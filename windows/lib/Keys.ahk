; Translates the neutral key specs used in config and the Action layer
; ("ctrl+alt+shift+F10", "ctrl+v", "enter") into AutoHotkey syntax.

_KeyParts(spec) {
    mods := ""
    parts := StrSplit(spec, "+")
    key := parts.Pop()
    for m in parts {
        switch StrLower(Trim(m)) {
            case "ctrl", "control": mods .= "^"
            case "alt", "option": mods .= "!"
            case "shift": mods .= "+"
            case "win", "cmd", "super": mods .= "#"
            default: throw ValueError("Unknown modifier '" m "' in key spec '" spec "'")
        }
    }
    return {mods: mods, key: Trim(key)}
}

; Hotkey syntax, e.g. "^!+F10".
ToAhkHotkey(spec) {
    p := _KeyParts(spec)
    return p.mods p.key
}

; Send syntax, e.g. "^v", "{Enter}", "!{PrintScreen}". Single characters are sent bare.
ToAhkSend(spec) {
    p := _KeyParts(spec)
    return p.mods (StrLen(p.key) = 1 ? StrLower(p.key) : "{" _KeyName(p.key) "}")
}

_KeyName(k) {
    static names := Map("enter", "Enter", "printscreen", "PrintScreen", "esc", "Esc", "escape", "Esc", "tab", "Tab")
    return names.Has(StrLower(k)) ? names[StrLower(k)] : k
}
