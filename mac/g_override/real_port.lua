-- The real OS port: thin wrappers over Hammerspoon's hs.* modules.
-- Keep logic out of here; it belongs in the Action layer, where it is tested.
local bindings = require("g_override.bindings")  -- parses neutral key specs like "cmd+v"
local paletteMenu = require("g_override.palette_menu")

local M = {}
M.__index = M

function M.new()
  return setmetatable({}, M)
end

local function describe(app)
  if not app then return nil end
  return { id = app:pid(), bundleId = app:bundleID(), name = app:name() }
end

-- The frontmost app, with its focused window's title (for Send to Claude's source line) and ID
-- (for Window Snip).
function M:frontmostApp()
  local app = hs.application.frontmostApplication()
  local out = describe(app)
  if out then
    local win = app:focusedWindow()
    out.title = win and win:title() or ""
    out.windowId = win and win:id() or nil
  end
  return out
end

function M:findAppByBundleId(bundleId)
  local apps = hs.application.applicationsForBundleID(bundleId)
  return describe(apps and apps[1])
end

function M:findAppByName(name)
  return describe(hs.application.get(name))
end

function M:appRunning(id)
  return hs.application.applicationForPID(id) ~= nil
end

function M:activate(id)
  local app = hs.application.applicationForPID(id)
  if app then app:activate() end
end

-- Starts the app and waits (up to timeoutMs) for its first window. hs.application.open runs the
-- wait inside Hammerspoon's run loop, so the app list stays current while we wait.
function M:launch(bundleId, name, timeoutMs)
  local seconds = (timeoutMs or 15000) / 1000
  if not hs.application.open(bundleId, seconds, true) then
    hs.application.open(name, seconds, true)
  end
end

-- Inside a coroutine (how g-override.lua runs Actions), hand the time back to Hammerspoon's run
-- loop so hotkeys, timers and hs.task keep working while an Action waits. Elsewhere, block.
function M:sleep(ms)
  if coroutine.applicationYield and coroutine.isyieldable() then
    coroutine.applicationYield(ms / 1000)
  else
    hs.timer.usleep(ms * 1000)
  end
end

function M:toast(msg)
  hs.alert.show(msg, 2)
end

-- The file's text, or nil and an error message.
function M:readFile(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local text = f:read("a")
  f:close()
  return text
end

-- The Prompt Palette's chooser at the cursor. Returns the picked entry, or nil if dismissed.
function M:showPalette(items)
  return paletteMenu.show(items, function(ms) self:sleep(ms) end)
end

-- --- clipboard ---------------------------------------------------------------

function M:clipboardChangeCount() return hs.pasteboard.changeCount() end
function M:clipboardText() return hs.pasteboard.readString() or "" end
function M:clipboardHasImage() return hs.pasteboard.typesAvailable().image == true end
-- Every representation of the clipboard's first item (text, rich text, image...), keyed by UTI.
function M:clipboardBackup() return hs.pasteboard.readAllData() or {} end

function M:clipboardRestore(backup)
  if next(backup) then
    hs.pasteboard.writeAllData(backup)
  else
    hs.pasteboard.clearContents()
  end
end

function M:clipboardClear() hs.pasteboard.clearContents() end
function M:clipboardSetText(s) hs.pasteboard.setContents(s) end

-- --- input / capture ---------------------------------------------------------

local KEY_NAMES = { enter = "return" }  -- neutral key names -> hs.keycodes.map names

-- Presses a neutral key spec such as "cmd+c" in the frontmost app.
function M:send(keys)
  local mods, key = bindings.toHotkey(keys)
  hs.eventtap.keyStroke(mods, KEY_NAMES[key] or key, 20000)
end

-- macOS's own interactive capture (drag a region, Space for a window, Esc to cancel), straight to
-- the clipboard. screencapture exits when the user finishes or cancels. Returns false if it can't start.
function M:startRegionCapture()
  local task = hs.task.new("/usr/sbin/screencapture", nil, { "-i", "-c" })
  self.regionTask = task and task:start() and task or nil
  return self.regionTask ~= nil
end

function M:regionCaptureOpen()
  return self.regionTask ~= nil and self.regionTask:isRunning()
end

-- One window, by its ID, straight to the clipboard: no shadow (-o), no shutter sound (-x).
-- Returns false if screencapture can't start.
function M:captureWindow(windowId)
  local task = hs.task.new("/usr/sbin/screencapture", nil, { "-x", "-o", "-c", "-l", tostring(windowId) })
  return task ~= nil and task:start() ~= false
end

return M
