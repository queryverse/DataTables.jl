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
    cols = NamedTuple{names}(ntuple(i -> prepare_column(names[i], nt[i]), length(names)))
    tx = typeof(cols)
    et = NamedTuple{names,Tuple{(eltype(fieldtype(tx, i)) for i in 1:fieldcount(tx))...}}
    return DataTable{et,tx}(cols)
end

fromNT(nt::NamedTuple{()}) = DataTable{NamedTuple{(),Tuple{}},NamedTuple{(),Tuple{}}}(nt)

function DataTable(;cols...)
    return fromNT(values(cols))
end

function DataTable(table)
    if TableTraits.supports_get_columns_copy(table)
        cols = TableTraits.get_columns_copy(table)
        cols isa NamedTuple && return fromNT(cols)
    end

    cols, colnames = TableTraitsUtils.create_columns_from_iterabletable(table)

    return fromNT(NamedTuple{tuple(colnames...)}(tuple(cols...)))
end

columns(dt::DataTable) = getfield(dt, :columns)

@inline Base.getproperty(dt::DataTable, name::Symbol) = getproperty(columns(dt), name)

Base.size(dt::DataTable) = size(columns(dt)[1])

Base.IndexStyle(::Type{T}) where {T <: DataTable} = Base.IndexLinear()

function Base.checkbounds(::Type{Bool}, dt::DataTable, i)
    cols = columns(dt)
    if length(cols) == 0
        return true
    else
        return checkbounds(Bool, cols[1], i)
    end
end

@inline function Base.getindex(dt::DataTable{T}, i::Int) where {T}
    @boundscheck checkbounds(dt, i)
    return map(col -> @inbounds(getindex(col, i)), columns(dt))
end

function Base.show(io::IO, dt::DataTable)
    TableShowUtils.printtable(io, dt, "DataTable")
end

function Base.show(io::IO, ::MIME"text/plain", dt::DataTable)
    TableShowUtils.printtable(io, dt, "DataTable")
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
