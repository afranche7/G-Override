-- Shared test helpers.
local config = require("g_override.config")

local M = {}

-- The repo root, worked out from this file's own path (…/mac/tests/helpers.lua).
local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local root = source:gsub("/?mac/tests/helpers%.lua$", ""):gsub("^%./?", "")
if not root:find("^/") then
  -- Relative to the working directory (busted runs from the repo root); make it absolute.
  local p = io.popen("pwd")
  local cwd = p and p:read("l") or "."
  if p then p:close() end
  root = root == "" and cwd or (cwd .. "/" .. root)
end
M.REPO_ROOT = root

-- Config as shipped in the repo (no local overrides).
function M.testConfig()
  return config.load(M.REPO_ROOT .. "/config.ini")
end

local ESCAPES = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\" }

-- The formatting cases both Helpers' tests share (tests/format_cases.txt):
-- { {kind = "source line" | "fenced block", app, title, text, want, line}, ... }
function M.formatCases()
  local path = M.REPO_ROOT .. "/tests/format_cases.txt"
  local f = assert(io.open(path, "rb"))
  local cases, n = {}, 0
  for line in f:lines() do
    n = n + 1
    line = line:gsub("\r$", "")
    local kind = line:match("^%[(.+)%]$")
    if kind then
      cases[#cases + 1] = { kind = kind, line = n }
    elseif line ~= "" and not line:find("^#") then
      local key, value = line:match("^(%a+):%s?(.*)$")
      assert(key and #cases > 0, path .. ":" .. n .. ": can't parse '" .. line .. "'")
      cases[#cases][key] = value:gsub("\\(.)", ESCAPES)
    end
  end
  f:close()
  return cases
end

-- The palette parsing cases both Helpers' tests share (tests/palette_cases.txt):
-- { {file, line, items = { {kind, title, body, send, action}, ... }}, ... }
function M.paletteCases()
  local path = M.REPO_ROOT .. "/tests/palette_cases.txt"
  local f = assert(io.open(path, "rb"))
  local cases, n = {}, 0
  for line in f:lines() do
    n = n + 1
    line = line:gsub("\r$", "")
    local file = line:match("^%[(.+)%]$")
    if file then
      cases[#cases + 1] = { file = file, line = n, items = {} }
    elseif line ~= "" and not line:find("^#") then
      local key, value = line:match("^(%a+):%s?(.*)$")
      assert(key and #cases > 0, path .. ":" .. n .. ": can't parse '" .. line .. "'")
      value = value:gsub("\\(.)", ESCAPES)
      local items = cases[#cases].items
      if key == "entry" or key == "group" or key == "separator" then
        items[#items + 1] = { kind = key, title = value, body = "", send = false, action = "" }
      else
        assert(#items > 0 and (key == "body" or key == "send" or key == "action"),
          path .. ":" .. n .. ": unexpected '" .. key .. "'")
        if key == "send" then value = value == "true" end
        items[#items][key] = value
      end
    end
  end
  f:close()
  return cases
end

-- The contents of a file under the repo root.
function M.readRepoFile(rel)
  local f = assert(io.open(M.REPO_ROOT .. "/" .. rel, "rb"))
  local text = f:read("a")
  f:close()
  return text
end

-- A palette item as one comparable line: kind|title|body|send|action.
function M.describeItem(it)
  return table.concat({ it.kind, it.title, it.body, tostring(it.send), it.action }, "|")
end

return M
