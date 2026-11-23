-- Reads the shared config.ini (the same file the Windows Helper reads), layering
-- config.local.ini (machine-specific, git-ignored) on top. Pure Lua: no Hammerspoon needed.
local M = {}

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

-- The Windows installer writes config.local.ini as UTF-16LE; the keys and values we read
-- are ASCII, so dropping the high bytes is enough. A UTF-8 BOM is stripped too.
local function decode(s)
  if s:sub(1, 2) == "\255\254" then
    s = s:sub(3):gsub("(.)%z", "%1")
  end
  return (s:gsub("^\239\187\191", ""))
end

-- INI text -> { [section] = { [key] = value } }, with lower-cased section and key names
-- (AutoHotkey's IniRead is case-insensitive). Lines starting with ; or # are comments.
function M.parseIni(text)
  local out, section = {}, nil
  for line in (decode(text) .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
    if line == "" or line:find("^[;#]") then
      -- skip
    elseif line:find("^%[.*%]$") then
      section = line:sub(2, -2):match("^%s*(.-)%s*$"):lower()
      out[section] = out[section] or {}
    elseif section then
      local key, value = line:match("^([^=]-)%s*=%s*(.*)$")
      if key and key ~= "" then out[section][key:lower()] = value end
    end
  end
  return out
end

-- Relative paths in config are resolved from the folder that holds config.ini (the repo root).
local function resolvePath(baseIni, path)
  if path:find("^/") or path:find("^~") or path:find("^%a:[\\/]") then return path end
  local dir = baseIni:gsub("\\", "/"):match("^(.*)/[^/]*$") or "."
  return dir .. "/" .. path
end

function M.load(baseIni, localIni)
  local baseText = readFile(baseIni)
  if not baseText then error("Config not found: " .. baseIni, 2) end
  local base = M.parseIni(baseText)
  local localText = localIni and readFile(localIni)
  local over = localText and M.parseIni(localText) or {}

  local function get(section, key, default)
    local v = (over[section] or {})[key]
    if v == nil then v = (base[section] or {})[key] end
    if v == nil then return default end
    return v
  end
  local function num(section, key, default)
    return tonumber(get(section, key, default)) or default
  end

  return {
    triggers = {
      focusClaude = get("triggers", "focus_claude", "F17"),
      sendToClaude = get("triggers", "send_to_claude", "F18"),
      promptPalette = get("triggers", "prompt_palette", "F19"),
    },
    claudeBundleId = get("claude", "mac_bundle_id", "com.anthropic.claudefordesktop"),
    claudeAppName = get("claude", "mac_app_name", "Claude"),
    copyTimeoutMs = num("timing", "copy_timeout_ms", 400),
    snipTimeoutMs = num("timing", "snip_timeout_ms", 30000),
    windowSnipTimeoutMs = num("timing", "window_snip_timeout_ms", 2000),
    launchTimeoutMs = num("timing", "launch_timeout_ms", 15000),
    pasteSettleMs = num("timing", "paste_settle_ms", 250),
    paletteFile = resolvePath(baseIni, get("palette", "file", "palette.md")),
    debug = get("debug", "enabled", "0") == "1",
  }
end

return M
