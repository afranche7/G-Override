; Palette file parsing, and the Prompt Palette (G8) + Window Snip against the fake OS port.

Titles(entries) {
    s := ""
    for e in entries
        s .= (s != "" ? "|" : "") (e.kind = "separator" ? "---" : e.title)
    return s
}

; --- parser ----------------------------------------------------------------

Test("Palette: each ## heading is an entry whose body is the text to insert", () => (
    e := ParsePalette("## First`nhello world`n`n## Second`nline one`nline two`n"),
    AssertEq(e.Length, 2),
    AssertEq(e[1].kind, "entry"),
    AssertEq(e[1].title, "First"),
    AssertEq(e[1].body, "hello world"),
    AssertEq(e[2].body, "line one`nline two"),
    AssertFalse(e[1].send)
))

Test("Palette: a leading send: true line marks auto-submit and is not part of the body", () => (
    e := ParsePalette("## Go`nsend: true`n/implement`n`n## Wait`n/grill`n"),
    AssertTrue(e[1].send),
    AssertEq(e[1].body, "/implement"),
    AssertFalse(e[2].send),
    e2 := ParsePalette("## X`nSend:  TRUE`nhi"),
    AssertTrue(e2[1].send)
))

Test("Palette: send: false is the default and the line is still not part of the body", () => (
    e := ParsePalette("## X`nsend: false`nhi"),
    AssertFalse(e[1].send),
    AssertEq(e[1].body, "hi")
))

Test("Palette: @region-snip and @window-snip bodies are capture actions, not text", () => (
    e := ParsePalette("## Region Snip`n@region-snip`n`n## Window Snip`n@window-snip`n"),
    AssertEq(e[1].action, "region-snip"),
    AssertEq(e[2].action, "window-snip"),
    t := ParsePalette("## Text`nhello"),
    AssertEq(t[1].action, "")
))

Test("Palette: an unknown @action is treated as plain text", () => (
    e := ParsePalette("## Odd`n@nonsense"),
    AssertEq(e[1].action, ""),
    AssertEq(e[1].body, "@nonsense")
))

Test("Palette: --- makes a separator and # makes a group label", () => (
    e := ParsePalette("# Skills`n## A`na`n## B`nb`n---`n# Capture`n## C`n@region-snip`n"),
    AssertEq(Titles(e), "Skills|A|B|---|Capture|C"),
    AssertEq(e[1].kind, "group"),
    AssertEq(e[4].kind, "separator")
))

Test("Palette: stray, doubled, leading and trailing separators are dropped", () => (
    e := ParsePalette("---`n## A`na`n---`n---`n## B`nb`n---`n"),
    AssertEq(Titles(e), "A|---|B")
))

Test("Palette: text before the first heading is ignored, blank lines around bodies are trimmed", () => (
    e := ParsePalette("My prompts`nnotes here`n`n## A`n`n`n  body  `n`n`n"),
    AssertEq(e.Length, 1),
    AssertEq(e[1].body, "  body")
))

Test("Palette: CRLF files parse the same as LF", () => (
    e := ParsePalette("## A`r`nsend: true`r`nline1`r`nline2`r`n`r`n## B`r`nx`r`n"),
    AssertEq(e[1].body, "line1`nline2"),
    AssertTrue(e[1].send),
    AssertEq(e[2].title, "B")
))

Test("Palette: malformed input is handled gracefully", () => (
    AssertEq(ParsePalette("").Length, 0),
    AssertEq(ParsePalette("no headings at all`njust text").Length, 0),
    AssertEq(ParsePalette("## `nbody").Length, 0),
    AssertEq(ParsePalette("## Empty body`n`n## Real`nx").Length, 1),
    AssertEq(ParsePalette("## Only send`nsend: true`n").Length, 0),
    AssertEq(ParsePalette("---`n---").Length, 0)
))

Test("Palette: the starter palette has the six Main Flow skills in order, a separator, then both snips", () => (
    e := ParsePalette(FileRead(REPO_ROOT "\palette.md", "UTF-8")),
    AssertEq(Titles(e), "/grill-with-docs|/to-spec|/to-tickets|/implement|/code-review|/retro|---|Region Snip|Window Snip"),
    AssertEq(e[1].body, "/grill-with-docs"),
    AssertEq(e[8].action, "region-snip"),
    AssertEq(e[9].action, "window-snip")
))

