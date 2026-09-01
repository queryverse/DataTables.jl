# DataTables.jl

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Build Status](https://github.com/queryverse/DataTables.jl/actions/workflows/juliaci.yml/badge.svg?branch=main)](https://github.com/queryverse/DataTables.jl/actions/workflows/juliaci.yml)
[![codecov](https://codecov.io/gh/queryverse/DataTables.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/queryverse/DataTables.jl)

## Overview

A simple read-only table type for the [Queryverse](https://github.com/queryverse).

## Installation

You can install the package at the Pkg REPL-mode with:

```julia
pkg> add DataTables
```

## Getting started

The main type in this package is `DataTable`, a data structure for tabular data. To create a new `DataTable` with a number of columns, just pass the columns as keyword arguments to the `DataTable` constructor:

```julia
julia> dt = DataTable(Name=["John", "Sally", "Jim"], Age=[23., 43., 56.], Children=[2, 0, 3])
3x3 DataTable
Name  │ Age  │ Children
──────┼──────┼─────────
John  │ 23.0 │ 2
Sally │ 43.0 │ 0
Jim   │ 56.0 │ 3
```

To access an individual column by name, use the `.` dot syntax:

```julia
julia> dt.Age
3-element ReadOnlyArrays.ReadOnlyArray{Float64,1,Array{Float64,1}}:
 23.0
 43.0
 56.0
```

To access an individual row, use the normal julia index syntax:

```julia
julia> dt[2]
(Name = "Sally", Age = 43.0, Children = 0)
```

To select a subset of rows, index with a range, a vector of indices, or a Bool mask; the result is again a `DataTable`:

```julia
julia> dt[2:3]
julia> dt[dt.Age .> 30]
```

If you want to access the value in an individual cell, it is generally more efficient to first access the column via the dot syntax, and then select the value for a given row via indexing:

```julia
julia> dt.Name[2]
"Sally"
```

You can also create a new `DataTable` by passing any object to its constructor that implements the [TableTraits.jl](https://github.com/queryverse/TableTraits.jl) interface. That includes everything in the [Queryverse](https://www.queryverse.org/), but also many other table types like [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl), [IndexedTables.jl](https://github.com/JuliaComputing/IndexedTables.jl) etc. Every `DataTable` also implements the [TableTraits.jl](https://github.com/queryverse/TableTraits.jl) interface and can therefore be passed to any function that accepts a [TableTraits.jl](https://github.com/queryverse/TableTraits.jl) value.

## Arrow storage

`DataTable` stores its columns in [Apache Arrow](https://arrow.apache.org/) physical layouts wherever the element type has an Arrow representation (fixed-width numbers, `Bool`, strings, `Date`/`DateTime`/`Time`, and their missing-value versions). The user-facing behavior is unchanged — columns are read-only `AbstractVector`s and missing data uses [DataValues.jl](https://github.com/queryverse/DataValues.jl) — but the underlying memory is Arrow-native, which will allow zero-copy handoff of a `DataTable` to Arrow consumers such as the DuckDB query engine via the Arrow C data interface. Element types without an Arrow representation fall back to plain read-only column storage, so any Julia type can be stored in a column.

The Arrow implementation is vendored under `src/vendor/` from the [Arrow.jl 3.0 core rewrite](https://github.com/apache/arrow-julia/tree/core-rewrite) until upstream registers those modules as standalone packages; see `src/vendor/README.md` for provenance and licensing.

Note that `DataTable` constructors take ownership of the vectors passed to them: column memory may alias the input vectors, so do not mutate or resize them after constructing the table.

## Alternatives

DataTables.jl is not the only julia initiative for tabular data, there are many other packages that have similar goals. Take a look at [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl), [IndexedTables.jl](https://github.com/JuliaComputing/IndexedTables.jl) and [TypedTables.jl](https://github.com/JuliaData/TypedTables.jl) (which in particular was a major inspiration for this package here). If I missed other packages, please let me know and I'll add them to this list!

## Getting help

Please ask any usage question in the [Data Domain](https://discourse.julialang.org/c/domain/data) on the [julia Discourse forum](https://discourse.julialang.org/). If you find a bug or have an improvement suggestion for this package, please open an issue in this github repository.
