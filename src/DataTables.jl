module DataTables

import TableShowUtils, TableTraits, TableTraitsUtils, ReadOnlyArrays
import Dates

using DataValues

include(joinpath("vendor", "ArrowCore.jl"))
include(joinpath("vendor", "ArrowStrings.jl"))
import .ArrowCore
import .ArrowStrings: ArrowStrings, ArrowString, ArrowStringPayload, StringVector

export DataTable, NA, isna

struct DataTable{T,TCOLS} <: AbstractVector{T}
    columns::TCOLS
end

include("columns.jl")

function fromNT(nt::NamedTuple{names}) where {names}
    if length(names) > 1
        n1 = length(nt[1])
        for i = 2:length(names)
            length(nt[i]) == n1 || throw(
                ArgumentError(
                    "all columns must have the same length: column $(names[1]) has " *
                    "$n1 rows, column $(names[i]) has $(length(nt[i]))",
                ),
            )
        end
    end
    cols = NamedTuple{names}(ntuple(i -> prepare_column(names[i], nt[i]), length(names)))
    tx = typeof(cols)
    et = NamedTuple{names,Tuple{(eltype(fieldtype(tx, i)) for i in 1:fieldcount(tx))...}}
    return DataTable{et,tx}(cols)
end

fromNT(nt::NamedTuple{()}) = DataTable{NamedTuple{(),Tuple{}},NamedTuple{(),Tuple{}}}(nt)

function DataTable(;cols...)
    return fromNT(values(cols))
end

DataTable(dt::DataTable) = fromNT(columns(dt))

function DataTable(table)
    if TableTraits.supports_get_columns_copy(table)
        cols = TableTraits.get_columns_copy(table)
        cols isa NamedTuple && return fromNT(cols)
    end

    if TableTraits.supports_get_columns_copy_using_missing(table)
        cols = TableTraits.get_columns_copy_using_missing(table)
        cols isa NamedTuple && return fromNT(cols)
    end

    cols, colnames = TableTraitsUtils.create_columns_from_iterabletable(table)

    return fromNT(NamedTuple{tuple(colnames...)}(tuple(cols...)))
end

columns(dt::DataTable) = getfield(dt, :columns)

@inline Base.getproperty(dt::DataTable, name::Symbol) = getproperty(columns(dt), name)

Base.propertynames(dt::DataTable, private::Bool=false) = propertynames(columns(dt))

Base.size(dt::DataTable) = isempty(columns(dt)) ? (0,) : size(columns(dt)[1])

Base.IndexStyle(::Type{T}) where {T <: DataTable} = Base.IndexLinear()

@inline function Base.getindex(dt::DataTable{T}, i::Int) where {T}
    @boundscheck checkbounds(dt, i)
    return map(col -> @inbounds(getindex(col, i)), columns(dt))
end

function Base.getindex(dt::DataTable, I::AbstractVector)
    @boundscheck checkbounds(dt, I)
    return fromNT(map(c -> c[I], columns(dt)))
end

TableTraits.supports_get_columns_view(::DataTable) = true
TableTraits.get_columns_view(dt::DataTable) = columns(dt)

function Base.show(io::IO, dt::DataTable)
    # TableShowUtils cannot print a zero-column table
    if isempty(columns(dt))
        print(io, "0x0 DataTable")
    else
        TableShowUtils.printtable(io, dt, "DataTable")
    end
end

function Base.show(io::IO, ::MIME"text/plain", dt::DataTable)
    if isempty(columns(dt))
        print(io, "0x0 DataTable")
    else
        TableShowUtils.printtable(io, dt, "DataTable")
    end
end

function Base.show(io::IO, ::MIME"text/html", dt::DataTable)
    TableShowUtils.printHTMLtable(io, dt)
end

Base.showable(::MIME"text/html", dt::DataTable) = true

function Base.show(io::IO, ::MIME"application/vnd.dataresource+json", dt::DataTable)
    TableShowUtils.printdataresource(io, dt)
end

Base.showable(::MIME"application/vnd.dataresource+json", dt::DataTable) = true

end
