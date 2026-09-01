@testitem "vegadatasets cars" begin
    using VegaDatasets
    using DataValues

    dt = dataset("cars") |> DataTable
    @test length(dt) == 406
    @test length(propertynames(dt)) == 9
    @test eltype(dt.Miles_per_Gallon) <: DataValue
    @test any(isna(x) for x in dt.Miles_per_Gallon)
    @test any(isna(x) for x in dt.Horsepower)
    @test eltype(dt.Name) <: Union{AbstractString,DataValue}
    @test dt[1].Name == "chevrolet chevelle malibu"
end

@testitem "vegadatasets iris" begin
    using VegaDatasets
    using DataValues

    dt = dataset("iris") |> DataTable
    @test length(dt) == 150
    @test !any(isna(x) for x in dt.sepalLength)
    row = dt[1]
    @test row.species == "setosa"
end
