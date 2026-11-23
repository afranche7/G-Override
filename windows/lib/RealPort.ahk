; The real OS port: thin wrappers over AutoHotkey's window, clipboard and input APIs.
; Keep logic out of here; it belongs in the Action layer, where it is tested.
class RealPort {
    ; --- windows -----------------------------------------------------------
    ActiveWindow() {
        try {
            id := WinExist("A")
            if !id
                return ""
            return {id: id, exe: WinGetProcessName(id), path: WinGetProcessPath(id), title: WinGetTitle(id)}
        }
        return ""
    }
    FindWindows(exe) {
        out := []
        for id in WinGetList("ahk_exe " exe) {
            try out.Push({id: id, exe: exe, path: WinGetProcessPath(id), title: WinGetTitle(id)})
        }
        return out
    }
    WindowExists(id) => WinExist("ahk_id " id) != 0
    Activate(id) {
        try {
            WinActivate("ahk_id " id)
            WinWaitActive("ahk_id " id, , 2)
        }
    }
    Launch(appId) {
        Run('explorer.exe "shell:AppsFolder\' appId '"')
    }
    Sleep(ms) {
        Sleep(ms)
    }

    ; --- clipboard ---------------------------------------------------------
    ClipboardSeq() => DllCall("GetClipboardSequenceNumber", "UInt")
    ClipboardText() => A_Clipboard
    ClipboardHasImage() => DllCall("IsClipboardFormatAvailable", "UInt", 8) || DllCall("IsClipboardFormatAvailable", "UInt", 2)
    ClipboardBackup() => ClipboardAll()
    ClipboardRestore(b) {
        A_Clipboard := b
    }
    ClipboardClear() {
        A_Clipboard := ""
    }
    ClipboardSetText(s) {
        A_Clipboard := s
        ClipWait(1)
    }

    ; --- input / capture ---------------------------------------------------
    Send(keys) {
        SendInput(ToAhkSend(keys))
    }
    StartRegionCapture() {
        Run("ms-screenclip:")
    }
    CaptureActiveWindow() {
        SendInput("!{PrintScreen}")
    }
    ReadFile(path) => FileRead(path, "UTF-8")
    ShowPalette(entries) => PaletteMenu(entries).Show()
    Toast(msg) {
        ToolTip(msg)
        SetTimer(() => ToolTip(), -2000)
    }
}
