; Button -> Trigger Key -> Action wiring.

Test("Each Button is bound to its configured Trigger Key", () => (
    b := ButtonBindings(TestConfig()),
    AssertEq(b[1].button, "G6"),
    AssertEq(b[1].trigger, "F17"),
    AssertEq(b[1].name, "Focus Claude"),
    AssertEq(b[2].button, "G7"),
    AssertEq(b[2].trigger, "F18"),
    AssertEq(b[2].name, "Send to Claude")
))

Test("Running the G7 binding runs Send to Claude", () => (
    port := FakePort(),
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "Chrome"),
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude"),
    port.activeId := 100,
    port.selection := "hello",
    RunBinding(Actions(port, TestConfig()), ButtonBindings(TestConfig())[2]),
    AssertContains(port.pasted[1].text, "hello")
))

Test("Running the G6 binding runs Focus Claude", () => (
    port := FakePort(),
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "Chrome"),
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude"),
    port.activeId := 100,
    a := Actions(port, TestConfig()),
    RunBinding(a, ButtonBindings(TestConfig())[1]),
    AssertEq(port.activeId, 200)
))

Test("G8 is bound to the Prompt Palette on its configured Trigger Key", () => (
    b := ButtonBindings(TestConfig()),
    AssertEq(b[3].button, "G8"),
    AssertEq(b[3].trigger, "F19"),
    AssertEq(b[3].name, "Prompt Palette")
))

Test("Running the G8 binding opens the Prompt Palette", () => (
    port := FakePort(),
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "Chrome"),
    port.activeId := 100,
    port.files[TestConfig().paletteFile] := "## A`nhello",
    RunBinding(Actions(port, TestConfig()), ButtonBindings(TestConfig())[3]),
    AssertEq(port.paletteShown.Length, 1)
))

Test("Two Buttons on the same Trigger Key are rejected", () => (
    cfg := TestConfig(),
    cfg.triggers.sendToClaude := "f17",
    AssertTrue(Throws(() => CheckBindings(ButtonBindings(cfg))), "expected a duplicate Trigger Key error")
))

Test("Distinct Trigger Keys pass the check", () => (
    CheckBindings(ButtonBindings(TestConfig()))
))
