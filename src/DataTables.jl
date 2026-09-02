module DataTables

import TableShowUtils, TableTraits, TableTraitsUtils, ReadOnlyArrays
import Dates

using DataValues

include(joinpath("vendor", "ArrowCore.jl"))
include(joinpath("vendor", "ArrowStrings.jl"))
import .ArrowCore
import .ArrowStrings: ArrowStrings, ArrowString, ArrowStringPayload, StringVector

export DataTable, NA, isna

"""
    DataTable(; cols...)
    DataTable(table)

A simple, fast, read-only table. A `DataTable` is an `AbstractVector` of
`NamedTuple` rows; columns are accessed by name via `dt.colname` and are
themselves read-only `AbstractVector`s. Indexing with a range, a vector of
indices, or a `Bool` mask returns a new `DataTable` with the selected rows.
Missing values are represented as `DataValues.DataValue`.

`DataTable(; cols...)` builds a table from keyword-argument column vectors.
`DataTable(table)` builds a table from any TableTraits.jl source (a columnar
handoff via `TableTraits.get_columns_copy` is used when the source supports
it, otherwise rows are iterated); `DataTable(dt::DataTable)` reuses the
existing columns without copying.

Columns whose element type has an Apache Arrow representation (fixed-width
numbers, `Bool`, strings, `Date`/`DateTime`/`Time`, and their `DataValue`
versions) are stored in Arrow physical layouts; string elements are
`ArrowString <: AbstractString`. Any other element type is stored in a plain
read-only column, so every Julia type can be stored.

The constructors take ownership of the vectors passed to them: column
storage may alias the input vectors, so do not mutate or resize them after
constructing the table.
"""
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
