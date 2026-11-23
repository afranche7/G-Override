# Prints a Hammerspoon init without the G-Override block (and the one blank line install.sh put before it).
# Usage: awk -v b="<begin marker>" -v e="<end marker>" -f strip-block.awk init.lua
# Only a block with BOTH markers is removed; a begin marker with no end marker is left alone.
{ lines[NR] = $0 }
END {
  for (i = 1; i <= NR; i++) if (lines[i] == b) { for (j = i + 1; j <= NR; j++) if (lines[j] == e) { start = i; stop = j; break } ; if (stop) break }
  for (i = 1; i <= NR; i++) {
    if (start && i >= start && i <= stop) continue
    if (start && i == start - 1 && lines[i] == "") continue
    print lines[i]
  }
}
