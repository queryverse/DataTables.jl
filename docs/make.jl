using Documenter, QueryTables

makedocs(
	modules = [QueryTables],
    sitename = "QueryTables.jl",
    format=HTML(analytics="UA-132838790-1"),
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/QueryTables.jl.git"
)