Test("Palette: filtering matches titles case-insensitively and drops separators and groups", () => (
    e := ParsePalette("# G`n## /to-spec`na`n## /to-tickets`nb`n---`n## Region Snip`n@region-snip"),
    AssertEq(Titles(FilterPalette(e, "TO-")), "/to-spec|/to-tickets"),
    AssertEq(Titles(FilterPalette(e, "snip")), "Region Snip"),
    AssertEq(FilterPalette(e, "zzz").Length, 0),
    AssertEq(FilterPalette(e, "").Length, e.Length)
))

; --- placeholders ----------------------------------------------------------

Test("Placeholders: {selection} and {clipboard} are replaced where they appear", () => (
    AssertEq(FillPalette("Fix: {selection} (was {clipboard})", "ERR", "old"), "Fix: ERR (was old)"),
    AssertEq(FillPalette("{selection}{selection}", "a", ""), "aa")
))

Test("Placeholders: a replacement containing braces or $ is inserted literally", () => (
    AssertEq(FillPalette("x {selection}", "{clipboard} `$1", "NO"), "x {clipboard} `$1")
))

; --- Prompt Palette action -------------------------------------------------

PALETTE_TEXT := "## /grill-with-docs`n/grill-with-docs`n`n"
    . "## /implement`nsend: true`n/implement`n`n"
    . "## Explain`nExplain this: {selection}`n`n"
    . "## Compare`nCompare {selection} with {clipboard}`n`n"
    . "---`n## Region Snip`n@region-snip`n`n## Window Snip`n@window-snip`n"

NewPaletteWorld() {
    port := FakePort()
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "localhost:3000 - Google Chrome")
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude")
    port.activeId := 100
    port.clipText := "user's clipboard"
    port.files[TestConfig().paletteFile] := PALETTE_TEXT
    return port
}

Test("Prompt Palette lists the palette file's entries", () => (
    port := NewPaletteWorld(),
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(Titles(port.paletteShown), "/grill-with-docs|/implement|Explain|Compare|---|Region Snip|Window Snip")
))

Test("Prompt Palette inserts the picked entry into Claude without submitting", () => (
    port := NewPaletteWorld(),
    port.paletteChoice := "/grill-with-docs",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted.Length, 1),
    AssertEq(port.pasted[1].target, 200),
    AssertEq(port.pasted[1].text, "/grill-with-docs"),
    AssertFalse(port.SentEnter(), "Enter was sent"),
    AssertEq(port.activeId, 200)
))

Test("Prompt Palette sends Enter only for entries marked send: true", () => (
    port := NewPaletteWorld(),
    port.paletteChoice := "/implement",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].text, "/implement"),
    AssertTrue(port.SentEnter(), "Enter should be sent"),
    AssertEq(port.sent[port.sent.Length], "enter")
))

Test("Prompt Palette appends the selection as a fenced block when the entry has no placeholder", () => (
    port := NewPaletteWorld(),
    port.selection := "TypeError: x is undefined",
    port.paletteChoice := "/grill-with-docs",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].text, "/grill-with-docs`n`n" Fence(3) "`nTypeError: x is undefined`n" Fence(3) "`n")
))

Test("Prompt Palette puts the selection where {selection} is, without an extra block", () => (
    port := NewPaletteWorld(),
    port.selection := "boom",
    port.paletteChoice := "Explain",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].text, "Explain this: boom")
))

Test("Prompt Palette {clipboard} is the user's own clipboard, not the captured selection", () => (
    port := NewPaletteWorld(),
    port.selection := "boom",
    port.paletteChoice := "Compare",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].text, "Compare boom with user's clipboard")
))

Test("Prompt Palette with nothing selected inserts the plain entry and blanks {selection}", () => (
    port := NewPaletteWorld(),
    port.paletteChoice := "Explain",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].text, "Explain this:")
))

Test("Prompt Palette captures the selection before the palette opens", () => (
    port := NewPaletteWorld(),
    port.selection := "chosen text",
    port.paletteChoice := "",
    port.paletteStealsFocus := true,
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.sent[1], "ctrl+c")
))

