@testitem "show NA and datavalue" begin
    using DataValues

    dt = DataTable(a=[DataValue(1), NA], s=[DataValue("hi"), NA])
    plain = sprint((io, x) -> show(io, "text/plain", x), dt)
    @test occursin("#NA", plain)
    @test occursin("hi", plain)
    html = sprint((io, x) -> show(io, "text/html", x), dt)
    @test occursin("<table>", html)
    @test occursin("#NA", html)
    json = sprint((io, x) -> show(io, "application/vnd.dataresource+json", x), dt)
    @test occursin("null", json)
    @test occursin("\"type\":\"integer\"", json)
    @test occursin("\"type\":\"string\"", json)
end

@testitem "show temporal" begin
    using Dates

    dt = DataTable(
        d=[Date(2020, 1, 1)],
        t=[Time(12, 30)],
        ts=[DateTime(2020, 1, 1, 12, 30)],
    )
    for mime in ("text/plain", "text/html", "application/vnd.dataresource+json")
        out = sprint((io, x) -> show(io, mime, x), dt)
        @test !isempty(out)
    end
    json = sprint((io, x) -> show(io, "application/vnd.dataresource+json", x), dt)
    @test occursin("\"name\":\"d\",\"type\":\"date\"", json)
    @test occursin("\"name\":\"t\",\"type\":\"time\"", json)
    @test occursin("\"name\":\"ts\",\"type\":\"datetime\"", json)
end

@testitem "show long table truncation" begin
    dt = DataTable(a=collect(1:25))
    plain = sprint(show, dt)
    @test startswith(plain, "25x1 DataTable")
    @test occursin("... with 15 more rows", plain)
    html = sprint((io, x) -> show(io, "text/html", x), dt)
    @test occursin("&vellip;", html)
end

@testitem "show wide table" begin
    dt = DataTable(; (Symbol("column", i) => [i, i + 10] for i in 1:30)...)
    plain = sprint(show, dt)
    @test startswith(plain, "2x30 DataTable")
    @test occursin("more columns:", plain)
end

@testitem "show zero rows" begin
    dt = DataTable(a=Int[])
    plain = sprint(show, dt)
    @test startswith(plain, "0x1 DataTable")
    html = sprint((io, x) -> show(io, "text/html", x), dt)
    @test occursin("<table>", html)
    json = sprint((io, x) -> show(io, "application/vnd.dataresource+json", x), dt)
    @test occursin("\"data\":[]", json)
end

@testitem "show zero columns" begin
    dt = DataTable()
    plain = sprint(show, dt)
    @test startswith(plain, "0x0 DataTable")
    html = sprint((io, x) -> show(io, "text/html", x), dt)
    @test occursin("<table>", html)
    json = sprint((io, x) -> show(io, "application/vnd.dataresource+json", x), dt)
    @test !isempty(json)
end

@testitem "show html escaping" begin
    dt = DataTable(s=["<b>", "a&b", "say \"hi\""])
    html = sprint((io, x) -> show(io, "text/html", x), dt)
    @test occursin("&lt;b&gt;", html)
    @test occursin("a&amp;b", html)
    @test occursin("&quot;", html)
    @test !occursin("<b>", html)
end

@testitem "dataresource bool missing arrowstring" begin
    using DataValues

    dt = DataTable(
        b=[true, false],
        m=[DataValue(1.5), NA],
        s=["plain", "a string that is longer than twelve bytes"],
    )
    json = sprint((io, x) -> show(io, "application/vnd.dataresource+json", x), dt)
    @test occursin("\"name\":\"b\",\"type\":\"boolean\"", json)
    @test occursin("\"name\":\"m\",\"type\":\"number\"", json)
    @test occursin("\"name\":\"s\",\"type\":\"string\"", json)
    @test occursin("true", json)
    @test occursin("false", json)
    @test occursin("null", json)
    @test occursin("a string that is longer than twelve bytes", json)
end
