-- G-Override Helper for macOS: turns the G502's Trigger Keys into Actions.
-- Loaded from ~/.hammerspoon/init.lua by the block install.sh adds, which keeps the returned
-- table in the global G_Override. Everything is local to this module otherwise.
local root = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/mac/g%-override%.lua$", "")
package.path = root .. "/mac/?.lua;" .. package.path
-- Reloading Hammerspoon re-runs this file; make sure the modules are re-read as well.
for _, name in ipairs({ "g_override.config", "g_override.format", "g_override.actions", "g_override.bindings", "g_override.real_port" }) do
  package.loaded[name] = nil
end

require("hs.ipc")  -- lets install.sh --doctor query this Helper through the `hs` command-line tool
local config = require("g_override.config")
local bindings = require("g_override.bindings")
local Actions = require("g_override.actions")
local RealPort = require("g_override.real_port")

local M = { root = root, hotkeys = {}, ok = false }

local function loadAll()
  local cfg = config.load(root .. "/config.ini", root .. "/config.local.ini")
  local all = bindings.buttonBindings(cfg)
  bindings.check(all)
  for _, b in ipairs(all) do
    local _, key = bindings.toHotkey(b.trigger)  -- throws on an unknown modifier
    if not hs.keycodes.map[key] then error("Unknown key '" .. key .. "' in Trigger Key '" .. b.trigger .. "'", 0) end
  end
  return cfg, all
end

-- Validates config; used by `install.sh --doctor`. Returns a short description, or throws.
function M.check()
  local _, all = loadAll()
  local parts = {}
  for _, b in ipairs(all) do parts[#parts + 1] = b.button .. " -> " .. b.name .. " on " .. b.trigger end
  return table.concat(parts, ", ")
end

local ok, err = pcall(function()
  local cfg, all = loadAll()
  local helper = Actions.new(RealPort.new(), cfg)
  for _, b in ipairs(all) do
    local mods, key = bindings.toHotkey(b.trigger)
    local busy = false
    M.hotkeys[#M.hotkeys + 1] = hs.hotkey.bind(mods, key, function()
      -- Like AutoHotkey's one thread per hotkey: pressing a Button again while its Action is still
      -- waiting (on a snip, say) is ignored. Other Buttons still work.
      if busy then return end
      busy = true
      -- In a coroutine, the Action's waits yield to Hammerspoon instead of freezing it.
      coroutine.wrap(function()
        local okRun, runErr = pcall(bindings.run, helper, b)
        busy = false
        if not okRun then
          helper.port:toast("G-Override error: " .. tostring(runErr))
          print("G-Override error: " .. tostring(runErr))
        end
      end)()
    end)
  end
end)
M.ok = ok
if not ok then
  hs.alert.show("G-Override config error: " .. tostring(err), 5)
  print("G-Override config error: " .. tostring(err))
end

return M
