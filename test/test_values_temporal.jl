@testitem "date extremes" begin
    using Dates
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    dates = [Date(1970, 1, 1), Date(1970, 1, 2), Date(1969, 12, 31), Date(1, 1, 1), Date(9999, 12, 31)]
    dt = DataTable(d=dates)
    @test dt.d == dates
    f, d = arrowfield(dt, :d), arrowdata(dt, :d)
    @test ArrowCore.getvalue(f, d, 1) === Int32(0)
    @test ArrowCore.getvalue(f, d, 2) === Int32(1)
    @test ArrowCore.getvalue(f, d, 3) === Int32(-1)
    ArrowCore.validate_full(f, d)
    @test true
end

@testitem "time boundaries" begin
    using Dates

    times = [Time(0), Time(23, 59, 59, 999, 999, 999), Time(12, 0, 0, 0, 0, 1)]
    dt = DataTable(t=times)
    @test dt.t == times
    @test dt.t[2] == Time(23, 59, 59, 999, 999, 999)
    @test dt[3].t == Time(12, 0, 0, 0, 0, 1)
end

@testitem "datetime precision and pre-epoch" begin
    using Dates
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    stamps = [
        DateTime(2020, 1, 1, 12, 30, 45, 123),
        DateTime(1969, 12, 31, 23, 59, 59, 999),
        DateTime(1970, 1, 1),
    ]
    dt = DataTable(ts=stamps)
    @test dt.ts == stamps
    f, d = arrowfield(dt, :ts), arrowdata(dt, :ts)
    @test ArrowCore.getvalue(f, d, 2) === Int64(-1)
    @test ArrowCore.getvalue(f, d, 3) === Int64(0)
end

@testitem "nullable temporal garbage slots" begin
    using Dates
    using DataValues
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    # Build a DataValueArray whose values under null slots hold arbitrary
    # garbage — the conversion path must branch on isna before converting.
    values = [Date(2020, 1, 1), reinterpret(Date, typemax(Int64)), Date(2021, 1, 1)]
    isna_mask = [false, true, false]
    dva = DataValueArray(values, isna_mask)
    dt = DataTable(d=dva)
    @test dt.d[1] == DataValue(Date(2020, 1, 1))
    @test isna(dt.d[2])
    @test dt.d[3] == DataValue(Date(2021, 1, 1))
    f, d = arrowfield(dt, :d), arrowdata(dt, :d)
    @test ArrowCore.getvalue(f, d, 2) === missing
    ArrowCore.validate_full(f, d)
    @test true
end
