# DataTables.jl v1.0.0 Release Notes
* Columns are now stored in Apache Arrow physical layouts where the element
  type has an Arrow representation (vendored from the Arrow.jl 3.0 core
  rewrite); other element types keep the previous read-only storage. String
  columns expose `ArrowString` (an `AbstractString`) elements.
* Constructors take ownership of the vectors passed to them and reject
  columns of unequal length with an `ArgumentError`.
* `DataTable()` with zero columns now works as a zero-row table.
* Row subsetting with ranges, index vectors, and Bool masks (`dt[2:3]`,
  `dt[[1,3]]`, `dt[mask]`) returns a `DataTable`; `first(dt, n)` and
  `last(dt, n)` do too.
* `propertynames` returns the column names (tab completion in the REPL).
* `DataTable(table)` consumes the columnar `TableTraits.get_columns_copy`
  and `get_columns_copy_using_missing` interfaces when a source provides
  them, avoiding row iteration; `DataTable(dt::DataTable)` aliases columns
  without copying. DataTable implements `TableTraits.get_columns_view`.
* Inputs of `Vector{Union{Missing,T}}` with an Arrow-mappable `T` are now
  presented through the `DataValue` facade like other missing data.
* Requires Julia 1.10.

# DataTables.jl v0.1.0 Release Notes
* Initial release
