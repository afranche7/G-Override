-- The real OS port: thin wrappers over Hammerspoon's hs.* modules.
-- Keep logic out of here; it belongs in the Action layer, where it is tested.
local M = {}
M.__index = M

function M.new()
  return setmetatable({}, M)
end

local function describe(app)
  if not app then return nil end
  return { id = app:pid(), bundleId = app:bundleID(), name = app:name() }
end

function M:frontmostApp()
  return describe(hs.application.frontmostApplication())
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

function M:sleep(ms)
  hs.timer.usleep(ms * 1000)
end

function M:toast(msg)
  hs.alert.show(msg, 2)
end

return M
