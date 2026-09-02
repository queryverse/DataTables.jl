# DataTables.jl

DataTables.jl provides `DataTable`, a simple, fast, **read-only** table type
for the [Queryverse](https://www.queryverse.org/). A `DataTable` is a plain
container: it stores columns and hands out rows. All data manipulation —
filtering, projecting, grouping, sorting, joining — happens through
[Query.jl](https://github.com/queryverse/Query.jl) pipelines rather than
through methods on the table itself.

Under the hood, columns are stored in [Apache Arrow](https://arrow.apache.org/)
physical layouts wherever the element type has an Arrow representation. The
user-facing behavior is that of an ordinary Julia container, but the
underlying memory is Arrow-native, which will allow zero-copy handoff of a
`DataTable` to Arrow consumers such as the DuckDB query engine. Element
types without an Arrow representation fall back to plain read-only column
storage, so any Julia type can be stored in a column.

```@contents
Depth = 2
```

## Installation

```julia
Pkg.add("DataTables")
```

## Getting started

Create a `DataTable` by passing columns as keyword arguments:

```jldoctest getting-started
julia> using DataTables

julia> dt = DataTable(Name=["John", "Sally", "Jim"], Age=[23., 43., 56.], Children=[2, 0, 3]);

julia> length(dt)
3
```

A `DataTable` is an `AbstractVector` of `NamedTuple` rows. Index it to get a
row, and iterate it to visit every row:

```jldoctest getting-started
julia> dt[2]
(Name = "Sally", Age = 43.0, Children = 0)

julia> sum(r.Children for r in dt)
5
```

Columns are accessed by name with the dot syntax and are themselves
read-only `AbstractVector`s:

```jldoctest getting-started
julia> dt.Age == [23., 43., 56.]
true

julia> dt.Name[2]
"Sally"
```

To access an individual cell, it is generally more efficient to first access
the column and then index into it (`dt.Name[2]`) than to materialize a whole
row first.

You can also create a `DataTable` from any source that implements the
[TableTraits.jl](https://github.com/queryverse/TableTraits.jl) interface —
everything in the Queryverse, but also many other table types like
[DataFrames.jl](https://github.com/JuliaData/DataFrames.jl):

```julia
using DataTables, CSVFiles, FileIO

dt = load("data.csv") |> DataTable
```

When a source offers a columnar handoff (`TableTraits.get_columns_copy`),
`DataTable` consumes the columns directly — for primitive columns without
any copying at all — and only falls back to row iteration otherwise.

## Row subsetting

Indexing with a range, a vector of indices, or a `Bool` mask returns a new
`DataTable` with the selected rows, and so do `first(dt, n)` and
`last(dt, n)`:

```jldoctest getting-started
julia> dt[2:3][1]
(Name = "Sally", Age = 43.0, Children = 0)

julia> dt[dt.Age .> 30] |> length
2

julia> first(dt, 2) isa DataTable
true
```

Anything beyond row selection is Query.jl territory — see
[Integration with the Queryverse](@ref) below.

## Missing data

Missing values are represented with `DataValue` from
[DataValues.jl](https://github.com/queryverse/DataValues.jl). A column with
missing data has element type `DataValue{T}`; the exported `NA` constant
denotes a missing value and `isna` tests for one:

```jldoctest
julia> using DataTables, DataValues

julia> dt = DataTable(a=[DataValue(1), NA, DataValue(3)]);

julia> isna(dt.a[2])
true

julia> dt.a[3] == 3
true
```

Vectors with `Union{Missing,T}` element types are accepted by the
constructors and are presented through the `DataValue` facade like any other
missing data (for `T` with an Arrow representation):

```jldoctest
julia> using DataTables, DataValues

julia> dt = DataTable(a=[1, missing, 3]);

julia> eltype(dt.a)
DataValue{Int64}
```

## Element types and storage

Columns are stored in Arrow physical layouts when the element type has an
Arrow representation:

| input element type | storage |
|---|---|
| `Int8`–`Int64`, `UInt8`–`UInt64`, `Float16/32/64` | Arrow primitive layout, **zero-copy** (the column aliases your vector) |
| `Bool` | Arrow bit-packed Boolean layout |
| `String` (and other concrete `AbstractString`s) | Arrow `Utf8View` layout; elements are `ArrowString` |
| `Date`, `DateTime`, `Time` | Arrow date32 / timestamp[ms] / time64[ns] layouts |
| `DataValue{T}` / `Union{Missing,T}` of the above | the same layouts plus an Arrow validity bitmap; elements are `DataValue{T}` |
| anything else | plain read-only column (no Arrow storage) |

Two things are worth knowing about string columns. Their element type is
`ArrowString`, an `AbstractString` in the compact Arrow string-view
representation: it compares equal to and hashes identically with the
corresponding `String`, so `dt.Name[2] == "Sally"`, dictionary lookups, and
Query.jl string operations all work unchanged — but code that tests
`x isa String` specifically must test `x isa AbstractString` instead. Call
`String(x)` to detach a plain `String` copy.

And an ownership rule that applies to all constructors: `DataTable` takes
ownership of the vectors passed to it. Column storage may alias the input
vectors (that is what makes primitive columns zero-copy), so do not mutate
or resize input vectors after constructing a table.

## Integration with the Queryverse

`DataTable` implements the TableTraits.jl interfaces, so it composes with
the whole Queryverse. Manipulate it with [Query.jl](https://github.com/queryverse/Query.jl)
and collect results back into a new `DataTable`:

```julia
using DataTables, Query

result = dt |>
    @filter(_.Age > 30 && _.Children > 2) |>
    @map({_.Name, _.Age}) |>
    DataTable
```

Load and save files with the Queryverse file IO packages, for example
[CSVFiles.jl](https://github.com/queryverse/CSVFiles.jl):

```julia
using DataTables, CSVFiles, FileIO

dt = load("data.csv") |> DataTable
save("output.csv", dt)
```

Or plot directly with [VegaLite.jl](https://github.com/queryverse/VegaLite.jl):

```julia
using DataTables, VegaLite

dt |> @vlplot(:point, x=:Age, y=:Children)
```

On the interface level, `DataTable` implements `TableTraits.isiterabletable`
(every table is an iterator of `NamedTuple` rows) and
`TableTraits.get_columns_view` (columnar read-only access without copying),
and its constructor consumes `TableTraits.get_columns_copy` from sources
that provide it.

## Arrow storage details

The Arrow implementation is vendored under `src/vendor/` from the
[Arrow.jl 3.0 core rewrite](https://github.com/apache/arrow-julia/tree/core-rewrite)
(see `src/vendor/README.md` for the exact commit and licensing). The
vendoring is temporary: once upstream registers those modules as standalone
packages, they will become ordinary dependencies.

For consumers that want to access the Arrow storage itself — for example a
future zero-copy handoff to DuckDB through the Arrow C data interface — the
unexported accessors [`DataTables.arrowfield`](@ref) and
[`DataTables.arrowdata`](@ref) return a column's Arrow field descriptor and
array data, or `nothing` for columns on the fallback path. These are
experimental and their API may change.

## API reference

```@docs
DataTable
DataTables.arrowfield
DataTables.arrowdata
```
