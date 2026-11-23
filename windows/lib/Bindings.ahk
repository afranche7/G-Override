; Which Button triggers which Action, on which configured Trigger Key.
ButtonBindings(cfg) {
    return [
        {button: "G6", name: "Focus Claude", trigger: cfg.triggers.focusClaude, action: "FocusClaude"},
    ]
}

; Run a binding's Action. Returns the Action's result (truthy if it did something).
RunBinding(actions, binding) {
    return actions.%binding.action%()
}
