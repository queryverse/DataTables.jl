using TestItemRunner

include("test_datatables.jl")
include("test_arrow_storage.jl")

@run_package_tests
