@testitem "size length axes eltype" begin
    dt = DataTable(a=[1, 2, 3], b=["x", "y", "z"])
    @test size(dt) == (3,)
    @test length(dt) == 3
    @test axes(dt) == (Base.OneTo(3),)
    @test eltype(dt) <: NamedTuple
    @test fieldnames(eltype(dt)) == (:a, :b)
    @test Base.IndexStyle(typeof(dt)) isa Base.IndexLinear
    @test eltype(collect(dt)) === eltype(dt)
end

@testitem "getindex bounds" begin
    dt = DataTable(a=[1, 2, 3])
    @test dt[1] == (a=1,)
    @test dt[end] == (a=3,)
    @test first(dt) == (a=1,)
    @test last(dt) == (a=3,)
    @test_throws BoundsError dt[0]
    @test_throws BoundsError dt[4]
end

@testitem "row subsetting returns DataTable" begin
    using DataTables: arrowdata

    dt = DataTable(a=[1, 2, 3, 4], s=["w", "x", "a string that is longer than twelve", "z"])

    sub = dt[2:3]
    @test sub isa DataTable
    @test length(sub) == 2
    @test sub.a == [2, 3]
    @test sub.s[2] == "a string that is longer than twelve"
    @test arrowdata(sub, :a) !== nothing

    sub2 = dt[[1, 4]]
    @test sub2 isa DataTable
    @test sub2.a == [1, 4]

    mask = [x > 2 for x in dt.a]
    sub3 = dt[mask]
    @test sub3 isa DataTable
    @test sub3.a == [3, 4]

    sub4 = dt[dt.a .> 2]
    @test sub4 isa DataTable
    @test sub4.a == [3, 4]

    @test first(dt, 2) isa DataTable
    @test first(dt, 2).a == [1, 2]
    @test last(dt, 2) isa DataTable
    @test last(dt, 2).a == [3, 4]

    v = view(dt, 2:3)
    @test v isa SubArray
    @test collect(v) == collect(dt)[2:3]

    @test_throws BoundsError dt[0:2]
    @test_throws BoundsError dt[[1, 5]]

    dt0 = DataTable()
    @test dt0[1:0] isa DataTable
    @test length(dt0[1:0]) == 0
    @test_throws BoundsError dt0[[1]]
end

@testitem "iteration protocols" begin
    dt = DataTable(a=[1, 2, 3], b=[4.0, 5.0, 6.0])

    next = iterate(dt)
    @test next[1] == (a=1, b=4.0)
    next = iterate(dt, next[2])
    @test next[1] == (a=2, b=5.0)

    @test map(r -> r.a + 1, dt) == [2, 3, 4]
    @test [i for (i, r) in enumerate(dt) if r.a > 1] == [2, 3]
    @test [(x.a, y.b) for (x, y) in zip(dt, dt)] == [(1, 4.0), (2, 5.0), (3, 6.0)]
    @test (a=2, b=5.0) in dt
    @test !((a=9, b=9.9) in dt)
    @test sum(r.a for r in dt) == 6
end

@testitem "equality across storage classes" begin
    import ReadOnlyArrays

    a = [1, 2, 3]
    s = ["x", "y", "a string that is longer than twelve"]
    dt_arrow = DataTable(a=a, s=s)
    # ReadOnlyArray inputs pass through prepare_column untouched -> fallback storage
    dt_fallback = DataTable(a=ReadOnlyArrays.ReadOnlyArray(a), s=ReadOnlyArrays.ReadOnlyArray(s))

    @test DataTables.arrowdata(dt_arrow, :a) !== nothing
    @test DataTables.arrowdata(dt_fallback, :a) === nothing
    @test dt_arrow == dt_fallback
    @test isequal(dt_arrow, dt_fallback)
    @test hash(dt_arrow) == hash(dt_fallback)
    @test dt_arrow == collect(dt_arrow)
    @test hash(dt_arrow) == hash(collect(dt_arrow))
end

@testitem "propertynames and getproperty errors" begin
    dt = DataTable(a=[1], b=["x"], c=[2.0])
    @test propertynames(dt) == (:a, :b, :c)
    @test propertynames(dt, true) == (:a, :b, :c)
    # FieldError on Julia >= 1.12, ErrorException before; Exception covers both
    @test_throws Exception dt.nonexistent
end

@testitem "inherited container semantics" begin
    dt = DataTable(a=[1, 2])
    @test keys(dt) == LinearIndices(1:2)
    @test values(dt) === dt
    @test copy(dt) isa Vector
    @test copy(dt) == collect(dt)
    @test vcat(dt, dt) isa Vector
    @test length(vcat(dt, dt)) == 4
end

@testitem "broadcast" begin
    dt = DataTable(a=[1, 2, 3], b=[1.0, 2.0, 3.0])
    @test dt.a .+ 1 == [2, 3, 4]
    @test (dt.a .> 1) == [false, true, true]
    @test all(dt .== dt)
    @test dt.a .* dt.b == [1.0, 4.0, 9.0]
end
