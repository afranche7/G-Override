; Reads the shared config.ini, layering config.local.ini (machine-specific) on top.

LoadConfig(baseIni, localIni := "") {
    get(section, key, default := "") {
        if localIni != "" && FileExist(localIni) {
            v := IniRead(localIni, section, key, Chr(0))
            if v != Chr(0)
                return v
        }
        return IniRead(baseIni, section, key, default)
    }
    num(section, key, default) {
        v := get(section, key, default)
        return IsNumber(v) ? Number(v) : default
    }
    if !FileExist(baseIni)
        throw Error("Config not found: " baseIni)
    terminals := []
    for t in StrSplit(get("copy", "windows_terminals"), ",")
        if (t := Trim(t)) != ""
            terminals.Push(t)
    return {
        triggers: {
            focusClaude: get("triggers", "focus_claude", "F17"),
            sendToClaude: get("triggers", "send_to_claude", "F18"),
            promptPalette: get("triggers", "prompt_palette", "F19"),
        },
        claudeAppId: get("claude", "windows_app_id"),
        claudeExe: get("claude", "windows_exe", "Claude.exe"),
        claudePathMatch: get("claude", "windows_path_match", "\WindowsApps\Claude_"),
        terminals: terminals,
        terminalCopyKey: get("copy", "windows_terminal_copy_key", "ctrl+shift+c"),
        defaultCopyKey: get("copy", "windows_default_copy_key", "ctrl+c"),
        copyTimeoutMs: num("timing", "copy_timeout_ms", 400),
        snipTimeoutMs: num("timing", "snip_timeout_ms", 30000),
        windowSnipTimeoutMs: num("timing", "window_snip_timeout_ms", 2000),
        launchTimeoutMs: num("timing", "launch_timeout_ms", 15000),
        pasteSettleMs: num("timing", "paste_settle_ms", 250),
        paletteFile: ResolvePath(baseIni, get("palette", "file", "palette.md")),
        debug: get("debug", "enabled", "0") = "1",
    }
}

; Relative paths in config are resolved from the folder that holds config.ini (the repo root).
ResolvePath(baseIni, path) {
    if RegExMatch(path, "^([A-Za-z]:[\\/]|[\\/]{2})")
        return path
    return RegExReplace(baseIni, "[\\/][^\\/]*$") "\" StrReplace(path, "/", "\")
}
