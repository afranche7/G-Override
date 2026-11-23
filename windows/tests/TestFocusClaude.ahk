; Focus Claude (G6) scenarios against the fake OS port.

CLAUDE_PATH := "C:\Program Files\WindowsApps\Claude_6.1_x64__pzs8sxrjxfjjc\app\Claude.exe"
CLI_PATH := "C:\Users\dev\AppData\Roaming\Claude\claude-code\2.1\claude.exe"

NewFocusWorld() {
    port := FakePort()
    port.AddWindow(100, "chrome.exe", "C:\chrome.exe", "localhost:3000 - Google Chrome")
    port.activeId := 100
    return port
}

Test("Focus Claude brings the Claude App to the front", () => (
    port := NewFocusWorld(),
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude"),
    Actions(port, TestConfig()).FocusClaude(),
    AssertEq(port.activeId, 200)
))

Test("Focus Claude again toggles back to the previous window", () => (
    port := NewFocusWorld(),
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude"),
    a := Actions(port, TestConfig()),
    a.FocusClaude(),
    a.FocusClaude(),
    AssertEq(port.activeId, 100)
))

Test("Focus Claude stays on Claude if the previous window has closed", () => (
    port := NewFocusWorld(),
    port.AddWindow(200, "Claude.exe", CLAUDE_PATH, "Claude"),
    a := Actions(port, TestConfig()),
    a.FocusClaude(),
    port.windows.RemoveAt(1),
    a.FocusClaude(),
    AssertEq(port.activeId, 200)
))

Test("Focus Claude launches the Claude App when it isn't running, then focuses it", () => (
    port := NewFocusWorld(),
    port.pendingLaunch := {id: 300, exe: "Claude.exe", path: CLAUDE_PATH, title: "Claude"},
    Actions(port, TestConfig()).FocusClaude(),
    AssertEq(port.launchedAppId, "Claude_pzs8sxrjxfjjc!Claude"),
    AssertEq(port.activeId, 300)
))

Test("Focus Claude never picks a CLI claude.exe window", () => (
    port := NewFocusWorld(),
    port.AddWindow(400, "claude.exe", CLI_PATH, "claude - Windows PowerShell"),
    port.pendingLaunch := {id: 300, exe: "Claude.exe", path: CLAUDE_PATH, title: "Claude"},
    Actions(port, TestConfig()).FocusClaude(),
    AssertEq(port.activeId, 300)
))

Test("Focus Claude shows a toast and leaves focus alone if Claude never starts", () => (
    port := NewFocusWorld(),
    Actions(port, TestConfig()).FocusClaude(),
    AssertEq(port.activeId, 100),
    AssertEq(port.toasts.Length, 1)
))
