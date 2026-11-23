# macOS manual checklist (Focus Claude, G6)

The busted tests cover the Action layer and the installer on any machine. These steps need a real Mac,
Hammerspoon and the Claude App, and have not been run yet.

1. Clone the repo and run `./install.sh`. It installs Hammerspoon (Homebrew), adds the marked block to
   `~/.hammerspoon/init.lua`, starts Hammerspoon and turns on auto-launch.
2. In System Settings > Privacy & Security, grant Hammerspoon **Accessibility** and **Screen Recording**,
   then Hammerspoon menu bar icon > Reload Config.
3. `./install.sh --doctor` reports every check `[ok]`.
4. **Confirm the Claude App's bundle ID** and record it below (and in `config.ini` `mac_bundle_id` if it differs):
   `osascript -e 'id of app "Claude"'`
   - Confirmed bundle ID: _not yet confirmed_ (config.ini currently says `com.anthropic.claudefordesktop`)
5. In G HUB, map G6 to F17 in the Onboard Profile and turn on onboard memory mode.
6. With another app in front, press G6: the Claude App comes to the front.
7. Press G6 again: you're back in the previous app.
8. Quit the previous app while Claude is in front, press G6: you stay on Claude, no error.
9. Quit the Claude App, press G6: Claude launches and comes to the front.
10. Set `[debug] enabled=1` in `config.local.ini`, reload, press G6: a toast reads `G-Override: G6 -> Focus Claude (F17)`.
    Set it back to 0.
11. `./uninstall.sh`, then `./install.sh --doctor` reports the init block gone.
