-- Send to Claude (G7) and Region Snip scenarios against the fake OS port.
-- Mirrors windows/tests/TestSendToClaude.ahk.
local FakePort = require("fake_port")
local Actions = require("g_override.actions")
local helpers = require("helpers")

local CLAUDE_ID = "com.anthropic.claudefordesktop"

local function fence(n) return ("`"):rep(n) end

-- Chrome in front with the user's own text on the clipboard, Claude App running behind.
local function newWorld()
  local port = FakePort.new()
  port:addApp(100, "com.google.Chrome", "Google Chrome", "localhost:3000 - Issue #6")
  port:addApp(200, CLAUDE_ID, "Claude", "Claude")
  port.frontmostId = 100
  port.clipText = "user's clipboard"
  return port
end

local function lastPaste(port)
  assert.is_true(#port.pasted > 0, "expected something to be pasted")
  return port.pasted[#port.pasted]
end

local function sendToClaude(port)
  return Actions.new(port, helpers.testConfig()):sendToClaude()
end

describe("Send to Claude", function()
  it("pastes the Selection into Claude as a fenced block with its source", function()
    local port = newWorld()
    port.selection = "TypeError: x is undefined\n    at main.js:12"
    sendToClaude(port)
    local p = lastPaste(port)
    assert.are.equal(200, p.target)
    assert.are.equal("From Google Chrome — localhost:3000 - Issue #6\n" .. fence(3) .. "\n"
      .. "TypeError: x is undefined\n    at main.js:12\n" .. fence(3) .. "\n", p.text)
  end)

  it("leaves Claude in front and the user's clipboard restored", function()
    local port = newWorld()
    port.selection = "some text"
    sendToClaude(port)
    assert.are.equal(200, port.frontmostId)
    assert.are.equal("user's clipboard", port.clipText)
    assert.are.equal("", port.clipImage)
  end)

  it("restores an image the user had on the clipboard", function()
    local port = newWorld()
    port.clipText = ""
    port.clipImage = "user's screenshot"
    port.selection = "some text"
    sendToClaude(port)
    assert.are.equal("user's screenshot", port.clipImage)
  end)

  it("never sends Enter", function()
    local port = newWorld()
    port.selection = "some text"
    sendToClaude(port)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
  end)

  it("uses a longer fence when the Selection contains one", function()
    local port = newWorld()
    port.selection = "see:\n" .. fence(3) .. "js\nx()\n" .. fence(3)
    sendToClaude(port)
    local text = lastPaste(port).text
    assert.truthy(text:find("\n" .. fence(4) .. "\nsee:", 1, true), text)
    assert.are.equal("\n" .. fence(4) .. "\n", text:sub(-6))
  end)

  it("copies from a terminal with Cmd+C, never Ctrl+C, so nothing is interrupted", function()
    local port = newWorld()
    port:addApp(300, "com.googlecode.iterm2", "iTerm2", "npm run dev")
    port.frontmostId = 300
    port.selection = "ERR! missing script"
    sendToClaude(port)
    assert.are.equal("cmd+c", port.sent[1])
    assert.is_false(port:sentKey("ctrl+c"), "Ctrl+C was sent")
    assert.truthy(lastPaste(port).text:find("From iTerm2 — npm run dev\n" .. fence(3) .. "\nERR! missing script", 1, true))
  end)

  it("works on a Selection inside the Claude App itself", function()
    local port = newWorld()
    port.frontmostId = 200
    port.selection = "Claude's own answer"
    sendToClaude(port)
    assert.are.equal(200, lastPaste(port).target)
    assert.truthy(lastPaste(port).text:find("Claude's own answer", 1, true))
  end)

  it("launches the Claude App first if it isn't running", function()
    local port = newWorld()
    port:quitApp(200)
    port.pendingLaunch = { id = 300, bundleId = CLAUDE_ID, name = "Claude", title = "Claude" }
    port.selection = "x"
    sendToClaude(port)
    assert.are.equal(300, lastPaste(port).target)
  end)

  it("waits for the Claude App to come to the front before pasting", function()
    local port = newWorld()
    port.activateDelayPolls = 3
    port.selection = "some text"
    sendToClaude(port)
    assert.are.equal(200, lastPaste(port).target)
  end)

  it("pastes nothing, toasts and restores the clipboard if the Claude App never comes to the front", function()
    local port = newWorld()
    port.activateDelayPolls = math.huge
    port.selection = "some text"
    local result = sendToClaude(port)
    assert.is_false(result)
    assert.are.equal(0, #port.pasted)
    assert.are.equal(1, #port.toasts)
    assert.are.equal("user's clipboard", port.clipText)
  end)

  it("with nothing selected snips a region and pastes the image into Claude", function()
    local port = newWorld()
    port.regionResult = "image"
    sendToClaude(port)
    assert.are.equal(1, port.regionCaptures)
    local p = lastPaste(port)
    assert.are.equal(200, p.target)
    assert.are.equal("region", p.image)
    assert.are.equal("user's clipboard", port.clipText)
    assert.are.equal("", port.clipImage)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
  end)

  it("snips a region when no app is in front", function()
    local port = newWorld()
    port.frontmostId = nil
    port.selection = "stale text no app owns"
    port.regionResult = "image"
    sendToClaude(port)
    assert.are.equal(1, port.regionCaptures)
    assert.are.equal("region", lastPaste(port).image)
  end)

  it("treats a whitespace-only Selection as nothing selected", function()
    local port = newWorld()
    port.selection = "  \n "
    sendToClaude(port)
    assert.are.equal(1, port.regionCaptures)
  end)

  it("does nothing and restores the clipboard when the snip is cancelled", function()
    local port = newWorld()
    port.regionResult = ""
    local result = sendToClaude(port)
    assert.is_false(result, "should report a no-op")
    assert.are.equal(1, port.regionCaptures)
    assert.are.equal(0, #port.pasted)
    assert.are.equal(100, port.frontmostId)
    assert.are.equal("user's clipboard", port.clipText)
  end)

  it("returns at once with a toast when the screen capture can't start", function()
    local port = newWorld()
    port.regionStartFails = true
    local result = sendToClaude(port)
    assert.is_false(result)
    assert.are.equal(0, #port.pasted)
    assert.are.equal(1, #port.toasts)
    assert.is_true(port.sleptMs < 1000, "waited " .. port.sleptMs .. " ms after a failed start")
  end)

  it("returns from a cancelled snip long before the snip timeout, so the Button isn't dead", function()
    local port = newWorld()
    port.regionResult = ""
    sendToClaude(port)
    assert.is_true(port.sleptMs < 5000, "waited " .. port.sleptMs .. " ms after a cancel")
  end)

  it("still pastes an image that arrives just after the capture UI closes", function()
    local port = newWorld()
    port.regionResult = "image"
    port.imageDelayPolls = 5
    sendToClaude(port)
    assert.are.equal("region", lastPaste(port).image)
  end)
end)
