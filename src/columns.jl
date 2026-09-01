# Arrow-backed column storage.
#
# Every column of a DataTable is either an `ArrowColumn` — a read-only
# AbstractVector whose data lives in an Apache Arrow physical layout
# (vendored ArrowCore), with a fast typed facade for element access — or,
# for element types Arrow cannot represent, a `ReadOnlyArrays.ReadOnlyArray`
# over the original vector.
#
# Ownership contract: constructors take ownership of the vectors passed to
# them. Arrow buffers alias the caller's memory where possible (fixed-width
# primitives, DataValueArray values/isna), so mutating or resizing an input
# vector after construction is undefined behavior on the Arrow side.

struct ArrowColumn{T,TFacade<:AbstractVector{T}} <: AbstractVector{T}
    facade::TFacade               # fast typed access with the public eltype
    field::ArrowCore.Field        # Arrow logical type / name / nullability
    data::ArrowCore.ArrayData     # Arrow physical storage
end

Base.size(c::ArrowColumn) = size(c.facade)
Base.IndexStyle(::Type{<:ArrowColumn}) = Base.IndexLinear()
Base.@propagate_inbounds Base.getindex(c::ArrowColumn, i::Int) = c.facade[i]

# ---------------------------------------------------------------------------
# Facade adapters
# ---------------------------------------------------------------------------

"Present a missing-based StringVector through the DataValue facade."
struct DataValueStringVector <: AbstractVector{DataValue{ArrowString}}
    sv::StringVector{Union{Missing,ArrowString}}
end
Base.size(v::DataValueStringVector) = size(v.sv)
Base.IndexStyle(::Type{DataValueStringVector}) = Base.IndexLinear()
Base.@propagate_inbounds function Base.getindex(v::DataValueStringVector, i::Int)
    x = v.sv[i]
    return x === missing ? DataValue{ArrowString}() : DataValue{ArrowString}(x)
end

"Temporal column over Arrow's epoch-relative integer storage."
struct TemporalVector{T,S<:Union{Int32,Int64}} <: AbstractVector{T}
    storage::Vector{S}
end
Base.size(v::TemporalVector) = size(v.storage)
Base.IndexStyle(::Type{<:TemporalVector}) = Base.IndexLinear()
Base.@propagate_inbounds Base.getindex(v::TemporalVector{T}, i::Int) where {T} =
    from_storage(T, v.storage[i])

"Nullable temporal column: converted storage (zero at null slots) plus mask."
struct NullableTemporalVector{T,S<:Union{Int32,Int64}} <: AbstractVector{DataValue{T}}
    storage::Vector{S}
    isna::Vector{Bool}
end
Base.size(v::NullableTemporalVector) = size(v.storage)
Base.IndexStyle(::Type{<:NullableTemporalVector}) = Base.IndexLinear()
Base.@propagate_inbounds Base.getindex(v::NullableTemporalVector{T}, i::Int) where {T} =
    v.isna[i] ? DataValue{T}() : DataValue{T}(from_storage(T, v.storage[i]))

# ---------------------------------------------------------------------------
# Temporal conversions (matching arrow-julia's facade conventions)
# ---------------------------------------------------------------------------

const EPOCH_DAYS = Dates.value(Dates.Date(1970))

arrow_temporal_type(::Type{Dates.Date}) = ArrowCore.DateType(ArrowCore.DAY)
arrow_temporal_type(::Type{Dates.DateTime}) =
    ArrowCore.TimestampType(ArrowCore.MILLISECOND, nothing)
arrow_temporal_type(::Type{Dates.Time}) = ArrowCore.TimeType(ArrowCore.NANOSECOND, 64)

temporal_storage_type(::Type{Dates.Date}) = Int32
temporal_storage_type(::Type{<:Union{Dates.DateTime,Dates.Time}}) = Int64

to_storage(x::Dates.Date) = Int32(Dates.value(x) - EPOCH_DAYS)
to_storage(x::Dates.DateTime) = Int64(Dates.value(x) - Dates.UNIXEPOCH)
to_storage(x::Dates.Time) = Int64(Dates.value(x))

from_storage(::Type{Dates.Date}, x) = Dates.Date(Dates.UTD(Int64(x) + EPOCH_DAYS))
from_storage(::Type{Dates.DateTime}, x) = Dates.DateTime(Dates.UTM(x + Dates.UNIXEPOCH))
from_storage(::Type{Dates.Time}, x) = Dates.Time(Dates.Nanosecond(x))

# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------

struct _TooLongString <: Exception end

