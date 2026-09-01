@testitem "string multibyte straddle" begin
    using DataTables: ArrowString

    strs = [
        repeat("a", 10) * "é",    # 12 codeunits — inline
        repeat("a", 11) * "é",    # 13 codeunits — view
        repeat("a", 8) * "😀",    # 12 codeunits — inline
        repeat("a", 9) * "😀",    # 13 codeunits — view
        "é" * repeat("x", 9),   # combining accent, 12 codeunits
        "é" * repeat("x", 10),  # combining accent, 13 codeunits
    ]
    @test ncodeunits(strs[1]) == 12 && ncodeunits(strs[2]) == 13
    @test ncodeunits(strs[3]) == 12 && ncodeunits(strs[4]) == 13
    @test ncodeunits(strs[5]) == 12 && ncodeunits(strs[6]) == 13

    dt = DataTable(s=strs)
    @test dt.s == strs
    for (a, o) in zip(dt.s, strs)
        @test a isa ArrowString
        @test collect(a) == collect(o)      # char-level iteration
        @test length(a) == length(o)
        @test String(a) == o
    end
end

@testitem "string special chars" begin
    strs = ["a,b", "say \"hi\"", "line1\nline2", "tab\there", "<b>&amp;</b>", "back\\slash"]
    dt = DataTable(s=strs)
    @test dt.s == strs
    @test String.(collect(dt.s)) == strs
end

@testitem "string very long and column shapes" begin
    using DataTables: arrowfield, arrowdata
    import DataTables.ArrowCore

    long = repeat("abcdefghij", 150)   # 1500 bytes
    mixed = DataTable(s=["tiny", long, "twelve chars", repeat("é", 400)])
    @test ncodeunits(mixed.s[2]) == 1500
    @test mixed.s[2] == long
    @test mixed.s[4] == repeat("é", 400)

    allview = DataTable(s=[repeat("v", 13 + i) for i in 1:20])
    allinline = DataTable(s=[repeat("i", i % 13) for i in 1:20])
    for t in (mixed, allview, allinline)
        ArrowCore.validate_full(arrowfield(t, :s), arrowdata(t, :s))
    end
    @test allview.s[20] == repeat("v", 33)
    @test allinline.s[13] == ""
end

@testitem "string hash and collections" begin
    dt = DataTable(s=["short", "a string that is longer than twelve bytes"])
    for i in 1:2
        @test hash(dt.s[i]) == hash(String(dt.s[i]))
        @test isequal(dt.s[i], String(dt.s[i]))
    end
    @test dt.s[1] in Set(["short", "other"])
    d = Dict(dt.s[1] => 1, dt.s[2] => 2)
    @test d["short"] == 1
    @test d["a string that is longer than twelve bytes"] == 2
end

@testitem "nullable string boundaries" begin
    using DataValues
    import DataTables.ArrowCore
    using DataTables: arrowfield, arrowdata

    col = [
        DataValue(repeat("a", 12)),
        NA,
        DataValue(repeat("b", 13)),
        NA,
        DataValue(""),
    ]
    dt = DataTable(s=col)
    @test dt.s[1] == DataValue(repeat("a", 12))
    @test isna(dt.s[2])
    @test dt.s[3] == DataValue(repeat("b", 13))
    @test isna(dt.s[4])
    @test dt.s[5] == DataValue("")
    @test ArrowCore.nullcount(arrowdata(dt, :s)) == 2
    ArrowCore.validate_full(arrowfield(dt, :s), arrowdata(dt, :s))
    @test true
end
