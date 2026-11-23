; Pure text helpers used by the Action layer (no OS access).

; "From chrome — localhost:3000 - Google Chrome": where a Selection came from.
SourceLine(exe, title) {
    app := RegExReplace(exe, "i)\.exe$")
    return "From " app (title != "" ? " — " title : "")
}

; Wrap text in a Markdown code fence that is longer than any backtick run inside it,
; so the text can't close the fence early. Ends with a newline.
FencedBlock(text) {
    text := RTrim(StrReplace(text, "`r`n", "`n"), "`n")
    longest := 0
    pos := 1
    while pos := RegExMatch(text, "``+", &m, pos) {
        longest := Max(longest, m.Len)
        pos += m.Len
    }
    fence := StrRepeat("``", Max(3, longest + 1))
    return fence "`n" text "`n" fence "`n"
}

StrRepeat(s, n) {
    out := ""
    loop n
        out .= s
    return out
}

; The copy key for the active app: terminals get their own so Ctrl+C never interrupts anything.
CopyKeyFor(exe, cfg) {
    for t in cfg.terminals
        if t = exe  ; case-insensitive
            return cfg.terminalCopyKey
    return cfg.defaultCopyKey
}