# getval(i) is only called when isnull(i) is false, protecting
# DataValueArray's #undef values slots for non-isbits element types.
function build_string_payloads(n::Int, isnull::F1, getval::F2) where {F1,F2}
    payloads = Vector{ArrowStringPayload}(undef, n)
    buffers = Vector{Vector{UInt8}}()
    databuf = UInt8[]
    for i = 1:n
        if isnull(i)
            payloads[i] = ArrowStrings.PAYLOAD_MISSING
            continue
        end
        s = getval(i)
        len = ncodeunits(s)
        if len <= ArrowStrings.INLINE_MAX
            payloads[i] = ArrowStrings.inline_payload(codeunits(s), 1, len)
        else
            len <= typemax(Int32) || throw(_TooLongString())
            if isempty(buffers) || length(databuf) + len > typemax(Int32)
                databuf = UInt8[]
                push!(buffers, databuf)
            end
            off0 = length(databuf)
            append!(databuf, codeunits(s))
            payloads[i] =
                ArrowStrings.view_payload(databuf, off0 + 1, len, length(buffers) - 1, off0)
        end
    end
    # All buffer growth is complete here; only now may the buffers be wrapped
    # into Arrow regions (heapregion captures the current pointer).
    return payloads, buffers
end

function string_column(name::String, n::Int, isnull::F1, getval::F2, nullable::Bool) where {F1,F2}
    payloads, buffers = build_string_payloads(n, isnull, getval)
    f, d = ArrowCore.fromviewentries(name, payloads, buffers; nullable=nullable)
    if nullable
        sv = StringVector{Union{Missing,ArrowString}}(payloads, buffers, Val(:trusted))
        facade = DataValueStringVector(sv)
        return ArrowColumn{DataValue{ArrowString},DataValueStringVector}(facade, f, d)
    else
        sv = StringVector{ArrowString}(payloads, buffers, Val(:trusted))
        return ArrowColumn{ArrowString,typeof(sv)}(sv, f, d)
    end
end

function primitive_column(name::String, v::Vector{T}) where {T}
    f, d = ArrowCore.fromjulia(name, v)
    return ArrowColumn{T,Vector{T}}(v, f, d)
end

function nullable_primitive_column(name::String, dva::DataValueArray{P,1}) where {P}
    t = ArrowCore.arrowtype_for(P)
    validity = ArrowCore._bitmapbuffer(.!dva.isna)
    data = ArrowCore.BufferSlice(ArrowCore.heapregion(dva.values), 0, sizeof(dva.values))
    f = ArrowCore.Field(name, t; nullable=true)
    d = ArrowCore.ArrayData(
        t,
        length(dva),
        [validity, data];
        nullcount=count(dva.isna),
    )
    return ArrowColumn{DataValue{P},typeof(dva)}(dva, f, d)
end

function nullable_bool_column(name::String, dva::DataValueArray{Bool,1})
    tmp = Union{Missing,Bool}[dva.isna[i] ? missing : dva.values[i] for i = 1:length(dva)]
    f, d = ArrowCore.fromjulia(name, tmp)
    return ArrowColumn{DataValue{Bool},typeof(dva)}(dva, f, d)
end

function temporal_column(name::String, v::Vector{T}) where {T}
    S = temporal_storage_type(T)
    storage = S[to_storage(x) for x in v]
    t = arrow_temporal_type(T)
    f = ArrowCore.Field(name, t; nullable=false)
    d = ArrowCore.ArrayData(
        t,
        length(v),
        [
            ArrowCore.BufferSlice(),
            ArrowCore.BufferSlice(ArrowCore.heapregion(storage), 0, sizeof(storage)),
        ];
        nullcount=0,
    )
    return ArrowColumn{T,TemporalVector{T,S}}(TemporalVector{T,S}(storage), f, d)
end

function nullable_temporal_column(name::String, dva::DataValueArray{T,1}) where {T}
    S = temporal_storage_type(T)
    n = length(dva)
    storage = Vector{S}(undef, n)
    for i = 1:n
        # Branch before converting: values under null slots may hold garbage.
        storage[i] = dva.isna[i] ? zero(S) : to_storage(dva.values[i])
    end
    t = arrow_temporal_type(T)
    f = ArrowCore.Field(name, t; nullable=true)
    d = ArrowCore.ArrayData(
        t,
        n,
        [
            ArrowCore._bitmapbuffer(.!dva.isna),
            ArrowCore.BufferSlice(ArrowCore.heapregion(storage), 0, sizeof(storage)),
        ];
        nullcount=count(dva.isna),
    )
    facade = NullableTemporalVector{T,S}(storage, dva.isna)
    return ArrowColumn{DataValue{T},NullableTemporalVector{T,S}}(facade, f, d)
end

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

const ARROW_PRIMITIVE =
    Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,Float16,Float32,Float64}
const TEMPORAL = Union{Dates.Date,Dates.DateTime,Dates.Time}

