#!/bin/sh
# Installs the G-Override Helper on macOS (safe to re-run).
#
#   - Installs Hammerspoon via Homebrew if it's missing
#   - Adds a marked block to ~/.hammerspoon/init.lua that loads the Helper (your own config is kept)
#   - Starts Hammerspoon and turns on its auto-launch at login
#   - Installs Matt Pocock's skills (npx) if none of the Main Flow skills are found
#   - Prints the macOS permissions Hammerspoon needs
#
#   ./install.sh               install
#   ./install.sh --doctor      check an existing install without changing anything
#   ./install.sh --no-start    don't start or reload Hammerspoon
#   ./install.sh --skip-skills skip the Claude skills step
set -eu

ROOT=$(cd "$(dirname "$0")" && pwd)
HELPER="$ROOT/mac/g-override.lua"
HS_INIT="$HOME/.hammerspoon/init.lua"
BLOCK_BEGIN='-- >>> G-Override >>>'
BLOCK_END='-- <<< G-Override <<<'
WAIT_S=${G_OVERRIDE_WAIT_S:-15}

DOCTOR=0
NO_START=0
SKIP_SKILLS=0
for arg in "$@"; do
  case "$arg" in
    --doctor) DOCTOR=1 ;;
    --no-start) NO_START=1 ;;
    --skip-skills) SKIP_SKILLS=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# --- helpers -----------------------------------------------------------------

find_hammerspoon() {
  if [ -n "${G_OVERRIDE_HAMMERSPOON_APP:-}" ]; then
    [ -d "$G_OVERRIDE_HAMMERSPOON_APP" ] && echo "$G_OVERRIDE_HAMMERSPOON_APP"
    return 0
  fi
  for app in /Applications/Hammerspoon.app "$HOME/Applications/Hammerspoon.app"; do
    [ -d "$app" ] && { echo "$app"; return 0; }
  done
  return 0
}

find_brew() {
  command -v brew 2>/dev/null && return 0
  for b in ${G_OVERRIDE_BREW_FALLBACKS-/opt/homebrew/bin/brew /usr/local/bin/brew}; do
    [ -x "$b" ] && { echo "$b"; return 0; }
  done
  return 0
}

# Hammerspoon's command-line tool talks to the running Hammerspoon (needs hs.ipc, which the Helper loads).
hs_cli() {
  "$HS_APP/Contents/Frameworks/hs/hs" -c "$1" 2>/dev/null
}

hammerspoon_running() {
  pgrep -x Hammerspoon >/dev/null 2>&1
}

wait_for_hs_cli() {
  i=0
  while [ "$i" -lt "$WAIT_S" ]; do
    hs_cli 'return true' >/dev/null && return 0
    sleep 1
    i=$((i + 1))
  done
  return 1
}

has_block() {
  [ -f "$HS_INIT" ] && grep -qxF -- "$BLOCK_BEGIN" "$HS_INIT" && grep -qxF -- "$BLOCK_END" "$HS_INIT"
}

# Prints $HS_INIT without the G-Override block (shared with uninstall.sh).
init_without_block() {
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -f "$ROOT/mac/strip-block.awk" "$HS_INIT"
}

# Reads [section] key from config.local.ini, falling back to config.ini (names are case-insensitive).
ini_get() {
  for f in "$ROOT/config.local.ini" "$ROOT/config.ini"; do
    [ -f "$f" ] || continue
    v=$(awk -v s="$1" -v k="$2" '
      { sub(/\r$/, "") }
      /^[ \t]*[;#]/ { next }
      /^[ \t]*\[.*\][ \t]*$/ { line = $0; gsub(/^[ \t]*\[[ \t]*|[ \t]*\][ \t]*$/, "", line); in_s = (tolower(line) == tolower(s)); next }
      in_s && index($0, "=") {
        key = substr($0, 1, index($0, "=") - 1); gsub(/^[ \t]+|[ \t]+$/, "", key)
        if (tolower(key) == tolower(k)) { val = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t]+$/, "", val); print val; found = 1; exit }
      }
      END { exit !found }
    ' "$f") && { echo "$v"; return 0; }
  done
  return 1
}

# The Claude App's path, found by bundle ID and then by app name.
find_claude_app() {
  bundle_id=$(ini_get claude mac_bundle_id || echo com.anthropic.claudefordesktop)
  name=$(ini_get claude mac_app_name || echo Claude)
  found=$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null | head -n 1 || true)
  [ -n "$found" ] && { echo "$found"; return 0; }
  for app in "/Applications/$name.app" "$HOME/Applications/$name.app"; do
    [ -d "$app" ] && { echo "$app"; return 0; }
  done
  return 0
}

