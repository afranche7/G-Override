-- The Action layer: what each Trigger Key does, expressed only through the OS port.
-- Mirrors windows/lib/Actions.ahk; keep the two behaving the same.
local Actions = {}
Actions.__index = Actions

Actions.POLL_MS = 50

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

return Actions
