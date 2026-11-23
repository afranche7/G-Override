; Palette file parsing and placeholder filling (pure; no OS access).
;
; Format (shared with the macOS Helper):
;   ## Title           starts a Palette Entry; the lines below it are its body
;   send: true         optional first body line: submit after inserting
;   @region-snip       whole body: run that capture Action instead of inserting text
;   @window-snip
;   ---                separator
;   # Group            group label
;   {selection} {clipboard}   placeholders in a body
; <!-- ... --> comments and text before the first heading are ignored.

; Returns an array of {kind: "entry"|"separator"|"group", title, body, send, action}.
ParsePalette(text) {
    items := []
    cur := ""
    text := RegExReplace(text, "s)<!--.*?-->")  ; comments
    lines := StrSplit(StrReplace(text, "`r`n", "`n"), "`n")

    flush() {
        if !IsObject(cur)
            return
        entry := cur
        cur := ""
        if entry.title = ""
            return
        body := entry.lines
        while body.Length && Trim(body[1]) = ""
            body.RemoveAt(1)
        ; Not `m`: flush() shares the caller's variables, and the loop below still needs its own match.
        if body.Length && RegExMatch(body[1], "i)^\s*send:\s*(true|false)\s*$", &sendLine) {
            entry.send := StrLower(sendLine[1]) = "true"
            body.RemoveAt(1)
        }
        joined := ""
        for l in body
            joined .= (A_Index > 1 ? "`n" : "") l
        joined := RTrim(joined, " `t`n")
        joined := RegExReplace(joined, "^(\s*\n)+")
        if Trim(joined) = ""
            return
        entry.body := joined
        entry.action := joined = "@region-snip" ? "region-snip" : joined = "@window-snip" ? "window-snip" : ""
        items.Push({kind: "entry", title: entry.title, body: entry.body, send: entry.send, action: entry.action})
    }

    for line in lines {
        t := Trim(line)
        if RegExMatch(t, "^##\s+(.+)$", &m) {
            flush()
            cur := {title: Trim(m[1]), lines: [], send: false}
        } else if RegExMatch(t, "^##\s*$") {
            flush()
            cur := {title: "", lines: [], send: false}
        } else if t = "---" {
            flush()
            items.Push({kind: "separator", title: "", body: "", send: false, action: ""})
        } else if RegExMatch(t, "^#\s+(.+)$", &m) {
            flush()
            items.Push({kind: "group", title: Trim(m[1]), body: "", send: false, action: ""})
        } else if IsObject(cur) {
            cur.lines.Push(line)
        }
    }
    flush()
    return Tidy(items)
}

; Drop separators that lead, trail or repeat, and groups with nothing under them.
Tidy(items) {
    out := []
    for it in items {
        if it.kind = "separator" && (!out.Length || out[out.Length].kind = "separator")
            continue
        out.Push(it)
    }
    ; drop empty groups and trailing separators (a group is empty if the next item isn't an entry)
    cleaned := []
    for i, it in out {
        if it.kind = "group" && !(i < out.Length && out[i + 1].kind = "entry")
            continue
        cleaned.Push(it)
    }
    ; Dropping an empty group can leave a separator first or next to another one.
    out := []
    for it in cleaned {
        if it.kind = "separator" && (!out.Length || out[out.Length].kind = "separator")
            continue
        out.Push(it)
    }
    while out.Length && out[out.Length].kind != "entry"
        out.Pop()
    return out
}

; Entries whose title contains the query (case-insensitive). An empty query keeps everything,
; separators and groups included; a real query shows only matching entries.
FilterPalette(items, query) {
    query := Trim(query)
    if query = ""
        return items
    out := []
    for it in items
        if it.kind = "entry" && InStr(it.title, query)
            out.Push(it)
    return out
}

; Replace {selection} and {clipboard} literally (no regex or $ interpretation of the values).
FillPalette(body, selection, clipboard) {
    body := StrReplace(body, "{selection}", "`0SEL`0")
    body := StrReplace(body, "{clipboard}", "`0CLIP`0")
    body := StrReplace(body, "`0SEL`0", selection)
    return StrReplace(body, "`0CLIP`0", clipboard)
}
