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

return M
