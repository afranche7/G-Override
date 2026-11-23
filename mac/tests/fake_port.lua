-- In-memory stand-in for the macOS OS port. Records what the Action layer did so tests can
-- assert on observable effects: which app is frontmost, what was launched, which toasts showed.
local FakePort = {}
FakePort.__index = FakePort

function FakePort.new()
  return setmetatable({
    apps = {},             -- { {id, bundleId, name} }
    frontmostId = nil,
    pendingLaunch = nil,   -- app that appears after a launch and a sleep
    launches = {},         -- {bundleId, name} passed to launch, in order
    sleptMs = 0,
    toasts = {},
  }, FakePort)
end

function FakePort:addApp(id, bundleId, name)
  local app = { id = id, bundleId = bundleId, name = name }
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

-- --- port API --------------------------------------------------------------

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

function FakePort:activate(id)
  self.frontmostId = id
end

-- Starts the app; it only appears after the next sleep, like a real cold start.
function FakePort:launch(bundleId, name, timeoutMs)
  table.insert(self.launches, { bundleId = bundleId, name = name })
end

function FakePort:sleep(ms)
  self.sleptMs = self.sleptMs + ms
  if self.pendingLaunch and #self.launches > 0 then
    table.insert(self.apps, self.pendingLaunch)
    self.pendingLaunch = nil
  end
end

function FakePort:toast(msg)
  table.insert(self.toasts, msg)
end

return FakePort
