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

@testitem "consume get_columns_copy DataValueArray zero-copy" begin
    import TableTraits
    using DataValues
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    struct FakeDataValueSource
        a::DataValueArray{Int,1}
    end
    TableTraits.supports_get_columns_copy(::FakeDataValueSource) = true
    TableTraits.get_columns_copy(src::FakeDataValueSource) = (a=src.a,)

    dva = DataValueArray([1, 2, 3], [false, true, false])
    dt = DataTable(FakeDataValueSource(dva))
    @test eltype(dt.a) === DataValue{Int}
    @test isna(dt.a[2])
    @test dt.a[3] == DataValue(3)
    @test ArrowCore.nullcount(arrowdata(dt, :a)) == 1

    # The DataValueArray's values/isna are aliased into the Arrow storage
    # zero-copy: a write to the handed-over array is visible on both sides.
    dva.values[3] = 42
    @test dt.a[3] == DataValue(42)
    @test ArrowCore.getvalue(arrowfield(dt, :a), arrowdata(dt, :a), 3) === Int64(42)
end
