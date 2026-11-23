---
name: g-override
description: Set up G-Override on this machine. Detects the OS, runs the installer, walks through the Onboard Profile guide, runs the G6/G7/G8 button test with debug toasts, then runs doctor. Use when the user types /g-override or asks to set up or verify G-Override.
---

# /g-override

Set up and verify G-Override on this machine. Work from the repo root (the folder containing `install.ps1`). Terms (Button, Trigger Key, Onboard Profile, Helper) are defined in `CONTEXT.md`.

## 1. Install

Detect the OS and run the matching installer. Both are safe to re-run.

- Windows: `powershell -ExecutionPolicy Bypass -File .\install.ps1`
- macOS: `./install.sh` (then, if the output says so, have the user grant Hammerspoon **Accessibility** and **Screen Recording** in System Settings > Privacy & Security and choose Reload Config from the Hammerspoon menu bar icon)

If the installer fails, show the error and stop; don't improvise around it.

## 2. Onboard Profile (the only manual step)

Read `docs/onboard-profile.md` and walk the user through it step by step: assign G6/G7/G8 to their Trigger Keys in G HUB, save to the Onboard Profile, turn on onboard memory mode. Remind them it must be done on both machines. If F17+ can't be assigned, use the fallback in that guide (config change only). Wait for the user to confirm before continuing.

## 3. Button test

1. Turn debug on: set `enabled=1` under `[debug]` in `config.local.ini` (create the section if missing; keep other keys).
2. Restart the Helper so it re-reads the config: Windows `.\install.ps1 -SkipSkills`; macOS ask the user to choose Reload Config from the Hammerspoon menu bar icon.
3. Ask the user to press G6, then G7, then G8, one at a time. Each press shows a toast like `G-Override: G6 -> Focus Claude (F17)`. Ask the user to confirm each toast. After G7 or G8 opens a crosshair or the palette, tell them to press Esc.
4. If a Button shows no toast: check the Trigger Key in `config.local.ini`/`config.ini` against the Onboard Profile, and on Windows check `%TEMP%\g-override.log`. Fix and retest that Button.

Don't move on until all three are confirmed.

## 4. Debug off and doctor

1. Set `enabled=0` under `[debug]` in `config.local.ini` and restart/reload the Helper as above.
2. Run doctor: Windows `.\install.ps1 -Doctor`; macOS `./install.sh --doctor`. Report any `[!!]` line with its hint; everything should be green.

## 5. Palette

Tell the user the Prompt Palette (G8) is the file `palette.md` at the repo root. Each `## Title` is an entry; the body is inserted into the Claude prompt; `@region-snip`/`@window-snip` run a capture; `send: true` as the first body line submits. Edits apply the next time G8 is pressed, with no reload. The header comment in the file lists all the syntax.

## Finish

Summarise: what was installed, which Buttons were confirmed, that debug is off, the doctor result.
