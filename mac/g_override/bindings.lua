-- Which Button triggers which Action, on which configured Trigger Key; plus Trigger Key parsing.
local M = {}

function M.buttonBindings(cfg)
  return {
    { button = "G6", name = "Focus Claude", trigger = cfg.triggers.focusClaude, action = "focusClaude" },
    { button = "G7", name = "Send to Claude", trigger = cfg.triggers.sendToClaude, action = "sendToClaude" },
    { button = "G8", name = "Prompt Palette", trigger = cfg.triggers.promptPalette, action = "promptPalette" },
  }
end

-- Run a binding's Action. Returns the Action's result (truthy if it did something).
function M.run(actions, binding)
  if actions.cfg.debug then
    actions.port:toast("G-Override: " .. binding.button .. " -> " .. binding.name .. " (" .. binding.trigger .. ")")
  end
  return actions[binding.action](actions)
end

local MODIFIERS = {
  ctrl = "ctrl", control = "ctrl",
  alt = "alt", option = "alt",
  shift = "shift",
  cmd = "cmd", win = "cmd", super = "cmd",
}

-- "ctrl+alt+shift+F10" -> {"ctrl", "alt", "shift"}, "f10" (Hammerspoon's hs.hotkey.bind arguments).
function M.toHotkey(spec)
  local parts = {}
  for p in spec:gmatch("[^+]+") do parts[#parts + 1] = p:match("^%s*(.-)%s*$") end
  local key = table.remove(parts)
  local mods = {}
  for _, m in ipairs(parts) do
    local mod = MODIFIERS[m:lower()]
    if not mod then error("Unknown modifier '" .. m .. "' in key spec '" .. spec .. "'") end
    mods[#mods + 1] = mod
  end
  return mods, key:lower()
end

-- Throws if two Buttons share a Trigger Key (the second would silently replace the first).
function M.check(bindings)
  local seen = {}
  for _, b in ipairs(bindings) do
    local mods, key = M.toHotkey(b.trigger)
    table.sort(mods)
    local id = table.concat(mods, "+") .. "+" .. key
    if seen[id] then
      error("Trigger Key '" .. b.trigger .. "' is used by both " .. seen[id] .. " and " .. b.button, 0)
    end
    seen[id] = b.button
  end
end

return M
