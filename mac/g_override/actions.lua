-- The Action layer: what each Trigger Key does, expressed only through the OS port.
-- Mirrors windows/lib/Actions.ahk; keep the two behaving the same.
local format = require("g_override.format")

local Actions = {}
Actions.__index = Actions

Actions.POLL_MS = 50
Actions.CANCEL_GRACE_MS = 1500  -- how long a closed capture UI may take to deliver its image
Actions.ACTIVATE_TIMEOUT_MS = 2000  -- how long the Claude App may take to come to the front
Actions.COPY_KEY = "cmd+c"
Actions.PASTE_KEY = "cmd+v"

function Actions.new(port, cfg)
  return setmetatable({ port = port, cfg = cfg, prevAppId = nil }, Actions)
end

-- The Claude App, found by bundle ID and then by app name. Never a `claude` CLI process,
-- which isn't an application bundle with this ID.
function Actions:findClaude()
  return self.port:findAppByBundleId(self.cfg.claudeBundleId)
      or self.port:findAppByName(self.cfg.claudeAppName)
end

-- Poll fn() until it returns something truthy or timeoutMs elapses.
function Actions:waitFor(fn, timeoutMs)
  local waited = 0
  while true do
    local result = fn()
    if result then return result end
    if waited >= timeoutMs then return nil end
    self.port:sleep(Actions.POLL_MS)
    waited = waited + Actions.POLL_MS
  end
end

-- Bring the Claude App to the front. With toggle (the default), pressing it while Claude is
-- already in front goes back to the app the user came from, or stays on Claude if that app is gone.
function Actions:focusClaude(toggle)
  if toggle == nil then toggle = true end
  local port = self.port
  local active = port:frontmostApp()
  local claude = self:findClaude()

  if claude and active and active.id == claude.id then
    if toggle and self.prevAppId and port:appRunning(self.prevAppId) then
      port:activate(self.prevAppId)
    end
    return true
  end

  if active then self.prevAppId = active.id end

  if not claude then
    port:launch(self.cfg.claudeBundleId, self.cfg.claudeAppName, self.cfg.launchTimeoutMs)
    claude = self:waitFor(function() return self:findClaude() end, self.cfg.launchTimeoutMs)
    if not claude then
      port:toast("G-Override: couldn't start the Claude App")
      return false
    end
  end
  port:activate(claude.id)
  return true
end

-- Run fn() and put the user's clipboard back afterwards, even if fn throws.
function Actions:withClipboardRestored(fn)
  local backup = self.port:clipboardBackup()
  local ok, result = pcall(fn)
  self.port:clipboardRestore(backup)
  if not ok then error(result, 0) end
  return result
end

-- Put the current Selection into Claude's prompt as a fenced block with its source.
-- Never submits; restores the clipboard.
function Actions:sendToClaude()
  return self:withClipboardRestored(function()
    local sel = self:captureSelection()
    if not sel then return self:captureRegion() end
    self.port:clipboardSetText(format.sourceLine(sel.app, sel.title) .. "\n" .. format.fencedBlock(sel.text))
    return self:pasteIntoClaude()
  end)
end

-- Copy the frontmost app's Selection with Cmd+C, which never interrupts a terminal.
-- Returns {text, app, title}, or nil when nothing (or only whitespace) was selected. Leaves the
-- copied text on the clipboard; callers own backing up and restoring it.
function Actions:captureSelection()
  local port = self.port
  local active = port:frontmostApp()
  if not active then return nil end
  port:clipboardClear()
  local count = port:clipboardChangeCount()
  port:send(Actions.COPY_KEY)
  local copied = self:waitFor(function()
    return port:clipboardChangeCount() ~= count and port:clipboardText() ~= ""
  end, self.cfg.copyTimeoutMs)
  local text = port:clipboardText()
  if not copied or not text:find("%S") then return nil end
  return { text = text, app = active.name, title = active.title or "" }
end

-- A dragged-region capture pasted into Claude. The OS capture UI tells us when it has closed,
-- so a cancel (Esc) ends the wait soon after instead of holding the Button for the full timeout.
function Actions:captureRegion()
  local port = self.port
  return self:snip(function() return port:startRegionCapture() end, self.cfg.snipTimeoutMs,
    function() return port:regionCaptureOpen() end)
end

-- Run a capture that puts an image on the clipboard, then paste it into Claude. A new image is
-- told apart from an old one by the clipboard's change count. Does nothing if no new image
-- arrives within timeoutMs, or (when isCaptureOpen is given) if the capture UI closed without
-- one, which is how a cancel looks.
function Actions:snip(startCapture, timeoutMs, isCaptureOpen)
  local port = self.port
  port:clipboardClear()
  local count = port:clipboardChangeCount()
  if startCapture() == false then
    port:toast("G-Override: couldn't start the screen capture")
    return false
  end
  local seenOpen, closedMs, waited = false, 0, 0
  while not (port:clipboardChangeCount() ~= count and port:clipboardHasImage()) do
    if waited >= timeoutMs then return false end
    if isCaptureOpen then
      if isCaptureOpen() then
        seenOpen, closedMs = true, 0
      elseif seenOpen then
        closedMs = closedMs + Actions.POLL_MS
        if closedMs >= Actions.CANCEL_GRACE_MS then return false end
      end
    end
    port:sleep(Actions.POLL_MS)
    waited = waited + Actions.POLL_MS
  end
  return self:pasteIntoClaude()
end

-- Focus Claude (never toggling away) and paste whatever is on the clipboard. Never submits.
-- Activation lands a moment after it's asked for, so wait until the Claude App is really in front:
-- pasting early would put the text in the app the user came from, maybe a terminal.
function Actions:pasteIntoClaude()
  local port = self.port
  if not self:focusClaude(false) then return false end
  local claude = self:findClaude()
  local inFront = claude and self:waitFor(function()
    local front = port:frontmostApp()
    return front and front.id == claude.id
  end, Actions.ACTIVATE_TIMEOUT_MS)
  if not inFront then
    port:toast("G-Override: couldn't bring the Claude App to the front")
    return false
  end
  port:send(Actions.PASTE_KEY)
  self.port:sleep(self.cfg.pasteSettleMs)  -- let Claude read the clipboard before it's restored
  return true
end

return Actions
