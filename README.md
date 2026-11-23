# G-Override

Turns the spare buttons on a Logitech G502 into shortcuts for the Claude desktop app, on Windows and macOS.

| Button | Trigger Key | Action |
|---|---|---|
| G6 (sniper) | F17 | **Focus Claude**: bring the Claude App to the front, go back if it's already there, launch it if it isn't running |
| G7 | F18 | **Send to Claude**: put the selected text in the Claude prompt as a fenced block with its source; with nothing selected, snip a region instead |
| G8 | F19 | **Prompt Palette**: a searchable menu at the cursor of prompts (`/grill-with-docs`, `/implement`, ...) and snips |

Nothing is ever submitted unless a palette entry says so, and your clipboard is restored afterwards. See `CONTEXT.md` for the vocabulary.

## Quick start

Easiest: open this folder in Claude Code and run `/g-override`. It installs, guides the one manual step, tests every Button and runs doctor.

Or by hand:

**Windows** (PowerShell, from a fresh clone):

```powershell
.\install.ps1
```

Installs AutoHotkey v2 (winget), starts the Helper at login, installs the Main Flow skills if missing. Check with `.\install.ps1 -Doctor`.

**macOS**:

```sh
./install.sh
```

Installs Hammerspoon (Homebrew) and adds a marked block to `~/.hammerspoon/init.lua`. Grant Hammerspoon **Accessibility** and **Screen Recording** in System Settings > Privacy & Security, then Reload Config. Check with `./install.sh --doctor`.

Then do the manual step: map the Buttons in G HUB. See [docs/onboard-profile.md](docs/onboard-profile.md) (includes the Ctrl+Alt+Shift+F10/F11/F12 fallback).

To remove: `.\uninstall.ps1` / `./uninstall.sh`.

## Manual verification checklists

- macOS: [mac/CHECKLIST.md](mac/CHECKLIST.md)
- Windows: with `[debug] enabled=1`, press G6, G7, G8 and confirm each toast (`/g-override` does this), then set it back to 0. Automated tests: `windows\tests\run.ps1`.

## Config

`config.ini` holds the defaults; put machine-specific overrides in `config.local.ini` (git-ignored, same sections and keys). Main knobs: `[triggers]` (Trigger Keys), `[timing]`, `[debug]`, `[palette] file`. Restart the Helper after changing it (Windows: re-run `.\install.ps1 -SkipSkills`; macOS: Hammerspoon > Reload Config).

## Palette

Edit `palette.md`; the next G8 press uses it, with no reload. Each `## Title` is an entry whose body is inserted into the Claude prompt. `send: true` as the first body line submits, `{selection}` / `{clipboard}` are placeholders, `@region-snip` / `@window-snip` run a capture. The file's header comment has the full syntax.
