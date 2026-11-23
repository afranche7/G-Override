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

## Prompt Palette (G8)

As before, copy `canary` first so you can check the clipboard comes back.

20. With nothing selected, press G8: a chooser opens at the mouse cursor (near a screen edge, it stays on
    screen) listing `/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement`, `/code-review`, `/retro`,
    a separator line, then Region Snip and Window Snip, in that order. The first entry is highlighted.
21. Type `to-`: only `/to-spec` and `/to-tickets` remain. Clear the query: the full list comes back.
22. Press Esc: the chooser closes and nothing else happens. Press G8 and click outside the chooser: same.
23. In Safari or Chrome, select an error message, press G8 and pick `/implement`. The Claude App comes to
    the front and its prompt holds `/implement`, a blank line, then the selection in a ``` fence. Nothing is
    submitted. Cmd+V elsewhere pastes `canary`.
24. Pick the separator line with Enter or a click: nothing happens and the chooser stays open.
25. Pick Region Snip (with or without a selection): macOS's crosshair appears; the dragged region is pasted
    into the Claude App's prompt.
26. In Safari, press G8 and pick Window Snip: an image of the Safari window (no shadow, no shutter sound) is
    pasted into the Claude App's prompt, not an image of the chooser or of Claude.
27. Add `send: true` as the first body line of an entry in `palette.md`, save, press G8 and pick it: the
    text is inserted and submitted. No reload needed. Remove the line again.
28. Break `palette.md` (e.g. rename it), press G8: a toast says the palette file can't be read, and
    `./install.sh --doctor` flags "Config and palette parse". Restore it.

## Uninstall

29. `./uninstall.sh`, then `./install.sh --doctor` reports the init block gone.
