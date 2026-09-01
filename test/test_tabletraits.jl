@testitem "isiterabletable and getiterator" begin
    import TableTraits, IteratorInterfaceExtensions

    dt = DataTable(a=[1, 2])
    @test TableTraits.isiterabletable(dt) === true
    @test IteratorInterfaceExtensions.getiterator(dt) === dt
end

@testitem "get_columns_view" begin
    import TableTraits

    dt = DataTable(a=[1, 2], s=["x", "y"])
    @test TableTraits.supports_get_columns_view(dt)
    cols = TableTraits.get_columns_view(dt)
    @test cols === DataTables.columns(dt)
    @test cols isa NamedTuple
    @test keys(cols) == (:a, :s)
    @test_throws Exception cols.a[1] = 0

    dt0 = DataTable()
    @test TableTraits.get_columns_view(dt0) === NamedTuple()
end

@testitem "roundtrip through row iteration" begin
    using DataValues
    using DataTables: arrowdata

    dt = DataTable(
        a=[1, 2, 3],
        s=["x", "a string that is longer than twelve", "z"],
        m=[DataValue(1.5), NA, DataValue(2.5)],
    )
    dt2 = DataTable(collect(dt))
    @test dt2 == dt
    @test arrowdata(dt2, :a) !== nothing
    @test arrowdata(dt2, :s) !== nothing
    @test arrowdata(dt2, :m) !== nothing
end

@testitem "consume get_columns_copy source zero-copy" begin
    import TableTraits
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    struct FakeColumnarSource
        v::Vector{Int}
        s::Vector{String}
    end
    TableTraits.supports_get_columns_copy(::FakeColumnarSource) = true
    TableTraits.get_columns_copy(src::FakeColumnarSource) = (a=src.v, s=src.s)

    src = FakeColumnarSource([1, 2, 3], ["x", "y", "z"])
    dt = DataTable(src)
    @test dt.a == [1, 2, 3]
    @test dt.s == ["x", "y", "z"]

    # Primitive columns take ownership zero-copy: mutations of the handed-over
    # vector are visible through the table and through the Arrow storage.
    src.v[2] = 42
    @test dt.a[2] == 42
    @test ArrowCore.getvalue(arrowfield(dt, :a), arrowdata(dt, :a), 2) === Int64(42)
end

@testitem "consume get_columns_copy_using_missing source" begin
    import TableTraits
    using DataValues
    using DataTables: arrowdata
    import DataTables.ArrowCore

    struct FakeMissingSource end
    TableTraits.supports_get_columns_copy_using_missing(::FakeMissingSource) = true
    TableTraits.get_columns_copy_using_missing(::FakeMissingSource) =
        (a=Union{Missing,Int}[1, missing, 3], s=Union{Missing,String}["x", missing, "z"])

    dt = DataTable(FakeMissingSource())
    @test eltype(dt.a) === DataValue{Int}
    @test isna(dt.a[2])
    @test dt.a[3] == DataValue(3)
    @test isna(dt.s[2])
    @test dt.s[1] == DataValue("x")
    @test arrowdata(dt, :a) !== nothing
    @test arrowdata(dt, :s) !== nothing
    @test ArrowCore.nullcount(arrowdata(dt, :a)) == 1
end
