-- Button -> Trigger Key -> Action wiring, and Trigger Key translation to Hammerspoon hotkeys.
local FakePort = require("fake_port")
local Actions = require("g_override.actions")
local bindings = require("g_override.bindings")
local helpers = require("helpers")

describe("Bindings", function()
  it("binds G6 to Focus Claude on its configured Trigger Key", function()
    local b = bindings.buttonBindings(helpers.testConfig())
    assert.are.equal("G6", b[1].button)
    assert.are.equal("F17", b[1].trigger)
    assert.are.equal("Focus Claude", b[1].name)
  end)

  it("runs Focus Claude when the G6 binding fires", function()
    local port = FakePort.new()
    port:addApp(100, "com.google.Chrome", "Google Chrome")
    port:addApp(200, "com.anthropic.claudefordesktop", "Claude")
    port.frontmostId = 100
    local cfg = helpers.testConfig()
    bindings.run(Actions.new(port, cfg), bindings.buttonBindings(cfg)[1])
    assert.are.equal(200, port.frontmostId)
  end)

  it("shows a debug toast naming the Button and Action when debug is on", function()
    local port = FakePort.new()
    local cfg = helpers.testConfig()
    cfg.debug = true
    bindings.run(Actions.new(port, cfg), bindings.buttonBindings(cfg)[1])
    assert.are.equal("G-Override: G6 -> Focus Claude (F17)", port.toasts[1])
  end)

  it("shows no debug toast when debug is off", function()
    local port = FakePort.new()
    port:addApp(200, "com.anthropic.claudefordesktop", "Claude")
    bindings.run(Actions.new(port, helpers.testConfig()), bindings.buttonBindings(helpers.testConfig())[1])
    assert.are.equal(0, #port.toasts)
  end)

  it("rejects two Buttons on the same Trigger Key", function()
    local b = {
      { button = "G6", trigger = "F17" },
      { button = "G7", trigger = "f17" },
    }
    assert.has_error(function() bindings.check(b) end, "Trigger Key 'f17' is used by both G6 and G7")
  end)

  it("accepts distinct Trigger Keys", function()
    assert.has_no.errors(function() bindings.check(bindings.buttonBindings(helpers.testConfig())) end)
  end)
end)

describe("Trigger Keys", function()
  it("translate to Hammerspoon modifiers and key", function()
    local mods, key = bindings.toHotkey("F17")
    assert.are.same({}, mods)
    assert.are.equal("f17", key)
    mods, key = bindings.toHotkey("ctrl+alt+shift+F10")
    assert.are.same({ "ctrl", "alt", "shift" }, mods)
    assert.are.equal("f10", key)
    mods, key = bindings.toHotkey("Cmd+Option+F12")
    assert.are.same({ "cmd", "alt" }, mods)
    assert.are.equal("f12", key)
  end)

  it("reject unknown modifiers", function()
    assert.has_error(function() bindings.toHotkey("hyper+F10") end)
  end)
end)
