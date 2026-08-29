using Documenter, DataTables

makedocs(
	modules=[DataTables],
    sitename="DataTables.jl",
    format = Documenter.HTML(analytics = "UA-132838790-1"),
    warnonly = [:missing_docs],
	pages=[
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo="github.com/queryverse/DataTables.jl.git"
)
