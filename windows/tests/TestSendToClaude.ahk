; Send to Claude (G7) and Region Snip scenarios against the fake OS port.

; Chrome in front with the user's own text on the clipboard, Claude App running behind.
NewSendWorld() {
    port := FakePort()
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "localhost:3000 - Google Chrome")
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude")
    port.activeId := 100
    port.clipText := "user's clipboard"
    return port
}

LastPaste(port) {
    AssertTrue(port.pasted.Length > 0, "expected something to be pasted")
    return port.pasted[port.pasted.Length]
}

Test("Send to Claude pastes the selection into Claude as a fenced block with its source", () => (
    port := NewSendWorld(),
    port.selection := "TypeError: x is undefined`n    at main.js:12",
    Actions(port, TestConfig()).SendToClaude(),
    p := LastPaste(port),
    AssertEq(p.target, 200),
    AssertEq(p.text, "From chrome — localhost:3000 - Google Chrome`n" Fence(3) "`n"
        . "TypeError: x is undefined`n    at main.js:12`n" Fence(3) "`n")
))

Test("Send to Claude leaves Claude in front and the user's clipboard restored", () => (
    port := NewSendWorld(),
    port.selection := "some text",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.activeId, 200),
    AssertEq(port.clipText, "user's clipboard"),
    AssertEq(port.clipImage, "")
))

Test("Send to Claude restores an image the user had on the clipboard", () => (
    port := NewSendWorld(),
    port.clipText := "",
    port.clipImage := "user's screenshot",
    port.selection := "some text",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.clipImage, "user's screenshot")
))

Test("Send to Claude never sends Enter", () => (
    port := NewSendWorld(),
    port.selection := "some text",
    Actions(port, TestConfig()).SendToClaude(),
    AssertFalse(port.SentEnter(), "Enter was sent")
))

Test("Send to Claude uses a longer fence when the selection contains one", () => (
    port := NewSendWorld(),
    port.selection := "see:`n" Fence(3) "js`nx()`n" Fence(3),
    Actions(port, TestConfig()).SendToClaude(),
    AssertContains(LastPaste(port).text, "`n" Fence(4) "`nsee:"),
    AssertTrue(SubStr(LastPaste(port).text, -6) = "`n" Fence(4) "`n", "should end with a 4-backtick fence")
))

Test("Send to Claude in a terminal uses the terminal copy key, never plain Ctrl+C", () => (
    port := NewSendWorld(),
    port.AddWindow(300, "WindowsTerminal.exe", "C:\WT\WindowsTerminal.exe", "npm run dev"),
    port.activeId := 300,
    port.selection := "ERR! missing script",
    port.copyKeyHonoured := "ctrl+shift+c",
    Actions(port, TestConfig()).SendToClaude(),
    AssertNotContains(T_Str(port.sent), "ctrl+c,"),
    AssertTrue(port.sent[1] = "ctrl+shift+c", "first key sent should be the terminal copy key"),
    AssertContains(LastPaste(port).text, "From WindowsTerminal — npm run dev`n" Fence(3) "`nERR! missing script")
))

Test("Terminal copy-key matching ignores case of the process name", () => (
    port := NewSendWorld(),
    port.AddWindow(300, "powershell.EXE", "C:\ps\powershell.exe", "PS"),
    port.activeId := 300,
    port.selection := "x",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.sent[1], "ctrl+shift+c")
))

Test("Send to Claude works on a selection inside the Claude App itself", () => (
    port := NewSendWorld(),
    port.activeId := 200,
    port.selection := "Claude's own answer",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(LastPaste(port).target, 200),
    AssertContains(LastPaste(port).text, "Claude's own answer")
))

Test("Send to Claude with nothing selected snips a region and pastes the image into Claude", () => (
    port := NewSendWorld(),
    port.regionResult := "image",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.regionCaptures, 1),
    p := LastPaste(port),
    AssertEq(p.target, 200),
    AssertEq(p.image, "region"),
    AssertEq(port.clipText, "user's clipboard"),
    AssertEq(port.clipImage, ""),
    AssertFalse(port.SentEnter(), "Enter was sent")
))

Test("Send to Claude with no window in front snips a region", () => (
    port := NewSendWorld(),
    port.activeId := 0,
    port.selection := "stale text no window owns",
    port.regionResult := "image",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.regionCaptures, 1),
    AssertEq(LastPaste(port).image, "region")
))

Test("A whitespace-only selection counts as nothing selected", () => (
    port := NewSendWorld(),
    port.selection := "  `n ",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(port.regionCaptures, 1)
))

Test("A cancelled or timed-out snip does nothing and restores the clipboard", () => (
    port := NewSendWorld(),
    port.regionResult := "",
    result := Actions(port, TestConfig()).SendToClaude(),
    AssertFalse(result, "should report a no-op"),
    AssertEq(port.regionCaptures, 1),
    AssertEq(port.pasted.Length, 0),
    AssertEq(port.activeId, 100),
    AssertEq(port.clipText, "user's clipboard")
))

Test("Region Snip on its own pastes the captured image into Claude", () => (
    port := NewSendWorld(),
    port.regionResult := "image",
    Actions(port, TestConfig()).RegionSnip(),
    AssertEq(LastPaste(port).image, "region"),
    AssertEq(port.activeId, 200),
    AssertEq(port.clipText, "user's clipboard")
))

Test("Send to Claude launches the Claude App first if it isn't running", () => (
    port := NewSendWorld(),
    port.windows.RemoveAt(2),
    port.pendingLaunch := {id: 300, exe: "Claude.exe", path: CLAUDE_PATH, title: "Claude"},
    port.selection := "x",
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(LastPaste(port).target, 300)
))

Fence(n) => StrRepeat(Chr(96), n)

Test("A cancelled snip returns long before the snip timeout, so the Button isn't dead", () => (
    port := NewSendWorld(),
    port.regionResult := "",
    Actions(port, TestConfig()).SendToClaude(),
    AssertTrue(port.sleptMs < 5000, "waited " port.sleptMs " ms after a cancel")
))

Test("A slow-arriving image just after the capture UI closes is still pasted", () => (
    port := NewSendWorld(),
    port.regionResult := "image",
    port.imageDelayPolls := 5,
    Actions(port, TestConfig()).SendToClaude(),
    AssertEq(LastPaste(port).image, "region")
))
