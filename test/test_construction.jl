@testitem "construct kwargs all eltypes" begin
    using Dates
    using DataTables: ArrowString

    dt = DataTable(
        i8=Int8[1, 2], i16=Int16[1, 2], i32=Int32[1, 2], i64=Int64[1, 2],
        u8=UInt8[1, 2], u16=UInt16[1, 2], u32=UInt32[1, 2], u64=UInt64[1, 2],
        f16=Float16[1, 2], f32=Float32[1, 2], f64=Float64[1, 2],
        b=[true, false], s=["x", "y"],
        d=[Date(2020, 1, 1), Date(2021, 1, 1)],
        t=[Time(1), Time(2)],
        ts=[DateTime(2020, 1, 1), DateTime(2021, 1, 1)],
        sym=[:a, :b],
    )
    @test length(dt) == 2
    @test eltype(dt.i8) === Int8
    @test eltype(dt.u64) === UInt64
    @test eltype(dt.f16) === Float16
    @test eltype(dt.b) === Bool
    @test eltype(dt.s) === ArrowString
    @test eltype(dt.d) === Date
    @test eltype(dt.t) === Time
    @test eltype(dt.ts) === DateTime
    @test eltype(dt.sym) === Symbol
    row = dt[1]
    @test row.i8 === Int8(1)
    @test row.s == "x"
    @test row.d == Date(2020, 1, 1)
    @test row.sym === :a
end

@testitem "construct from vector of namedtuples" begin
    dt1 = DataTable([(a=1, b="x"), (a=2, b="y")])
    dt2 = DataTable(a=[1, 2], b=["x", "y"])
    @test dt1 == dt2
end

@testitem "construct from generator" begin
    dt = DataTable((a=i, b=string(i)) for i in 1:3)
    @test length(dt) == 3
    @test dt.a == [1, 2, 3]
    @test dt.b == ["1", "2", "3"]
end

@testitem "construct from DataTable is zero copy" begin
    dt = DataTable(a=[1, 2, 3], s=["x", "a string that is longer than twelve", "z"])
    dt2 = DataTable(dt)
    @test dt2 == dt
    @test DataTables.columns(dt2).a === DataTables.columns(dt).a
    @test DataTables.columns(dt2).s === DataTables.columns(dt).s
end

@testitem "construct single column" begin
    dt = DataTable(a=[1])
    @test size(dt) == (1,)
    @test dt[1] == (a=1,)
end

@testitem "construct wide 30 columns" begin
    dt = DataTable(; (Symbol("c", i) => [i, i + 1] for i in 1:30)...)
    @test size(dt) == (2,)
    @test length(propertynames(dt)) == 30
    @test length(dt[2]) == 30
    @test dt[2].c30 == 31
    @test dt.c17 == [17, 18]
end

@testitem "construct unequal lengths" begin
    @test_throws ArgumentError DataTable(a=[1, 2], b=[1])
    @test_throws ArgumentError DataTable(a=[1, 2], b=[1, 2], c=String[])
    dt = DataTable(a=Int[], b=String[])
    @test length(dt) == 0
end

@testitem "construct zero columns" begin
    dt = DataTable()
    @test size(dt) == (0,)
    @test length(dt) == 0
    @test collect(dt) == NamedTuple{(),Tuple{}}[]
    @test_throws BoundsError dt[1]
    @test isempty(propertynames(dt))
end

@testitem "construct reserved-word column names" begin
    dt = DataTable(length=[1, 2], columns=["a", "b"], size=[0.5, 1.5])
    @test dt.length == [1, 2]
    @test dt.columns == ["a", "b"]
    @test dt.size == [0.5, 1.5]
    @test length(dt) == 2
    @test DataTables.columns(dt) isa NamedTuple
end

@testitem "construct unicode column names" begin
    cols = Dict(Symbol("α") => [1, 2], Symbol("日本") => ["あ", "い"], Symbol("x y") => [1.0, 2.0])
    dt = DataTable(; cols...)
    @test getproperty(dt, Symbol("α")) == [1, 2]
    @test getproperty(dt, Symbol("日本")) == ["あ", "い"]
    @test getproperty(dt, Symbol("x y")) == [1.0, 2.0]
end

@testitem "construct from range falls back" begin
    using DataTables: arrowdata

    dt = DataTable(a=1:3)
    @test dt.a == [1, 2, 3]
    @test arrowdata(dt, :a) === nothing
end
