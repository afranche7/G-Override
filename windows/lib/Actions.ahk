; The Action layer: what each Trigger Key does, expressed only through the OS port.
class Actions {
    static POLL_MS := 50
    static CANCEL_GRACE_MS := 1500  ; how long a closed capture UI may take to deliver its image

    __New(port, cfg) {
        this.port := port
        this.cfg := cfg
        this.prevWindowId := 0
    }

    ; The Claude App's window, never a `claude` CLI window (they share an exe name).
    FindClaude() {
        for w in this.port.FindWindows(this.cfg.claudeExe)
            if InStr(w.path, this.cfg.claudePathMatch) && w.title != ""
                return w
        return ""
    }

    ; Bring the Claude App to the front. With toggle, pressing it while Claude is
    ; already in front goes back to the window the user came from.
    FocusClaude(toggle := true) {
        port := this.port
        active := port.ActiveWindow()
        claude := this.FindClaude()

        if IsObject(claude) && IsObject(active) && active.id = claude.id {
            if toggle && this.prevWindowId && port.WindowExists(this.prevWindowId)
                port.Activate(this.prevWindowId)
            return true
        }

        if IsObject(active)
            this.prevWindowId := active.id

        if !IsObject(claude) {
            if this.cfg.claudeAppId = "" {
                port.Toast("G-Override: the Claude App isn't running and its launch id isn't set; re-run install.ps1")
                return false
            }
            port.Launch(this.cfg.claudeAppId)
            claude := this.WaitFor(() => this.FindClaude(), this.cfg.launchTimeoutMs)
            if !IsObject(claude) {
                port.Toast("G-Override: couldn't start the Claude App")
                return false
            }
        }
        port.Activate(claude.id)
        return true
    }

    ; Put the current Selection into Claude's prompt as a fenced block with its source.
    ; With no Selection, fall back to a Region Snip. Never submits; restores the clipboard.
    SendToClaude() {
        backup := this.port.ClipboardBackup()
        try {
            sel := this.CaptureSelection()
            if !IsObject(sel)
                return this.CaptureRegion()
            this.port.ClipboardSetText(SourceLine(sel.app, sel.title) "`n" FencedBlock(sel.text))
            return this.PasteIntoClaude()
        } finally {
            this.port.ClipboardRestore(backup)
        }
    }

    ; Capture a dragged region and paste the image into Claude's prompt.
    RegionSnip() {
        backup := this.port.ClipboardBackup()
        try return this.CaptureRegion()
        finally this.port.ClipboardRestore(backup)
    }

    ; Open the Prompt Palette at the cursor and run the picked entry. The Selection is captured
    ; first, before the palette takes focus. Dismissing it does nothing.
    PromptPalette() {
        port := this.port
        items := this.LoadPalette()
        if !items.Length
            return false
        userClip := port.ClipboardText()
        origin := port.ActiveWindow()
        backup := port.ClipboardBackup()
        try {
            sel := this.CaptureSelection()
            choice := port.ShowPalette(items)
            if !IsObject(choice)
                return false
            if IsObject(origin)
                port.Activate(origin.id)  ; the palette may have taken focus; snips capture this window
            if choice.action = "region-snip"
                return this.CaptureRegion()
            if choice.action = "window-snip"
                return this.CaptureWindow()

            selText := IsObject(sel) ? sel.text : ""
            text := RTrim(FillPalette(choice.body, selText, userClip), " `t`r`n")  ; a blank {selection} leaves no dangling space
            if selText != "" && !InStr(choice.body, "{selection}")
                text .= "`n`n" FencedBlock(selText)
            port.ClipboardSetText(text)
            if !this.PasteIntoClaude()
                return false
            if choice.send
                port.Send("enter")
            return true
        } finally {
            port.ClipboardRestore(backup)
        }
    }

    ; The palette file's entries, read fresh each time so edits apply immediately.
    LoadPalette() {
        try text := this.port.ReadFile(this.cfg.paletteFile)
        catch {
            this.port.Toast("G-Override: can't read the palette file (" this.cfg.paletteFile ")")
            return []
        }
        items := ParsePalette(text)
        if !items.Length
            this.port.Toast("G-Override: the palette file has no entries (" this.cfg.paletteFile ")")
        return items
    }

    ; Capture the active window and paste the image into Claude's prompt.
    WindowSnip() {
        backup := this.port.ClipboardBackup()
        try return this.CaptureWindow()
        finally this.port.ClipboardRestore(backup)
    }

    ; Copy the active app's Selection via its copy key. Returns {text, app, title}, or ""
    ; when nothing (or only whitespace) was selected. Leaves the copied text on the clipboard;
    ; callers own backing up and restoring it.
    CaptureSelection() {
        port := this.port
        active := port.ActiveWindow()
        if !IsObject(active)
            return ""
        port.ClipboardClear()
        seq := port.ClipboardSeq()
        port.Send(CopyKeyFor(active.exe, this.cfg))
        copied := this.WaitFor(() => port.ClipboardSeq() != seq && port.ClipboardText() != "", this.cfg.copyTimeoutMs)
        if !copied || Trim(port.ClipboardText(), " `t`r`n") = ""
            return ""
        return {text: port.ClipboardText(), app: active.exe, title: active.title}
    }

    ; A dragged-region capture pasted into Claude. The OS capture UI tells us when it has closed,
    ; so a cancel (Esc) ends the wait soon after instead of holding the Button for the full timeout.
    CaptureRegion() {
        port := this.port
        return this.Snip(() => port.StartRegionCapture(), this.cfg.snipTimeoutMs, () => port.RegionCaptureOpen())
    }

    ; The active window captured in one shot and pasted into Claude.
    CaptureWindow() {
        port := this.port
        return this.Snip(() => port.CaptureActiveWindow(), this.cfg.windowSnipTimeoutMs)
    }

    ; Run a capture that puts an image on the clipboard, then paste it into Claude.
    ; Does nothing if no new image arrives within timeoutMs, or (when isCaptureOpen is given) if
    ; the capture UI closed without one, which is how a cancel looks.
    Snip(startCapture, timeoutMs, isCaptureOpen := "") {
        port := this.port
        port.ClipboardClear()
        seq := port.ClipboardSeq()
        startCapture()
        seenOpen := false
        closedMs := 0
        waited := 0
        loop {
            if port.ClipboardSeq() != seq && port.ClipboardHasImage()
                break
            if waited >= timeoutMs
                return false
            if IsObject(isCaptureOpen) {
                if isCaptureOpen()
                    seenOpen := true, closedMs := 0
                else if seenOpen && (closedMs += Actions.POLL_MS) >= Actions.CANCEL_GRACE_MS
                    return false
            }
            port.Sleep(Actions.POLL_MS)
            waited += Actions.POLL_MS
        }
        return this.PasteIntoClaude()
    }

    ; Focus Claude (never toggling away) and paste whatever is on the clipboard. Never submits.
    PasteIntoClaude() {
        if !this.FocusClaude(false)
            return false
        this.port.Send("ctrl+v")
        this.port.Sleep(this.cfg.pasteSettleMs)  ; let Claude read the clipboard before it's restored
        return true
    }

    ; Poll fn() until it returns something truthy or timeoutMs elapses.
    WaitFor(fn, timeoutMs) {
        waited := 0
        loop {
            if (result := fn())
                return result
            if waited >= timeoutMs
                return ""
            this.port.Sleep(Actions.POLL_MS)
            waited += Actions.POLL_MS
        }
    }
}