_is_le() = Base.ENDIAN_BOM == 0x04030201

arrow_mappable(::Type{S}) where {S} =
    S <: ARROW_PRIMITIVE ||
    S === Bool ||
    (S <: AbstractString && isconcretetype(S) && _is_le()) ||
    (S <: TEMPORAL && isconcretetype(S))

function to_datavalue_array(v::Vector{T}) where {T}
    S = Base.nonmissingtype(T)
    n = length(v)
    values = Vector{S}(undef, n)
    isna = Vector{Bool}(undef, n)
    for i = 1:n
        x = v[i]
        if x === missing
            isna[i] = true
        else
            isna[i] = false
            values[i] = x
        end
    end
    return DataValueArray(values, isna)
end

prepare_column(name::Symbol, v::ArrowColumn) = v
prepare_column(name::Symbol, v::ReadOnlyArrays.ReadOnlyArray) = v
prepare_column(name::Symbol, v::Array{P,1}) where {P<:DataValue} =
    prepare_column(name, DataValueArray(v))

function prepare_column(name::Symbol, v::Vector{T}) where {T}
    # Union{} is a subtype of everything, so it would take the primitive
    # branch below and mis-dispatch; it has no Arrow type.
    T === Union{} && return ReadOnlyArrays.ReadOnlyArray(v)
    nm = String(name)
    if T <: ARROW_PRIMITIVE || T === Bool
        return primitive_column(nm, v)
    elseif T <: AbstractString && isconcretetype(T) && _is_le()
        return try
            string_column(nm, length(v), i -> false, i -> v[i], false)
        catch e
            e isa _TooLongString || rethrow()
            ReadOnlyArrays.ReadOnlyArray(v)
        end
    elseif T <: TEMPORAL && isconcretetype(T)
        return temporal_column(nm, v)
    elseif T !== Any &&
           Missing <: T &&
           Base.nonmissingtype(T) !== Union{} &&
           arrow_mappable(Base.nonmissingtype(T))
        return prepare_column(name, to_datavalue_array(v))
    else
        return ReadOnlyArrays.ReadOnlyArray(v)
    end
end

function prepare_column(name::Symbol, v::StringVector{ELT}) where {ELT}
    nm = String(name)
    if ELT === ArrowString
        f, d = ArrowCore.fromviewentries(nm, v.payloads, v.buffers; nullable=false)
        return ArrowColumn{ArrowString,typeof(v)}(v, f, d)
    else
        f, d = ArrowCore.fromviewentries(nm, v.payloads, v.buffers; nullable=true)
        facade = DataValueStringVector(v)
        return ArrowColumn{DataValue{ArrowString},DataValueStringVector}(facade, f, d)
    end
end

function prepare_column(name::Symbol, dva::DataValueArray{P,1}) where {P}
    P === Union{} && return ReadOnlyArrays.ReadOnlyArray(dva)
    nm = String(name)
    if P <: ARROW_PRIMITIVE
        return nullable_primitive_column(nm, dva)
    elseif P === Bool
        return nullable_bool_column(nm, dva)
    elseif P <: AbstractString && isconcretetype(P) && _is_le()
        return try
            string_column(nm, length(dva), i -> dva.isna[i], i -> dva.values[i], true)
        catch e
            e isa _TooLongString || rethrow()
            ReadOnlyArrays.ReadOnlyArray(dva)
        end
    elseif P <: TEMPORAL && isconcretetype(P)
        return nullable_temporal_column(nm, dva)
    else
        return ReadOnlyArrays.ReadOnlyArray(dva)
    end
end

prepare_column(name::Symbol, v::AbstractVector) = ReadOnlyArrays.ReadOnlyArray(v)

# ---------------------------------------------------------------------------
# Arrow storage accessors (the seam for zero-copy consumers, e.g. DuckDB)
# ---------------------------------------------------------------------------

_arrowfield(c::ArrowColumn) = c.field
_arrowfield(::AbstractVector) = nothing
_arrowdata(c::ArrowColumn) = c.data
_arrowdata(::AbstractVector) = nothing

"""
    arrowfield(dt::DataTable, name::Symbol)

The `ArrowCore.Field` describing column `name`'s Arrow storage, or `nothing`
for columns stored outside Arrow (the fallback path).
"""
arrowfield(dt, name::Symbol) = _arrowfield(getproperty(columns(dt), name))

"""
    arrowdata(dt::DataTable, name::Symbol)

The `ArrowCore.ArrayData` holding column `name`'s Arrow storage, or `nothing`
for columns stored outside Arrow (the fallback path).
"""
arrowdata(dt, name::Symbol) = _arrowdata(getproperty(columns(dt), name))
