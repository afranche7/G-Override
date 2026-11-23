-- Focus Claude (G6) scenarios against the fake OS port.
local FakePort = require("fake_port")
local Actions = require("g_override.actions")
local helpers = require("helpers")

local CLAUDE_ID = "com.anthropic.claudefordesktop"

local function newWorld()
  local port = FakePort.new()
  port:addApp(100, "com.google.Chrome", "Google Chrome")
  port.frontmostId = 100
  return port
end

describe("Focus Claude", function()
  it("brings the Claude App to the front", function()
    local port = newWorld()
    port:addApp(200, CLAUDE_ID, "Claude")
    Actions.new(port, helpers.testConfig()):focusClaude()
    assert.are.equal(200, port.frontmostId)
  end)

  it("toggles back to the previous app when pressed again", function()
    local port = newWorld()
    port:addApp(200, CLAUDE_ID, "Claude")
    local a = Actions.new(port, helpers.testConfig())
    a:focusClaude()
    a:focusClaude()
    assert.are.equal(100, port.frontmostId)
  end)

  it("stays on Claude if the previous app has quit", function()
    local port = newWorld()
    port:addApp(200, CLAUDE_ID, "Claude")
    local a = Actions.new(port, helpers.testConfig())
    a:focusClaude()
    port:quitApp(100)
    a:focusClaude()
    assert.are.equal(200, port.frontmostId)
  end)

  it("stays on Claude when it's in front and nothing was remembered", function()
    local port = FakePort.new()
    port:addApp(200, CLAUDE_ID, "Claude")
    port.frontmostId = 200
    Actions.new(port, helpers.testConfig()):focusClaude()
    assert.are.equal(200, port.frontmostId)
  end)

  it("launches the Claude App when it isn't running, then focuses it", function()
    local port = newWorld()
    port.pendingLaunch = { id = 300, bundleId = CLAUDE_ID, name = "Claude" }
    Actions.new(port, helpers.testConfig()):focusClaude()
    assert.are.equal(1, #port.launches)
    assert.are.equal(CLAUDE_ID, port.launches[1].bundleId)
    assert.are.equal("Claude", port.launches[1].name)
    assert.are.equal(300, port.frontmostId)
  end)

  it("falls back to the app name when the bundle ID doesn't match", function()
    local port = newWorld()
    port:addApp(200, "com.example.renamed", "Claude")
    Actions.new(port, helpers.testConfig()):focusClaude()
    assert.are.equal(200, port.frontmostId)
  end)

  it("remembers the app it launched from, so a second press toggles back", function()
    local port = newWorld()
    port.pendingLaunch = { id = 300, bundleId = CLAUDE_ID, name = "Claude" }
    local a = Actions.new(port, helpers.testConfig())
    a:focusClaude()
    a:focusClaude()
    assert.are.equal(100, port.frontmostId)
  end)

  it("never toggles away when asked not to", function()
    local port = newWorld()
    port:addApp(200, CLAUDE_ID, "Claude")
    local a = Actions.new(port, helpers.testConfig())
    a:focusClaude()
    a:focusClaude(false)
    assert.are.equal(200, port.frontmostId)
  end)

  it("toasts and leaves focus alone if Claude never starts", function()
    local port = newWorld()
    local ok = Actions.new(port, helpers.testConfig()):focusClaude()
    assert.is_false(ok)
    assert.are.equal(100, port.frontmostId)
    assert.are.equal(1, #port.toasts)
  end)
end)
