; The Prompt Palette's on-screen menu (real OS only; the Action layer reaches it through
; port.ShowPalette). A small popup at the cursor: type to filter, Up/Down to move,
; Enter or double-click to pick, Esc or clicking away to dismiss.
class PaletteMenu {
    static ROWS := 12

    __New(entries) {
        this.entries := entries
        this.rows := []     ; the items currently listed (after filtering)
        this.choice := ""
        this.done := false
    }

    ; Blocks until the user picks or dismisses. Returns the chosen entry, or "".
    Show() {
        CoordMode("Mouse", "Screen")  ; the default is relative to the active window
        MouseGetPos(&mx, &my)
        g := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "G-Override Prompt Palette")
        this.gui := g
        g.MarginX := 8
        g.MarginY := 8
        g.SetFont("s10", "Segoe UI")
        this.edit := g.AddEdit("w340")
        this.list := g.AddListBox("w340 r" PaletteMenu.ROWS " -HScroll")
        g.SetFont("s8 cGray")
        g.AddText("w340", "Type to filter    Enter: insert    Esc: close")
        this.edit.OnEvent("Change", (*) => this.Populate())
        this.list.OnEvent("DoubleClick", (*) => this.Pick())
        this.Populate()

        g.Show("Hide")
        g.GetPos(, , &w, &h)
        PaletteMenu.PlaceNear(mx, my, w, h, &x, &y)
        keyHandler := ObjBindMethod(this, "OnKey")
        OnMessage(0x100, keyHandler)  ; WM_KEYDOWN
        try {
            g.Show("x" x " y" y)
            ; The window only reaches its final size once shown, so place it again with that.
            WinGetPos(, , &w, &h, "ahk_id " g.Hwnd)
            PaletteMenu.PlaceNear(mx, my, w, h, &x, &y)
            WinMove(x, y, , , "ahk_id " g.Hwnd)
            WinActivate("ahk_id " g.Hwnd)
            this.edit.Focus()
            hwnd := g.Hwnd
            wasActive := false
            shownAt := A_TickCount
            while !this.done {
                Sleep(15)
                if WinActive("ahk_id " hwnd)
                    wasActive := true
                else if wasActive
                    this.done := true  ; clicked away
                else if A_TickCount - shownAt > 2000
                    this.done := true  ; never got focus (Windows refused it): don't leave G8 stuck
            }
        } finally {
            OnMessage(0x100, keyHandler, 0)
            g.Destroy()
        }
        return this.choice
    }

    ; Refill the list for the current filter text, selecting the first entry.
    Populate() {
        this.rows := FilterPalette(this.entries, this.edit.Value)
        labels := []
        for it in this.rows
            labels.Push(it.kind = "separator" ? "──────────────" : it.kind = "group" ? "  " it.title : it.title)
        this.list.Delete()
        if labels.Length
            this.list.Add(labels)
        this.Select(this.NextEntry(0, 1))
    }

    ; Index of the next pickable entry from `from`, stepping by `dir` (0 if there is none).
    NextEntry(from, dir) {
        i := from + dir
        while i >= 1 && i <= this.rows.Length {
            if this.rows[i].kind = "entry"
                return i
            i += dir
        }
        return 0
    }

    Select(i) {
        if i >= 1
            this.list.Choose(i)
    }

    Pick() {
        i := this.list.Value
        if i >= 1 && i <= this.rows.Length && this.rows[i].kind = "entry" {
            this.choice := this.rows[i]
            this.done := true
        }
    }

    OnKey(wParam, lParam, msg, hwnd) {
        if hwnd != this.edit.Hwnd && hwnd != this.list.Hwnd
            return
        switch wParam {
            case 0x1B:  ; Esc
                this.done := true
            case 0x0D:  ; Enter
                this.Pick()
            case 0x28:  ; Down
                this.Select(this.NextEntry(this.list.Value, 1) || this.list.Value)
            case 0x26:  ; Up
                this.Select(this.NextEntry(this.list.Value, -1) || this.list.Value)
            default:
                return
        }
        return 0  ; handled
    }

    ; Top-left for a w x h popup near the cursor, kept inside that monitor's work area.
    static PlaceNear(mx, my, w, h, &x, &y) {
        mon := MonitorGetPrimary()
        loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)  ; full bounds, so a cursor over the taskbar still finds its monitor
            if mx >= l && mx < r && my >= t && my < b {
                mon := A_Index
                break
            }
        }
        MonitorGetWorkArea(mon, &left, &top, &right, &bottom)
        x := Max(left, Min(mx, right - w))
        y := Max(top, Min(my, bottom - h))
    }
}
