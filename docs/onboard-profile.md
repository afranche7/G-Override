# Onboard Profile guide (Logitech G HUB)

The **Onboard Profile** is the button mapping saved in the mouse's own memory. The Helpers only listen for the **Trigger Keys** it emits, so this is the one step the installers can't do.

## Steps

1. Open Logitech G HUB and select the G502.
2. Switch the mouse to **Onboard Memory Mode** (the memory/chip toggle in the mouse's settings). Assignments are now saved to the mouse itself.
3. Assign each Button a keystroke:

   | Button | Trigger Key | Action |
   |---|---|---|
   | G6 (sniper) | F17 | Focus Claude |
   | G7 | F18 | Send to Claude |
   | G8 | F19 | Prompt Palette |

   Use the Keystroke assignment, not a macro.
4. Save. G HUB writes the profile to the mouse.
5. **Repeat on the other machine** (Windows and macOS). Once the profile is in onboard memory the mouse carries it, but check each machine's G HUB is also in Onboard Memory Mode so it doesn't override the mouse with a software profile.

Check: with `[debug] enabled=1` in `config.local.ini`, pressing a Button shows a toast naming its Trigger Key (the `/g-override` skill runs this test).

## Fallback: F17+ can't be assigned

Some G HUB versions only offer F1-F12. Assign these instead, with modifiers:

| Button | Trigger Key |
|---|---|
| G6 | Ctrl+Alt+Shift+F10 |
| G7 | Ctrl+Alt+Shift+F11 |
| G8 | Ctrl+Alt+Shift+F12 |

Then change only the config. In `config.local.ini` (git-ignored, applies to this machine):

```ini
[triggers]
focus_claude=ctrl+alt+shift+F10
send_to_claude=ctrl+alt+shift+F11
prompt_palette=ctrl+alt+shift+F12
```

Restart the Helper (Windows: `.\install.ps1 -SkipSkills`; macOS: Hammerspoon menu bar icon > Reload Config) and run the doctor.
