#Requires AutoHotkey v2.0
; Single-instance is handled in Main(): a `--check` run must never replace the running Helper.
#SingleInstance Off
Persistent

; G-Override Helper for Windows: turns the G502's Trigger Keys into Actions.
;   AutoHotkey64.exe g-override.ahk           run the Helper
;   AutoHotkey64.exe g-override.ahk --check   validate config and palette, print the result, exit

#Include lib\Core.ahk
#Include lib\PaletteMenu.ahk
#Include lib\RealPort.ahk

ROOT := RegExReplace(A_LineFile, "\\windows\\g-override\.ahk$")

Main()

Main() {
    global ROOT
    try {
        cfg := LoadConfig(ROOT "\config.ini", ROOT "\config.local.ini")
        bindings := ButtonBindings(cfg)
        CheckBindings(bindings)  ; throws if two Buttons share a Trigger Key
        for b in bindings
            Hotkey(ToAhkHotkey(b.trigger), (*) => 0, "Off")  ; throws on a key AutoHotkey doesn't know
    } catch as e {
        Fail("G-Override config error: " e.Message (e.Extra != "" ? " (" e.Extra ")" : ""))
    }

    if HasArg("--check") {
        try {
            palette := ParsePalette(FileRead(cfg.paletteFile, "UTF-8"))
            if !palette.Length
                throw Error("no entries")
        } catch as e {
            Fail("G-Override palette error: " cfg.paletteFile " (" e.Message ")")
        }
        Out("config ok: " ROOT "\config.ini")
        for b in bindings
            Out("  " b.button " -> " b.name " on " b.trigger)
        n := 0
        for it in palette
            n += it.kind = "entry"
        Out("palette ok: " n " entries in " cfg.paletteFile)
        ExitApp(0)
    }

    CloseOtherInstances()
    helper := Actions(RealPort(), cfg)
    for b in bindings
        Hotkey(ToAhkHotkey(b.trigger), MakeHandler(helper, cfg, b), "On")  ; "On": the validation above left it Off

    A_IconTip := "G-Override (G6/G7/G8 -> Claude)"
    A_TrayMenu.Insert("1&", "Reload G-Override", (*) => Reload())
    A_TrayMenu.Insert("2&")
}

MakeHandler(helper, cfg, b) {
    handler(*) {
        msg := b.button " -> " b.name " (" b.trigger ")"
        if cfg.debug {
            helper.port.Toast("G-Override: " msg)
            DebugLog("trigger " msg)
        }
        try {
            result := RunBinding(helper, b)
            if cfg.debug
                DebugLog("  done: " (result ? "ok" : "no-op"))
        } catch as e {
            DebugLog("  error: " e.Message " " e.Extra)
            helper.port.Toast("G-Override error: " e.Message)
        }
    }
    return handler
}

; Debug mode appends to %TEMP%\g-override.log.
DebugLog(s) {
    try FileAppend(FormatTime(, "HH:mm:ss") " " s "`n", A_Temp "\g-override.log", "UTF-8")
}

; Replace any already-running Helper (what #SingleInstance Force would do, minus --check runs).
CloseOtherInstances() {
    prev := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    for hwnd in WinGetList(A_ScriptFullPath " ahk_class AutoHotkey") {
        if hwnd != A_ScriptHwnd
            try ProcessClose(WinGetPID(hwnd))
    }
    DetectHiddenWindows(prev)
}

HasArg(name) {
    for a in A_Args
        if a = name
            return true
    return false
}

Out(s) {
    try FileAppend(s "`n", "*", "UTF-8")
}

Fail(msg) {
    if HasArg("--check") {
        Out(msg)
        ExitApp(1)
    }
    MsgBox(msg, "G-Override", "Icon!")
    ExitApp(1)
}
