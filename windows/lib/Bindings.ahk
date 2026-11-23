; Which Button triggers which Action, on which configured Trigger Key.
ButtonBindings(cfg) {
    return [
        {button: "G6", name: "Focus Claude", trigger: cfg.triggers.focusClaude, action: "FocusClaude"},
        {button: "G7", name: "Send to Claude", trigger: cfg.triggers.sendToClaude, action: "SendToClaude"},
    ]
}

; Run a binding's Action. Returns the Action's result (truthy if it did something).
RunBinding(actions, binding) {
    return actions.%binding.action%()
}
