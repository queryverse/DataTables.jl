@testitem "all missing columns" begin
    using DataValues
    import DataTables.ArrowCore
    using DataTables: arrowdata

    dva = DataValueArray{Int}(3)   # all NA
    dt = DataTable(a=dva, b=[NA, NA, NA])
    @test all(isna, dt.a)
    @test ArrowCore.nullcount(arrowdata(dt, :a)) == 3
    # [NA, NA, NA] is Vector{DataValue{Union{}}} — no value type, fallback path
    @test all(isna, dt.b)
end

@testitem "no missing datavaluearray" begin
    using DataValues
    import DataTables.ArrowCore
    using DataTables: arrowfield, arrowdata

    dva = DataValueArray([1, 2, 3], fill(false, 3))
    dt = DataTable(a=dva)
    @test eltype(dt.a) === DataValue{Int}
    @test all(!isna, dt.a)
    @test [get(x) for x in dt.a] == [1, 2, 3]
    @test ArrowCore.nullcount(arrowdata(dt, :a)) == 0
    @test arrowfield(dt, :a).nullable
end

@testitem "missing edge positions" begin
    using DataValues
    import DataTables.ArrowCore
    using DataTables: arrowfield, arrowdata

    firstna = DataValue{Float64}[i == 1 ? DataValue{Float64}() : DataValue(i * 1.0) for i in 1:10]
    lastna = DataValue{Int}[i == 10 ? DataValue{Int}() : DataValue(i) for i in 1:10]
    altna = DataValue{Int}[iseven(i) ? DataValue{Int}() : DataValue(i) for i in 1:10]
    dt = DataTable(a=firstna, b=lastna, c=altna)
    @test isna(dt.a[1]) && dt.a[10] == DataValue(10.0)
    @test isna(dt.b[10]) && dt.b[1] == DataValue(1)
    @test sum(Int[isna(x) for x in dt.c]) == 5
    for n in (:a, :b, :c)
        f, d = arrowfield(dt, n), arrowdata(dt, n)
        for i in 1:10
            expected = isna(getproperty(dt, n)[i]) ? missing : get(getproperty(dt, n)[i])
            @test isequal(ArrowCore.getvalue(f, d, i), expected)
        end
    end
end

@testitem "unmappable missing falls back" begin
    using DataValues
    using DataTables: arrowdata

    dt = DataTable(
        m=[missing, missing],
        anyv=[DataValue{Any}(1), NA],
        sym=[DataValue(:s), NA],
        u=[:a, missing],
    )
    @test arrowdata(dt, :m) === nothing
    @test eltype(dt.m) === Missing
    @test arrowdata(dt, :anyv) === nothing
    @test arrowdata(dt, :sym) === nothing
    @test dt.sym[1] == DataValue(:s)
    # Union{Missing,Symbol} is not arrow-mappable: stays missing-based, fallback
    @test arrowdata(dt, :u) === nothing
    @test dt.u[1] === :a
    @test dt.u[2] === missing
end
