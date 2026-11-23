; Which Button triggers which Action, on which configured Trigger Key.
ButtonBindings(cfg) {
    return [
        {button: "G6", name: "Focus Claude", trigger: cfg.triggers.focusClaude, action: "FocusClaude"},
        {button: "G7", name: "Send to Claude", trigger: cfg.triggers.sendToClaude, action: "SendToClaude"},
        {button: "G8", name: "Prompt Palette", trigger: cfg.triggers.promptPalette, action: "PromptPalette"},
    ]
}

; Run a binding's Action. Returns the Action's result (truthy if it did something).
RunBinding(actions, binding) {
    return actions.%binding.action%()
}

; Throws if two Buttons share a Trigger Key (the second would silently replace the first).
CheckBindings(bindings) {
    seen := Map()
    for b in bindings {
        key := StrLower(ToAhkHotkey(b.trigger))
        if seen.Has(key)
            throw Error("Trigger Key '" b.trigger "' is used by both " seen[key] " and " b.button)
        seen[key] := b.button
    }
}
