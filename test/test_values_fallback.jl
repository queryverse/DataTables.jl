@testitem "fallback eltypes" begin
    using DataTables: arrowdata

    struct Point2
        x::Float64
        y::Float64
    end

    dt = DataTable(
        sym=[:a, :b],
        ch=['x', 'y'],
        r=[1//2, 3//4],
        z=[1.0 + 2.0im, 3.0 - 4.0im],
        p=[Point2(1, 2), Point2(3, 4)],
        anyv=Any[1, "two"],
    )
    for n in (:sym, :ch, :r, :z, :p, :anyv)
        @test arrowdata(dt, n) === nothing
        col = getproperty(dt, n)
        @test_throws Exception col[1] = col[2]
    end
    @test dt.sym == [:a, :b]
    @test dt.ch == ['x', 'y']
    @test dt.r == [1//2, 3//4]
    @test dt.z[2] == 3.0 - 4.0im
    @test dt.p[1] == Point2(1, 2)
    @test dt.anyv == Any[1, "two"]
end

@testitem "mixed arrow and fallback table" begin
    using DataTables: arrowdata

    dt = DataTable(a=[1, 2], s=["x", "a string that is longer than twelve"], sym=[:p, :q])
    @test arrowdata(dt, :a) !== nothing
    @test arrowdata(dt, :s) !== nothing
    @test arrowdata(dt, :sym) === nothing
    row = dt[2]
    @test row.a == 2
    @test row.s == "a string that is longer than twelve"
    @test row.sym === :q
    @test length(collect(dt)) == 2
    @test eltype(collect(dt)) === eltype(dt)
end
