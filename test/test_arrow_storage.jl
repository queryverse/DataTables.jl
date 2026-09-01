@testitem "arrow primitives" begin
    using DataTables: arrowfield, arrowdata, ArrowColumn
    import DataTables.ArrowCore

    a = [1, 2, 3]
    dt = DataTable(a=a, b=[4.0, 5.0, 6.0], c=UInt8[7, 8, 9], d=Float32[1.5, 2.5, 3.5], e=[true, false, true])

    @test dt.a isa ArrowColumn{Int64}
    @test dt.a == [1, 2, 3]
    @test dt.b == [4.0, 5.0, 6.0]
    @test dt.c == UInt8[7, 8, 9]
    @test dt.d == Float32[1.5, 2.5, 3.5]
    @test dt.e == [true, false, true]
    @test eltype(dt.e) === Bool

    for n in (:a, :b, :c, :d, :e)
        @test arrowdata(dt, n) !== nothing
        @test arrowfield(dt, n) !== nothing
    end

    # Fixed-width primitive storage aliases the input vector (zero-copy):
    # the Arrow-side value tracks mutations of the original vector.
    f, d = arrowfield(dt, :a), arrowdata(dt, :a)
    @test ArrowCore.getvalue(f, d, 2) === Int64(2)
    a[2] = 42
    @test ArrowCore.getvalue(f, d, 2) === Int64(42)
    @test dt.a[2] == 42
    a[2] = 2
end

@testitem "arrow strings" begin
    using DataTables: arrowdata, ArrowColumn
    using DataTables: ArrowString

    strs = ["", "x", "elevenchars", "twelve chars", "thirteen char", "a considerably longer string that certainly views"]
    dt = DataTable(s=strs)

    @test arrowdata(dt, :s) !== nothing
    @test dt.s == strs
    @test all(x -> x isa ArrowString, dt.s)
    @test String.(collect(dt.s)) == strs
    @test ncodeunits(dt.s[4]) == 12   # inline boundary
    @test ncodeunits(dt.s[5]) == 13   # first view payload

    # multiple long strings share one data buffer
    longs = [string("long-", i, "-", repeat("abc", 10)) for i in 1:5]
    dt2 = DataTable(s=longs)
    @test dt2.s == longs
end

@testitem "arrow missing primitives" begin
    using DataTables: arrowfield, arrowdata, ArrowColumn
    import DataTables.ArrowCore
    using DataValues

    dt = DataTable(a=[DataValue(1), NA, DataValue(3)])
    @test eltype(dt.a) === DataValue{Int}
    @test dt.a[1] == DataValue(1)
    @test isna(dt.a[2])
    @test dt.a[3] == DataValue(3)
    @test arrowdata(dt, :a) !== nothing
    @test ArrowCore.nullcount(arrowdata(dt, :a)) == 1
    @test ArrowCore.getvalue(arrowfield(dt, :a), arrowdata(dt, :a), 2) === missing

    @test collect(dt) == [(a = DataValue(1),), (a = DataValue{Int}(),), (a = DataValue(3),)]
end

@testitem "arrow missing strings" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore
    using DataValues

    dt = DataTable(s=[DataValue("hi"), NA, DataValue("a string that is longer than twelve bytes")])
    @test eltype(dt.s) <: DataValue
    @test dt.s[1] == DataValue("hi")
    @test isna(dt.s[2])
    @test dt.s[3] == DataValue("a string that is longer than twelve bytes")
    @test ArrowCore.nullcount(arrowdata(dt, :s)) == 1
    @test ArrowCore.getvalue(arrowfield(dt, :s), arrowdata(dt, :s), 2) === missing
end

@testitem "arrow missing-union input" begin
    using DataTables: arrowdata
    using DataValues

    dt = DataTable(a=[1, missing, 3], s=["x", missing, "a string that is longer than twelve"])
    @test eltype(dt.a) === DataValue{Int}
    @test isna(dt.a[2])
    @test dt.a[3] == DataValue(3)
    @test eltype(dt.s) <: DataValue
    @test isna(dt.s[2])
    @test dt.s[3] == DataValue("a string that is longer than twelve")
    @test arrowdata(dt, :a) !== nothing
    @test arrowdata(dt, :s) !== nothing
end

