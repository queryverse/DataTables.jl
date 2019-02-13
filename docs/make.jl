using Documenter, QueryTables

makedocs(
	modules = [QueryTables],
	sitename = "QueryTables.jl",
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/QueryTables.jl.git"
)
