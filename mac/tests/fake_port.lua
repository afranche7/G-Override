-- In-memory stand-in for the macOS OS port. Mirrors windows/tests/FakePort.ahk. Records what the
-- Action layer did so tests can assert on observable effects: which app is frontmost, what was
-- launched or pasted where, which keys were sent, and what the clipboard holds afterwards.
local FakePort = {}
FakePort.__index = FakePort

function FakePort.new()
  return setmetatable({
    apps = {},             -- { {id, bundleId, name, title} }
    frontmostId = nil,
    pendingLaunch = nil,   -- app that appears after a launch and a sleep
    launches = {},         -- {bundleId, name} passed to launch, in order
    sleptMs = 0,
    toasts = {},
    clipText = "",
    clipImage = "",        -- "" or an image label, e.g. "region"
    changeCount = 1,
    selection = "",        -- text the frontmost app copies when Cmd+C is pressed
    sent = {},             -- neutral key specs sent, in order
    pasted = {},           -- { {target, text, image} }
    regionResult = "",     -- "image" -> a region capture lands on the clipboard; "" -> cancelled
    regionCaptures = 0,
    regionOpen = false,    -- the capture UI is on screen
    imageDelayPolls = 0,   -- polls (sleeps) before a captured image lands on the clipboard
    pendingImagePolls = 0,
    regionStartFails = false,  -- the capture tool can't be started
    activateDelayPolls = 0,    -- polls (sleeps) before an activated app is frontmost; math.huge = never
    pendingActivate = nil,     -- {id, polls}
    files = {},                -- path -> text, for readFile
    paletteChoice = "",        -- title of the Palette Entry the user picks; "" -> dismissed
    paletteShown = nil,        -- items passed to showPalette
    paletteStealsFocus = false,  -- the palette takes focus away from the frontmost app
    windowCaptures = {},       -- window IDs passed to captureWindow, in order
    windowCaptureFails = false,  -- the window capture can't start
    windowCaptureEmpty = false,  -- the window capture starts but never delivers an image
  }, FakePort)
end

function FakePort:addApp(id, bundleId, name, title)
  -- Each app's focused window gets an ID derived from the app's, e.g. 100 -> 1000.
  local app = { id = id, bundleId = bundleId, name = name, title = title or "", windowId = id * 10 }
  table.insert(self.apps, app)
  return app
end

function FakePort:quitApp(id)
  for i, a in ipairs(self.apps) do
    if a.id == id then
      table.remove(self.apps, i)
      if self.frontmostId == id then self.frontmostId = nil end
      return
    end
  end
end

-- --- apps --------------------------------------------------------------------

function FakePort:frontmostApp()
  for _, a in ipairs(self.apps) do
    if a.id == self.frontmostId then return a end
  end
  return nil
end

function FakePort:findAppByBundleId(bundleId)
  for _, a in ipairs(self.apps) do
    if a.bundleId == bundleId then return a end
  end
  return nil
end

function FakePort:findAppByName(name)
  for _, a in ipairs(self.apps) do
    if a.name == name then return a end
  end
  return nil
end

function FakePort:appRunning(id)
  for _, a in ipairs(self.apps) do
    if a.id == id then return true end
  end
  return false
end

-- Like the real thing, activation can take effect a little later than the call.
function FakePort:activate(id)
  if self.activateDelayPolls == 0 then
    self.frontmostId = id
  else
    self.pendingActivate = { id = id, polls = self.activateDelayPolls }
  end
end

-- Starts the app; it only appears after the next sleep, like a real cold start.
function FakePort:launch(bundleId, name, timeoutMs)
  table.insert(self.launches, { bundleId = bundleId, name = name })
end

-- Time passes: a launched app appears, the capture UI closes at the user's next move, and a
-- delayed capture lands its image.
function FakePort:sleep(ms)
  self.sleptMs = self.sleptMs + ms
  if self.pendingLaunch and #self.launches > 0 then
    table.insert(self.apps, self.pendingLaunch)
    self.pendingLaunch = nil
  end
  self.regionOpen = false
  if self.pendingActivate then
    self.pendingActivate.polls = self.pendingActivate.polls - 1
    if self.pendingActivate.polls <= 0 then
      self.frontmostId = self.pendingActivate.id
      self.pendingActivate = nil
    end
  end
  if self.pendingImagePolls > 0 then
    self.pendingImagePolls = self.pendingImagePolls - 1
    if self.pendingImagePolls == 0 then self:landRegionImage() end
  end
end

function FakePort:toast(msg)
  table.insert(self.toasts, msg)
end

function FakePort:readFile(path)
  local text = self.files[path]
  if text == nil then return nil, path .. ": No such file or directory" end
  return text
end

-- The user picks the entry titled paletteChoice, or dismisses the palette when it is "".
function FakePort:showPalette(items)
  self.paletteShown = items
  if self.paletteStealsFocus then self.frontmostId = nil end
  if self.paletteChoice == "" then return nil end
  for _, it in ipairs(items) do
    if it.kind == "entry" and it.title == self.paletteChoice then return it end
  end
  error("FakePort: no palette entry titled " .. self.paletteChoice)
end

-- --- clipboard ---------------------------------------------------------------

function FakePort:clipboardChangeCount() return self.changeCount end

function FakePort:clipboardText()
  if self.clipImage ~= "" then return "" end
  return self.clipText
end

function FakePort:clipboardHasImage() return self.clipImage ~= "" end

function FakePort:clipboardBackup() return { text = self.clipText, image = self.clipImage } end

function FakePort:clipboardRestore(b)
  self.clipText, self.clipImage = b.text, b.image
  self.changeCount = self.changeCount + 1
end

function FakePort:clipboardClear()
  self.clipText, self.clipImage = "", ""
  self.changeCount = self.changeCount + 1
end

function FakePort:clipboardSetText(s)
  self.clipText, self.clipImage = s, ""
  self.changeCount = self.changeCount + 1
end

-- --- input / capture ---------------------------------------------------------

function FakePort:send(keys)
  table.insert(self.sent, keys)
  if keys == "cmd+c" then
    if self.selection ~= "" then self:clipboardSetText(self.selection) end
  elseif keys == "cmd+v" then
    table.insert(self.pasted, { target = self.frontmostId, text = self:clipboardText(), image = self.clipImage })
  end
end

-- The capture UI opens, closes at the user's next move (sleep), and a captured image lands on
-- the clipboard immediately or imageDelayPolls sleeps later. Returns false if it can't start.
function FakePort:startRegionCapture()
  self.regionCaptures = self.regionCaptures + 1
  if self.regionStartFails then return false end
  self.regionOpen = true
  if self.regionResult == "image" then
    if self.imageDelayPolls == 0 then
      self:landRegionImage()
    else
      self.pendingImagePolls = self.imageDelayPolls
    end
  end
  return true
end

function FakePort:landRegionImage()
  self.clipImage = "region"
  self.changeCount = self.changeCount + 1
end

function FakePort:regionCaptureOpen() return self.regionOpen end

-- Captures the window with that ID straight to the clipboard. Returns false if it can't start.
function FakePort:captureWindow(windowId)
  table.insert(self.windowCaptures, windowId)
  if self.windowCaptureFails then return false end
  if self.windowCaptureEmpty then return true end
  for _, a in ipairs(self.apps) do
    if a.windowId == windowId then
      self.clipImage = "window:" .. a.title
      self.changeCount = self.changeCount + 1
    end
  end
  return true
end

-- --- helpers for assertions --------------------------------------------------

function FakePort:sentKey(keys)
  for _, k in ipairs(self.sent) do
    if k == keys then return true end
  end
  return false
end

return FakePort
