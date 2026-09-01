@testitem "vegalite spec from datatable" begin
    using VegaLite

    dt = DataTable(a=[1, 2, 3], b=[4.0, 5.0, 6.0])
    spec = dt |> @vlplot(:point, x=:a, y=:b)
    @test spec isa VegaLite.VLSpec
    params = VegaLite.Vega.getparams(spec)
    node = params["data"]["values"]
    @test length(node.columns[:a]) == 3
    @test collect(node.columns[:a]) == [1, 2, 3]
    @test collect(node.columns[:b]) == [4.0, 5.0, 6.0]
end

@testitem "vegalite datavalue and arrowstring columns" begin
    using VegaLite
    using DataValues
    using DataTables: ArrowString

    dt = DataTable(
        s=["short", "a string that is longer than twelve"],
        v=[DataValue(1.5), NA],
    )
    @test eltype(dt.s) === ArrowString
    spec = dt |> @vlplot(:point, x=:s, y=:v)
    @test spec isa VegaLite.VLSpec
    node = VegaLite.Vega.getparams(spec)["data"]["values"]
    @test length(node.columns[:s]) == 2
    @test eltype(node.columns[:s]) <: AbstractString
    @test isna(node.columns[:v][2])
end
