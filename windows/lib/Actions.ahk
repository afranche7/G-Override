; The Action layer: what each Trigger Key does, expressed only through the OS port.
class Actions {
    static POLL_MS := 50

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
