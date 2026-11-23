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

return M
