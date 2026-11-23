; Shared config + local overrides, and Trigger Key / key-spec translation to AHK syntax.

Test("Config defaults come from the shared config.ini", () => (
    cfg := TestConfig(),
    AssertEq(cfg.triggers.focusClaude, "F17"),
    AssertEq(cfg.triggers.sendToClaude, "F18"),
    AssertEq(cfg.triggers.promptPalette, "F19"),
    AssertEq(cfg.debug, false),
    AssertContains(T_Str(cfg.terminals), "WindowsTerminal.exe")
))

Test("config.local.ini overrides individual keys and leaves the rest", () => (
    localIni := A_Temp "\g-override-test-local.ini",
    FileExist(localIni) ? FileDelete(localIni) : 0,
    IniWrite("ctrl+alt+shift+F10", localIni, "triggers", "focus_claude"),
    IniWrite("1", localIni, "debug", "enabled"),
    cfg := LoadConfig(REPO_ROOT "\config.ini", localIni),
    FileDelete(localIni),
    AssertEq(cfg.triggers.focusClaude, "ctrl+alt+shift+F10"),
    AssertEq(cfg.triggers.sendToClaude, "F18"),
    AssertEq(cfg.debug, true)
))

Test("Trigger Keys translate to AHK hotkey syntax", () => (
    AssertEq(ToAhkHotkey("F17"), "F17"),
    AssertEq(ToAhkHotkey("ctrl+alt+shift+F10"), "^!+F10"),
    AssertEq(ToAhkHotkey("Ctrl+Shift+F12"), "^+F12")
))

Test("Key specs translate to AHK Send syntax", () => (
    AssertEq(ToAhkSend("ctrl+v"), "^v"),
    AssertEq(ToAhkSend("ctrl+shift+c"), "^+c"),
    AssertEq(ToAhkSend("enter"), "{Enter}"),
    AssertEq(ToAhkSend("alt+printscreen"), "!{PrintScreen}")
))
