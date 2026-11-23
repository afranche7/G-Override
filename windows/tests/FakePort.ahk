; In-memory stand-in for the OS port. Records what the Action layer did so tests can
; assert on observable effects: which window is active, what was pasted where, which
; keys were sent, and what the clipboard holds afterwards.
class FakePort {
    __New() {
        this.windows := []          ; [{id, exe, path, title}]
        this.activeId := 0
        this.clipText := ""
        this.clipImage := ""        ; "" or an image label, e.g. "region" / "window:Chrome"
        this.seq := 1
        this.selection := ""        ; text the active app copies when its copy key is pressed
        this.copyKeyHonoured := ""  ; if set, only this copy key copies the selection
        this.pendingLaunch := ""    ; window that appears after Launch + a Sleep
        this.launchedAppId := ""
        this.regionResult := ""     ; "image" -> a region capture lands on the clipboard; "" -> cancelled
        this.paletteChoice := ""    ; title of the Palette Entry the user picks; "" -> dismissed
        this.paletteShown := ""     ; entries passed to ShowPalette
        this.paletteStealsFocus := false  ; the palette menu takes focus away from the active window
        this.files := Map()         ; path -> text, for ReadFile
        this.sent := []             ; neutral key specs sent, in order
        this.pasted := []           ; [{target, text, image}]
        this.toasts := []
        this.sleptMs := 0
        this.regionCaptures := 0
    }

    AddWindow(id, exe, path, title) {
        w := {id: id, exe: exe, path: path, title: title}
        this.windows.Push(w)
        return w
    }

    ; --- windows -----------------------------------------------------------
    ActiveWindow() {
        for w in this.windows
            if w.id = this.activeId
                return w
        return ""
    }
    FindWindows(exe) {
        out := []
        for w in this.windows
            if w.exe = exe
                out.Push(w)
        return out
    }
    WindowExists(id) {
        for w in this.windows
            if w.id = id
                return true
        return false
    }
    Activate(id) {
        this.activeId := id
    }
    Launch(appId) {
        this.launchedAppId := appId
    }
    Sleep(ms) {
        this.sleptMs += ms
        if IsObject(this.pendingLaunch) && this.launchedAppId != "" {
            this.windows.Push(this.pendingLaunch)
            this.pendingLaunch := ""
        }
    }

    ; --- clipboard ---------------------------------------------------------
    ClipboardSeq() => this.seq
    ClipboardText() => this.clipImage != "" ? "" : this.clipText
    ClipboardHasImage() => this.clipImage != ""
    ClipboardBackup() => {text: this.clipText, image: this.clipImage}
    ClipboardRestore(b) {
        this.clipText := b.text
        this.clipImage := b.image
        this.seq += 1
    }
    ClipboardClear() {
        this.clipText := ""
        this.clipImage := ""
        this.seq += 1
    }
    ClipboardSetText(s) {
        this.clipText := s
        this.clipImage := ""
        this.seq += 1
    }

    ; --- input / capture ---------------------------------------------------
    Send(keys) {
        this.sent.Push(keys)
        if keys = "ctrl+c" || keys = "ctrl+shift+c" || keys = "cmd+c" {
            if this.selection != "" && (this.copyKeyHonoured = "" || this.copyKeyHonoured = keys)
                this.ClipboardSetText(this.selection)
        } else if keys = "ctrl+v" || keys = "cmd+v" {
            this.pasted.Push({target: this.activeId, text: this.ClipboardText(), image: this.clipImage})
        }
    }
    StartRegionCapture() {
        this.regionCaptures += 1
        if this.regionResult = "image" {
            this.clipImage := "region"
            this.seq += 1
        }
    }
    CaptureActiveWindow() {
        w := this.ActiveWindow()
        this.clipImage := "window:" (IsObject(w) ? w.title : "")
        this.seq += 1
    }
    ShowPalette(entries) {
        this.paletteShown := entries
        if this.paletteStealsFocus
            this.activeId := 0
        if this.paletteChoice = ""
            return ""
        for e in entries
            if e.kind = "entry" && e.title = this.paletteChoice
                return e
        throw Error("FakePort: no palette entry titled " this.paletteChoice)
    }
    ReadFile(path) {
        if !this.files.Has(path)
            throw Error("FakePort: no such file " path)
        return this.files[path]
    }
    Toast(msg) {
        this.toasts.Push(msg)
    }

    ; --- helpers for assertions ------------------------------------------
    SentEnter() {
        for k in this.sent
            if k = "enter"
                return true
        return false
    }
}
