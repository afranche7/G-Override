# Onboard Profile emits Trigger Keys; per-OS Helpers run the Actions

The G502's G6/G7/G8 **Buttons** are mapped to unused **Trigger Keys** (F17/F18/F19) in the mouse's **Onboard Profile**. A small per-OS **Helper** (AutoHotkey v2 on Windows, Hammerspoon on macOS) listens for those keys and runs the **Actions**. G HUB runs in onboard memory mode on both machines.

We rejected two alternatives:

- **G HUB Lua scripting**: it can press keys and play macros, but it can't run processes, query or focus specific windows, or read the clipboard. Those are exactly what **Focus Claude**, **Send to Claude** and the **Prompt Palette** need. It also requires G HUB software mode on every machine, which disables the **Onboard Profile**.
- **A custom cross-platform daemon** (Python, Go): one codebase, but we'd have to rebuild global hotkeys, window focus, clipboard handling and screen capture for each OS. AutoHotkey and Hammerspoon already do all of that.

## Consequences

- The **Onboard Profile** is set once, by hand in G HUB, and then works on any machine the mouse is plugged into. It can't be scripted.
- The **Helper** logic is written twice, once in AutoHotkey and once in Lua. To keep the two from drifting apart, both read the same config file and palette file, and both test their Action layer against a fake OS port with the same scenarios.
