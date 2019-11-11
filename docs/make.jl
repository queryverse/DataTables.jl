using Documenter, DataTables

makedocs(
	modules = [DataTables],
    sitename = "DataTables.jl",
    analytics="UA-132838790-1",
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/DataTables.jl.git"
)