Test("Prompt Palette uses the terminal copy key in a terminal", () => (
    port := NewPaletteWorld(),
    port.AddWindow(300, "WindowsTerminal.exe", "C:\WT\WindowsTerminal.exe", "pwsh"),
    port.activeId := 300,
    port.selection := "x",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.sent[1], "ctrl+shift+c")
))

Test("Dismissing the Prompt Palette does nothing and restores the clipboard", () => (
    port := NewPaletteWorld(),
    port.selection := "some selection",
    port.paletteChoice := "",
    result := Actions(port, TestConfig()).PromptPalette(),
    AssertFalse(result, "should report a no-op"),
    AssertEq(port.pasted.Length, 0),
    AssertEq(port.activeId, 100),
    AssertEq(port.clipText, "user's clipboard"),
    AssertEq(port.sent.Length, 1)
))

Test("Prompt Palette restores the user's clipboard after a pick", () => (
    port := NewPaletteWorld(),
    port.selection := "sel",
    port.paletteChoice := "Explain",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.clipText, "user's clipboard"),
    AssertEq(port.clipImage, "")
))

Test("Prompt Palette picks up palette file edits on the next open", () => (
    port := NewPaletteWorld(),
    a := Actions(port, TestConfig()),
    a.PromptPalette(),
    AssertContains(Titles(port.paletteShown), "Explain"),
    port.files[TestConfig().paletteFile] := "## Brand new`nhello",
    a.PromptPalette(),
    AssertEq(Titles(port.paletteShown), "Brand new")
))

Test("Prompt Palette with a missing or empty palette file toasts and does nothing", () => (
    port := NewPaletteWorld(),
    port.files.Delete(TestConfig().paletteFile),
    AssertFalse(Actions(port, TestConfig()).PromptPalette()),
    AssertEq(port.toasts.Length, 1),
    AssertEq(port.pasted.Length, 0),
    port.files[TestConfig().paletteFile] := "nothing useful",
    AssertFalse(Actions(port, TestConfig()).PromptPalette()),
    AssertEq(port.toasts.Length, 2)
))

Test("The Region Snip entry snips a region and pastes the image into Claude", () => (
    port := NewPaletteWorld(),
    port.selection := "selected but the user wants a snip",
    port.regionResult := "image",
    port.paletteChoice := "Region Snip",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.regionCaptures, 1),
    AssertEq(port.pasted[1].image, "region"),
    AssertEq(port.pasted[1].target, 200),
    AssertEq(port.clipText, "user's clipboard"),
    AssertFalse(port.SentEnter(), "Enter was sent")
))

Test("The Window Snip entry captures the active window and pastes it into Claude", () => (
    port := NewPaletteWorld(),
    port.paletteChoice := "Window Snip",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted.Length, 1),
    AssertEq(port.pasted[1].image, "window:localhost:3000 - Google Chrome"),
    AssertEq(port.pasted[1].target, 200),
    AssertEq(port.clipText, "user's clipboard"),
    AssertFalse(port.SentEnter(), "Enter was sent")
))

Test("Window Snip captures the window the user was in even if the palette menu took focus", () => (
    port := NewPaletteWorld(),
    port.paletteStealsFocus := true,
    port.paletteChoice := "Window Snip",
    Actions(port, TestConfig()).PromptPalette(),
    AssertEq(port.pasted[1].image, "window:localhost:3000 - Google Chrome")
))

Test("Window Snip on its own pastes the active window into Claude", () => (
    port := NewPaletteWorld(),
    Actions(port, TestConfig()).WindowSnip(),
    AssertEq(port.pasted[1].image, "window:localhost:3000 - Google Chrome"),
    AssertEq(port.pasted[1].target, 200),
    AssertEq(port.clipText, "user's clipboard")
))

Test("A cancelled Region Snip from the palette does nothing", () => (
    port := NewPaletteWorld(),
    port.regionResult := "",
    port.paletteChoice := "Region Snip",
    AssertFalse(Actions(port, TestConfig()).PromptPalette()),
    AssertEq(port.pasted.Length, 0),
    AssertEq(port.clipText, "user's clipboard")
))

Test("Palette: <!-- comments --> are ignored, including multi-line ones with # and --- inside", () => (
    e := ParsePalette("<!--`n# not a group`n---`n## not an entry`n-->`n## Real`nhello"),
    AssertEq(Titles(e), "Real")
))
