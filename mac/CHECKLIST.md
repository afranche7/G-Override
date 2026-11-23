# macOS manual checklist

The busted tests cover the Action layer and the installer on any machine. These steps need a real Mac,
Hammerspoon and the Claude App, and have not been run yet.

## Setup and Focus Claude (G6)

1. Clone the repo and run `./install.sh`. It installs Hammerspoon (Homebrew), adds the marked block to
   `~/.hammerspoon/init.lua`, starts Hammerspoon and turns on auto-launch.
2. In System Settings > Privacy & Security, grant Hammerspoon **Accessibility** and **Screen Recording**,
   then Hammerspoon menu bar icon > Reload Config.
3. `./install.sh --doctor` reports every check `[ok]`.
4. **Confirm the Claude App's bundle ID** and record it below (and in `config.ini` `mac_bundle_id` if it differs):
   `osascript -e 'id of app "Claude"'`
   - Confirmed bundle ID: _not yet confirmed_ (config.ini currently says `com.anthropic.claudefordesktop`)
5. In G HUB, map G6 to F17, G7 to F18 and G8 to F19 in the Onboard Profile and turn on onboard memory mode.
   (G8 does nothing on the Mac yet.)
6. With another app in front, press G6: the Claude App comes to the front.
7. Press G6 again: you're back in the previous app.
8. Quit the previous app while Claude is in front, press G6: you stay on Claude, no error.
9. Quit the Claude App, press G6: Claude launches and comes to the front.
10. Set `[debug] enabled=1` in `config.local.ini`, reload, press G6: a toast reads `G-Override: G6 -> Focus Claude (F17)`.
    Set it back to 0.

## Send to Claude (G7)

Before each step, copy something of your own (e.g. the word `canary`) so you can check it comes back.

11. In Safari or Chrome, select a few lines of text and press G7. The Claude App comes to the front and
    its prompt holds `From <browser> — <window title>`, then the text in a ``` fence. Nothing is
    submitted. Cmd+V in another app pastes `canary`.
12. In iTerm2, select some output and press G7: same result, with `From iTerm2 — <tab title>`.
    The running command is not interrupted, and nothing is pasted into the terminal.
13. Repeat step 12 in Ghostty.
14. Select text that itself contains a ``` fence and press G7: the block in the prompt uses a ```` fence.
15. With nothing selected, press G7: macOS's crosshair appears. Drag a region: the image is pasted into
    the Claude App's prompt, nothing is submitted, and Cmd+V elsewhere still pastes `canary`.
16. With nothing selected, press G7, then Esc: nothing happens, the Claude App is not brought forward, and
    G7 works again within about two seconds (no 30-second dead Button).
17. Press G7 twice quickly with nothing selected: only one crosshair appears.
18. While a crosshair is open, Hammerspoon stays responsive (its menu bar icon opens) and G6 still works.
19. Copy an image (e.g. Cmd+Ctrl+Shift+4 a region), then G7 a text selection: afterwards Cmd+V pastes
    that image, not the text.

## Uninstall

20. `./uninstall.sh`, then `./install.sh --doctor` reports the init block gone.
