; Send to Claude's source line and fenced block, checked against the cases the macOS tests share.

; The cases in tests/format_cases.txt: [{kind: "source line" | "fenced block", app, title, text, want, line}]
FormatCases() {
    path := REPO_ROOT "\tests\format_cases.txt"
    cases := []
    for i, line in StrSplit(FileRead(path, "UTF-8"), "`n", "`r") {
        if RegExMatch(line, "^\[(.+)\]$", &m) {
            cases.Push({kind: m[1], line: i})
        } else if line != "" && SubStr(line, 1, 1) != "#" {
            if !RegExMatch(line, "^([A-Za-z]+): ?(.*)$", &m) || !cases.Length
                throw Error(path ":" i ": can't parse '" line "'")
            cases[cases.Length].%m[1]% := UnescapeCase(m[2])
        }
    }
    return cases
}

; \n, \r, \t and \\ in a case value.
UnescapeCase(s) {
    out := ""
    i := 1
    while i <= StrLen(s) {
        c := SubStr(s, i, 1)
        if c = "\" && i < StrLen(s) {
            n := SubStr(s, ++i, 1)
            c := n == "n" ? "`n" : n == "r" ? "`r" : n == "t" ? "`t" : n
        }
        out .= c
        i += 1
    }
    return out
}

FormatCaseKinds() {
    kinds := Map()
    for c in FormatCases()
        kinds[c.kind] := true
    return kinds
}

Test("Shared formatting cases include both kinds", () => (
    kinds := FormatCaseKinds(),
    AssertTrue(kinds.Has("source line") && kinds.Has("fenced block"), "missing a case kind")
))

for c in FormatCases() {
    if c.kind = "source line"
        Test("Source line for '" c.app "' (format_cases.txt:" c.line ")", ((c) => () => AssertEq(SourceLine(c.app, c.title), c.want))(c))
    else if c.kind = "fenced block"
        Test("Fenced block (format_cases.txt:" c.line ")", ((c) => () => AssertEq(FencedBlock(c.text), c.want))(c))
    else
        Test("format_cases.txt:" c.line " has a known kind", ((c) => () => AssertTrue(false, "unknown case kind '" c.kind "'"))(c))
}
