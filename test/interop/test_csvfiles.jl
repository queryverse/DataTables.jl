@testitem "csv roundtrip primitives" begin
    using CSVFiles, FileIO

    mktempdir() do dir
        dt = DataTable(a=[1, 2, 3], b=[1.5, 2.5, 3.5], s=["x", "y", "z"])
        path = joinpath(dir, "f.csv")
        save(path, dt)
        dt2 = load(path) |> DataTable
        @test dt2.a == [1, 2, 3]
        @test dt2.b == [1.5, 2.5, 3.5]
        @test dt2.s == ["x", "y", "z"]
        @test dt2 == dt
    end
end

@testitem "csv roundtrip missing" begin
    using CSVFiles, FileIO
    using DataValues

    mktempdir() do dir
        dt = DataTable(a=[DataValue(1), NA, DataValue(3)], s=[DataValue("x"), NA, DataValue("z")])
        path = joinpath(dir, "f.csv")
        save(path, dt)
        raw = read(path, String)
        @test occursin("NA", raw)
        dt2 = load(path) |> DataTable
        @test eltype(dt2.a) === DataValue{Int}
        @test isna(dt2.a[2])
        @test dt2.a[3] == DataValue(3)
        # In a STRING column the nastring is not distinguishable from the
        # literal string "NA", so TextParse loads it as text — pinned here.
        @test dt2.s[2] == "NA"
        @test dt2.s[1] == "x"
    end
end

@testitem "csv arrowstring writer path" begin
    using CSVFiles, FileIO
    using DataTables: ArrowString

    mktempdir() do dir
        strs = ["short", "a string that is quite a bit longer than twelve bytes", repeat("é", 20)]
        dt = DataTable(s=strs)
        @test eltype(dt.s) === ArrowString    # the writer sees ArrowString cells
        path = joinpath(dir, "f.csv")
        save(path, dt)
        dt2 = load(path) |> DataTable
        @test String.(collect(dt2.s)) == strs
    end
end

@testitem "csv quoting escaping" begin
    using CSVFiles, FileIO

    mktempdir() do dir
        strs = ["a,b", "say \"hi\"", "line1\nline2", "plain"]
        dt = DataTable(s=strs, n=[1, 2, 3, 4])
        path = joinpath(dir, "f.csv")
        save(path, dt)
        raw = read(path, String)
        @test occursin("\"a,b\"", raw)
        @test occursin("\"\"hi\"\"", raw)   # escaped embedded quotes
        dt2 = load(path) |> DataTable
        @test String.(collect(dt2.s)) == strs
        @test dt2.n == [1, 2, 3, 4]
    end
end

@testitem "csv unicode" begin
    using CSVFiles, FileIO

    mktempdir() do dir
        dt = DataTable(; Symbol("名前") => ["あき", "はる"], Symbol("emoji") => ["😀x", "y😀"])
        path = joinpath(dir, "f.csv")
        save(path, dt)
        dt2 = load(path) |> DataTable
        @test propertynames(dt2) == (Symbol("名前"), :emoji)
        @test getproperty(dt2, Symbol("名前")) == ["あき", "はる"]
        @test dt2.emoji == ["😀x", "y😀"]
    end
end

@testitem "csv temporal" begin
    using CSVFiles, FileIO
    using Dates

    mktempdir() do dir
        dt = DataTable(d=[Date(2020, 1, 1), Date(1969, 12, 31)])
        path = joinpath(dir, "f.csv")
        save(path, dt)
        dt2 = load(path) |> DataTable
        @test eltype(dt2.d) === Date
        @test dt2.d == dt.d

        # DateTime columns: pin the observed representation on load
        dtt = DataTable(ts=[DateTime(2020, 1, 1, 12, 30, 45)])
        path2 = joinpath(dir, "g.csv")
        save(path2, dtt)
        dtt2 = load(path2) |> DataTable
        if eltype(dtt2.ts) === DateTime
            @test dtt2.ts == dtt.ts
        else
            # loaded as string; the text still round-trips the value
            @test occursin("2020-01-01T12:30:45", String(dtt2.ts[1]))
        end
    end
end

@testitem "csv headerless and custom delim" begin
    using CSVFiles, FileIO

    mktempdir() do dir
        dt = DataTable(a=[1, 2], b=["x", "y"])

        path = joinpath(dir, "nohdr.csv")
        save(path, dt; header=false)
        dt2 = load(path; header_exists=false) |> DataTable
        @test length(dt2) == 2
        @test collect(DataTables.columns(dt2)[1]) == [1, 2]

        tsvpath = joinpath(dir, "f.tsv")
        save(tsvpath, dt)
        dt3 = load(tsvpath) |> DataTable
        @test dt3.a == [1, 2]
        @test dt3.b == ["x", "y"]

        path3 = joinpath(dir, "semi.csv")
        save(path3, dt; delim=';')
        dt4 = load(path3; delim=';') |> DataTable
        @test dt4.a == [1, 2]
        @test dt4.b == ["x", "y"]
    end
end
