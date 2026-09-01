@testitem "query filter and pipeline storage" begin
    using Query
    using DataTables: arrowdata

    dt = DataTable(name=["John", "Sally", "Kirk"], age=[23.0, 42.0, 59.0], children=[3, 5, 2])

    res = dt |> @filter(_.age > 30 && _.children > 2) |> DataTable
    @test length(res) == 1
    @test res[1].name == "Sally"

    # a full DataTable -> Query -> DataTable pipeline regains Arrow storage
    @test arrowdata(res, :name) !== nothing
    @test arrowdata(res, :age) !== nothing
end

@testitem "query filter on datavalue drops NA" begin
    using Query
    using DataValues

    dt = DataTable(a=[DataValue(1), NA, DataValue(3), DataValue(4)])
    res = dt |> @filter(_.a > 2) |> DataTable
    @test length(res) == 2
    @test res.a[1] == DataValue(3)

    res2 = dt |> @filter(_.a == 3) |> DataTable
    @test length(res2) == 1
end

@testitem "query string operations on arrowstring" begin
    using Query
    using DataValues
    using DataTables: ArrowString

    dt = DataTable(name=["John", "Sally", "Kirk"], nick=[DataValue("Johnny"), NA, DataValue("Captain")])
    @test eltype(dt.name) === ArrowString

    @test length(dt |> @filter(_.name == "Sally") |> DataTable) == 1
    @test length(dt |> @filter(occursin("o", _.name)) |> DataTable) == 1
    @test length(dt |> @filter(lowercase(_.name) == "kirk") |> DataTable) == 1

    lifted = dt |> @filter(lowercase(_.nick) == "johnny") |> DataTable
    @test length(lifted) == 1
    @test lifted[1].name == "John"
end

@testitem "query map projection" begin
    using Query
    using DataValues

    dt = DataTable(a=[1, 2, 3], m=[DataValue(1.0), NA, DataValue(3.0)], s=["x", "y", "z"])
    res = dt |> @map({_.a, double = _.a * 2, u = uppercase(_.s), lifted = _.m + 1}) |> DataTable
    @test res.a == [1, 2, 3]
    @test res.double == [2, 4, 6]
    @test res.u == ["X", "Y", "Z"]
    @test res.lifted[1] == DataValue(2.0)
    @test isna(res.lifted[2])
end

@testitem "query orderby thenby" begin
    using Query

    dt = DataTable(grp=[2, 1, 2, 1], v=[4, 3, 1, 2])
    res = dt |> @orderby(_.grp) |> @thenby(_.v) |> DataTable
    @test res.grp == [1, 1, 2, 2]
    @test res.v == [2, 3, 1, 4]

    res2 = dt |> @orderby_descending(_.v) |> DataTable
    @test res2.v == [4, 3, 2, 1]
end

@testitem "query groupby aggregate" begin
    using Query
    using Statistics

    dt = DataTable(grp=["a", "b", "a", "b", "a"], x=[1.0, 2.0, 3.0, 4.0, 5.0])
    res = dt |> @groupby(_.grp) |> @map({g = key(_), n = length(_), m = mean(_.x)}) |> DataTable
    @test length(res) == 2
    byg = Dict(String(r.g) => r for r in res)
    @test byg["a"].n == 3
    @test byg["a"].m == 3.0
    @test byg["b"].n == 2
    @test byg["b"].m == 3.0
end

@testitem "query join" begin
    using Query

    people = DataTable(id=[1, 2, 3], name=["John", "Sally", "Kirk"])
    depts = DataTable(id=[1, 2, 4], dept=["Eng", "Ops", "HR"])
    res = people |> @join(depts, _.id, _.id, {_.name, __.dept}) |> DataTable
    @test length(res) == 2
    @test res.name == ["John", "Sally"]
    @test res.dept == ["Eng", "Ops"]
end

@testitem "query take drop unique" begin
    using Query

    dt = DataTable(a=[1, 1, 2, 3, 3])
    @test (dt |> @take(2) |> DataTable).a == [1, 1]
    @test (dt |> @drop(3) |> DataTable).a == [3, 3]
    @test (dt |> @unique() |> DataTable) |> length == 3
end

@testitem "query collect targets agree" begin
    using Query

    dt = DataTable(a=[1, 2, 3], b=["x", "y", "z"])
    q = dt |> @filter(_.a >= 2) |> @map({_.a, _.b})
    asvec = collect(q)
    astable = q |> DataTable
    @test asvec isa Vector
    @test astable isa DataTable
    @test astable == asvec
end
