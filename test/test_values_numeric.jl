@testitem "int extremes" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    dt = DataTable(
        i8=[typemin(Int8), typemax(Int8)],
        i16=[typemin(Int16), typemax(Int16)],
        i32=[typemin(Int32), typemax(Int32)],
        i64=[typemin(Int64), typemax(Int64)],
        u8=[typemin(UInt8), typemax(UInt8)],
        u16=[typemin(UInt16), typemax(UInt16)],
        u32=[typemin(UInt32), typemax(UInt32)],
        u64=[typemin(UInt64), typemax(UInt64)],
    )
    @test dt.i8 == [typemin(Int8), typemax(Int8)]
    @test dt.u64 == [typemin(UInt64), typemax(UInt64)]
    @test dt[1].i64 === typemin(Int64)
    @test dt[2].u32 === typemax(UInt32)
    @test ArrowCore.getvalue(arrowfield(dt, :i64), arrowdata(dt, :i64), 1) === typemin(Int64)
    @test ArrowCore.getvalue(arrowfield(dt, :i64), arrowdata(dt, :i64), 2) === typemax(Int64)
end

@testitem "float specials" begin
    dt = DataTable(a=[NaN, Inf, -Inf, -0.0], h=Float16[1.5, -2.5, 0.0, Inf])
    @test isnan(dt.a[1])
    @test dt.a[2] === Inf
    @test dt.a[3] === -Inf
    @test dt.a[4] === -0.0
    @test dt.h[4] === Float16(Inf)

    # Base == semantics carry over: NaN makes dt == dt false, isequal true
    @test !(dt == dt)
    @test isequal(dt, dt)

    dt2 = DataTable(z=[-0.0], p=[0.0])
    @test dt2[1].z == dt2[1].p == 0.0
    @test !isequal(dt2.z[1], 0.0)
end

@testitem "bool multiword bitmap" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    pattern = [isodd(i * i + 1) || i % 7 == 0 for i in 1:130]
    dt = DataTable(b=pattern)
    @test dt.b == pattern
    @test collect(dt) == [(b=x,) for x in pattern]
    ArrowCore.validate_full(arrowfield(dt, :b), arrowdata(dt, :b))
    @test true
end

@testitem "nullable bool multiword bitmap" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore
    using DataValues

    na_at = (1, 64, 65, 128, 130)
    col = DataValue{Bool}[i in na_at ? DataValue{Bool}() : DataValue(isodd(i)) for i in 1:130]
    dt = DataTable(b=col)
    @test eltype(dt.b) === DataValue{Bool}
    for i in 1:130
        if i in na_at
            @test isna(dt.b[i])
        else
            @test dt.b[i] == DataValue(isodd(i))
        end
    end
    @test ArrowCore.nullcount(arrowdata(dt, :b)) == length(na_at)
    ArrowCore.validate_full(arrowfield(dt, :b), arrowdata(dt, :b))
    @test true
end