# --- Main Flow skills --------------------------------------------------------

SKILLS_NPX_ARGS='skills@latest add mattpocock/skills --skill=setup-matt-pocock-skills'

main_flow_skills() {
  ini_get skills main_flow | tr ',' '\n' | awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); if ($0 != "") print }'
}

# A skill is present as a user skill (npx skills installs under ~/.claude/skills or ~/.agents/skills) or inside
# an installed plugin (~/.claude/plugins/cache, or the Claude desktop app's own plugin folder), at any depth.
skill_present() {
  for d in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    [ -f "$d/$1/SKILL.md" ] && return 0
  done
  for d in "$HOME/.claude/plugins/cache" "$HOME/Library/Application Support/Claude/rpm"; do
    [ -d "$d" ] || continue
    [ -n "$(find "$d" -type f -name SKILL.md -path "*/$1/SKILL.md" 2>/dev/null | head -n 1)" ] && return 0
  done
  return 1
}

any_skill_present() {
  for s in $(main_flow_skills); do skill_present "$s" && return 0; done
  return 1
}

install_skills() {
  if [ "$SKIP_SKILLS" = 1 ]; then echo "  Skills: skipped (--skip-skills)."; return 0; fi
  if [ -z "$(main_flow_skills)" ] || any_skill_present; then echo "  Skills: Main Flow skills already installed."; return 0; fi
  if ! command -v npx >/dev/null 2>&1; then
    echo "  npx not found, so Matt Pocock's skills were not installed. Install Node.js, then run:"
    echo "    npx $SKILLS_NPX_ARGS"
    return 0
  fi
  # shellcheck disable=SC2086
  if npx $SKILLS_NPX_ARGS; then echo "  Skills: installed Matt Pocock's skills."
  else echo "  Installing Matt Pocock's skills failed. Retry: npx $SKILLS_NPX_ARGS"; fi
  return 0
}

ALL_OK=1
check() {  # check <ok 0|1> <label> [hint]
  if [ "$1" = 1 ]; then
    echo "  [ok] $2"
  else
    echo "  [!!] $2"
    [ -n "${3:-}" ] && echo "       $3"
    ALL_OK=0
  fi
  return 0
}
yes_if() { if "$@"; then echo 1; else echo 0; fi; }
is_true() { [ "$1" = true ]; }

# --- doctor ------------------------------------------------------------------

doctor() {
  echo "G-Override doctor ($ROOT)"
  HS_APP=$(find_hammerspoon)
  check "$(yes_if [ -n "$HS_APP" ])" "Hammerspoon installed${HS_APP:+ ($HS_APP)}" "Run ./install.sh"
  check "$(yes_if has_block)" "Loaded by Hammerspoon at startup (block in $HS_INIT)" "Run ./install.sh"

  running=0; loaded=""; autolaunch=""; config=""; access=""; screen=""
  if [ -n "$HS_APP" ] && hammerspoon_running; then
    running=1
    loaded=$(hs_cli 'return G_Override ~= nil and G_Override.ok' || true)
    config=$(hs_cli 'return G_Override.check()' 2>&1) || config=""
    autolaunch=$(hs_cli 'return hs.autoLaunch()' || true)
    access=$(hs_cli 'return hs.accessibilityState()' || true)
    screen=$(hs_cli 'return hs.screenRecordingState()' || true)
  fi
  check "$(yes_if is_true "$loaded")" "Helper is running in Hammerspoon" \
    "$( [ "$running" = 1 ] && echo 'Reload Hammerspoon (menu bar icon > Reload Config) and check its Console for errors' || echo 'Start Hammerspoon (or run ./install.sh)')"
  check "$(yes_if [ -n "$config" ])" "Config and palette parse" "Needs Hammerspoon running with the Helper loaded; fix config.ini / config.local.ini / the palette file (Hammerspoon's Console shows the error)"
  check "$(yes_if is_true "$autolaunch")" "Starts at login (Hammerspoon auto-launch)" "Hammerspoon > Preferences > Launch Hammerspoon at login"
  check "$(yes_if is_true "$access")" "Accessibility permission granted to Hammerspoon" \
    "System Settings > Privacy & Security > Accessibility > turn on Hammerspoon"
  check "$(yes_if is_true "$screen")" "Screen Recording permission granted to Hammerspoon" \
    "System Settings > Privacy & Security > Screen Recording > turn on Hammerspoon"
  claude=$(find_claude_app)
  check "$(yes_if [ -n "$claude" ])" "Claude App found${claude:+ ($claude)}" "Install the Claude desktop app from https://claude.ai/download"

  echo "  Main Flow skills:"
  for s in $(main_flow_skills); do
    if skill_present "$s"; then echo "    [ok] $s"; else echo "    [--] $s (missing; run ./install.sh, or install Matt Pocock's skills)"; fi
  done

  if [ "$ALL_OK" = 1 ]; then echo "All good."; return 0; fi
  echo "Some checks failed."
  return 1
}

