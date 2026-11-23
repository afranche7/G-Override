#!/bin/sh
# Removes what install.sh added: the marked block in ~/.hammerspoon/init.lua.
# Leaves Hammerspoon, its auto-launch setting, Claude skills, config.local.ini and the repo untouched.
set -eu

HS_INIT="$HOME/.hammerspoon/init.lua"
BLOCK_BEGIN='-- >>> G-Override >>>'
BLOCK_END='-- <<< G-Override <<<'

ROOT=$(cd "$(dirname "$0")" && pwd)

if [ ! -f "$HS_INIT" ] || ! grep -qxF -- "$BLOCK_BEGIN" "$HS_INIT" || ! grep -qxF -- "$BLOCK_END" "$HS_INIT"; then
  echo "No complete G-Override block in $HS_INIT; nothing to remove."
else
  tmp="$HS_INIT.g-override.tmp"
  awk -v b="$BLOCK_BEGIN" -v e="$BLOCK_END" -f "$ROOT/mac/strip-block.awk" "$HS_INIT" > "$tmp"
  cat "$tmp" > "$HS_INIT"  # write through, so a symlinked init.lua stays a symlink
  rm -f "$tmp"
  echo "Removed the G-Override block from $HS_INIT"
  HS_CLI=""
  for app in /Applications/Hammerspoon.app "$HOME/Applications/Hammerspoon.app"; do
    [ -x "$app/Contents/Frameworks/hs/hs" ] && HS_CLI="$app/Contents/Frameworks/hs/hs" && break
  done
  [ -n "${G_OVERRIDE_HAMMERSPOON_APP:-}" ] && HS_CLI="$G_OVERRIDE_HAMMERSPOON_APP/Contents/Frameworks/hs/hs"
  if [ -n "$HS_CLI" ] && pgrep -x Hammerspoon >/dev/null 2>&1; then
    "$HS_CLI" -c 'hs.reload()' >/dev/null 2>&1 || true
  fi
fi

echo 'G-Override uninstalled. (Hammerspoon and Claude skills were left installed.)'
