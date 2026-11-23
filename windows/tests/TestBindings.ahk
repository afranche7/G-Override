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