if [ "$DOCTOR" = 1 ]; then
  doctor
  exit $?
fi

# --- install -----------------------------------------------------------------

echo "Installing G-Override (macOS)..."

# 1. Hammerspoon
HS_APP=$(find_hammerspoon)
if [ -z "$HS_APP" ]; then
  BREW=$(find_brew)
  if [ -z "$BREW" ]; then
    cat >&2 <<'EOF'
Hammerspoon is missing, and Homebrew (used to install it) isn't installed either.
Either:
  - install Homebrew from https://brew.sh, then re-run ./install.sh, or
  - install Hammerspoon yourself from https://www.hammerspoon.org, then re-run ./install.sh
EOF
    exit 1
  fi
  echo "  Installing Hammerspoon via Homebrew..."
  "$BREW" install --cask hammerspoon
  HS_APP=$(find_hammerspoon)
  if [ -z "$HS_APP" ]; then
    echo "Hammerspoon install did not complete. Install it from https://www.hammerspoon.org and re-run." >&2
    exit 1
  fi
fi
echo "  Hammerspoon: $HS_APP"

# 2. Marked block in the Hammerspoon init, replacing any earlier one
mkdir -p "$(dirname "$HS_INIT")"
tmp="$HS_INIT.g-override.tmp"
if [ -f "$HS_INIT" ]; then init_without_block > "$tmp"; else : > "$tmp"; fi
if [ -s "$tmp" ] && [ -n "$(tail -c 1 "$tmp")" ]; then echo >> "$tmp"; fi  # end the user's last line
[ -s "$tmp" ] && echo >> "$tmp"
cat >> "$tmp" <<EOF
$BLOCK_BEGIN
-- Added by G-Override's install.sh; uninstall.sh removes this block. Keep your own config outside it.
G_Override = dofile([==[$HELPER]==])
$BLOCK_END
EOF
cat "$tmp" > "$HS_INIT"  # write through, so a symlinked init.lua stays a symlink
rm -f "$tmp"
echo "  Hammerspoon init: $HS_INIT"

# 3. Main Flow skills
install_skills

# 4. Start or reload Hammerspoon, then turn on auto-launch
if [ "$NO_START" = 1 ]; then
  echo "  Not starting Hammerspoon (--no-start). Reload its config to pick up G-Override."
else
  was_running=0
  if hammerspoon_running; then
    was_running=1
    hs_cli 'hs.reload()' >/dev/null || true  # the connection drops as Hammerspoon reloads
    sleep 1
  else
    open "$HS_APP"
  fi
  if wait_for_hs_cli && hs_cli 'hs.autoLaunch(true)' >/dev/null; then
    echo "  Hammerspoon started; it will launch at login."
  elif [ "$was_running" = 1 ]; then
    echo "  Hammerspoon was already running with a config that can't be reloaded remotely."
    echo "  Reload it (menu bar icon > Reload Config), then re-run ./install.sh to turn on auto-launch."
  else
    echo "  Couldn't reach Hammerspoon. Open it, then turn on Preferences > Launch Hammerspoon at login."
  fi
fi

cat <<'EOF'

Permissions: Hammerspoon needs two macOS permissions. In System Settings > Privacy & Security:
  - Accessibility: turn on Hammerspoon (to send keystrokes and focus apps)
  - Screen Recording: turn on Hammerspoon (to capture snips)
Then reload Hammerspoon (menu bar icon > Reload Config).

Tip (VS Code): G7 with nothing selected should snip, but VS Code copies the whole line on an
  empty selection. Turn that off: Settings > "editor.emptySelectionClipboard" = false.

Done. Next: in G HUB, map G6/G7/G8 to F17/F18/F19 in the mouse's Onboard Profile and turn on onboard memory mode,
then check everything with: ./install.sh --doctor
EOF
