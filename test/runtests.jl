using TestItemRunner

include("test_datatables.jl")
include("test_arrow_storage.jl")
include("test_construction.jl")
include("test_values_numeric.jl")
include("test_values_strings.jl")
include("test_values_missing.jl")
include("test_values_temporal.jl")
include("test_values_fallback.jl")
include("test_table_interface.jl")
include("test_show.jl")
include("test_tabletraits.jl")
include(joinpath("interop", "test_csvfiles.jl"))
include(joinpath("interop", "test_query.jl"))
include(joinpath("interop", "test_vegadatasets.jl"))
include(joinpath("interop", "test_vegalite.jl"))

@run_package_tests