@testitem "arrow temporal" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore
    using DataValues
    using Dates

    dates = [Date(1969, 12, 31), Date(1970, 1, 2), Date(2020, 2, 29)]
    times = [Time(0), Time(12, 34, 56), Time(23, 59, 59)]
    stamps = [DateTime(1970, 1, 1, 0, 0, 1), DateTime(2000, 1, 1), DateTime(2026, 8, 31, 12)]
    dt = DataTable(d=dates, t=times, ts=stamps)

    @test dt.d == dates
    @test dt.t == times
    @test dt.ts == stamps
    @test arrowfield(dt, :d).type == ArrowCore.DateType(ArrowCore.DAY)
    @test arrowfield(dt, :t).type == ArrowCore.TimeType(ArrowCore.NANOSECOND, 64)
    @test arrowfield(dt, :ts).type == ArrowCore.TimestampType(ArrowCore.MILLISECOND, nothing)

    # raw storage word: 1970-01-02 is day 1; 1969-12-31 is day -1
    @test ArrowCore.getvalue(arrowfield(dt, :d), arrowdata(dt, :d), 2) === Int32(1)
    @test ArrowCore.getvalue(arrowfield(dt, :d), arrowdata(dt, :d), 1) === Int32(-1)

    dtn = DataTable(d=[DataValue(Date(2020, 1, 1)), NA])
    @test eltype(dtn.d) === DataValue{Date}
    @test dtn.d[1] == DataValue(Date(2020, 1, 1))
    @test isna(dtn.d[2])
    @test ArrowCore.nullcount(arrowdata(dtn, :d)) == 1
end

@testitem "arrow fallback" begin
    using DataTables: arrowdata
    using DataValues

    dt = DataTable(a=[:x, :y, :z], b=Any[1, "two", 3.0], c=[DataValue(:s), NA, DataValue(:t)])
    @test dt.a == [:x, :y, :z]
    @test dt.b == Any[1, "two", 3.0]
    @test dt.c[1] == DataValue(:s)
    @test isna(dt.c[2])
    @test arrowdata(dt, :a) === nothing
    @test arrowdata(dt, :b) === nothing
    @test arrowdata(dt, :c) === nothing

    # ranges keep working through the fallback path
    dt2 = DataTable(a=1:3)
    @test dt2.a == [1, 2, 3]
    @test arrowdata(dt2, :a) === nothing
end

@testitem "arrow empty and zero rows" begin
    using DataTables: arrowdata
    using Dates

    dt = DataTable(a=Int[], b=String[], c=Date[], d=Float64[])
    @test length(dt) == 0
    @test collect(dt) == []
    @test arrowdata(dt, :a) !== nothing
    @test arrowdata(dt, :b) !== nothing
    @test arrowdata(dt, :c) !== nothing

    dt2 = DataTable(NamedTuple{(:x, :y),Tuple{Int,String}}[])
    @test length(dt2) == 0
end

@testitem "arrow read only" begin
    dt = DataTable(a=[1, 2, 3], b=[:x, :y, :z])
    @test_throws Exception dt.a[1] = 0
    @test_throws Exception dt.b[1] = :w
end

@testitem "arrow validate" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore
    using DataValues
    using Dates

    dt = DataTable(
        a=[1, 2, 3],
        b=[1.5, 2.5, 3.5],
        c=[true, false, true],
        d=["short", "a string that is longer than twelve bytes", ""],
        e=[DataValue(1), NA, DataValue(3)],
        f=[DataValue("x"), NA, DataValue("another string longer than twelve")],
        g=[Date(2020, 1, 1), Date(1969, 1, 1), Date(2026, 8, 31)],
        h=[DataValue(DateTime(2020, 1, 1)), NA, DataValue(DateTime(2026, 1, 1))],
        i=[Time(1), Time(2), Time(3)],
    )
    for n in propertynames(DataTables.columns(dt))
        f, d = arrowfield(dt, n), arrowdata(dt, n)
        @test f !== nothing
        ArrowCore.validate_full(f, d)   # throws on any storage invariant violation
        @test true
    end
end

@testitem "arrow dataresource show" begin
    using DataValues
    using Dates

    dt = DataTable(
        s=["a string that is longer than twelve bytes", "x"],
        m=[DataValue("hi"), NA],
        d=[Date(2020, 1, 1), Date(2021, 1, 1)],
    )
    json = sprint((stream, data) -> show(stream, "application/vnd.dataresource+json", data), dt)
    @test occursin("\"name\":\"s\",\"type\":\"string\"", json)
    @test occursin("\"name\":\"m\",\"type\":\"string\"", json)
    @test occursin("\"name\":\"d\",\"type\":\"date\"", json)
    @test occursin("a string that is longer than twelve bytes", json)
    @test occursin("null", json)
end

@testitem "arrow re-ingestion" begin
    using DataTables: arrowdata
    using DataValues

    dt = DataTable(a=[1, 2, 3], s=["x", "a string that is longer than twelve", "z"], m=[DataValue(1), NA, DataValue(3)])
    dt2 = DataTable(dt)
    @test dt == dt2
    @test arrowdata(dt2, :a) !== nothing
    @test arrowdata(dt2, :s) !== nothing
    @test arrowdata(dt2, :m) !== nothing
end
