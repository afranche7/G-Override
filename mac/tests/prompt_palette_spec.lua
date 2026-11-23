-- Prompt Palette (G8) and Window Snip scenarios against the fake OS port.
-- Mirrors the action tests in windows/tests/TestPalette.ahk.
local FakePort = require("fake_port")
local Actions = require("g_override.actions")
local helpers = require("helpers")

local CLAUDE_ID = "com.anthropic.claudefordesktop"

local PALETTE_TEXT = "## /grill-with-docs\n/grill-with-docs\n\n"
  .. "## /implement\nsend: true\n/implement\n\n"
  .. "## Explain\nExplain this: {selection}\n\n"
  .. "## Compare\nCompare {selection} with {clipboard}\n\n"
  .. "---\n## Region Snip\n@region-snip\n\n## Window Snip\n@window-snip\n"

local function fence(n) return ("`"):rep(n) end

local function titles(items)
  local out = {}
  for _, it in ipairs(items) do out[#out + 1] = it.kind == "separator" and "---" or it.title end
  return table.concat(out, "|")
end

-- Chrome in front with the user's own text on the clipboard, the Claude App running behind,
-- and the palette file above.
local function newWorld()
  local port = FakePort.new()
  port:addApp(100, "com.google.Chrome", "Google Chrome", "localhost:3000 - Issue #7")
  port:addApp(200, CLAUDE_ID, "Claude", "Claude")
  port.frontmostId = 100
  port.clipText = "user's clipboard"
  port.files[helpers.testConfig().paletteFile] = PALETTE_TEXT
  return port
end

local function promptPalette(port)
  return Actions.new(port, helpers.testConfig()):promptPalette()
end

describe("Prompt Palette", function()
  it("lists the palette file's entries", function()
    local port = newWorld()
    promptPalette(port)
    assert.are.equal("/grill-with-docs|/implement|Explain|Compare|---|Region Snip|Window Snip", titles(port.paletteShown))
  end)

  it("inserts the picked entry into the Claude App without submitting", function()
    local port = newWorld()
    port.paletteChoice = "/grill-with-docs"
    assert.is_true(promptPalette(port))
    assert.are.equal(1, #port.pasted)
    assert.are.equal(200, port.pasted[1].target)
    assert.are.equal("/grill-with-docs", port.pasted[1].text)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
    assert.are.equal(200, port.frontmostId)
  end)

  it("sends Enter only for entries marked send: true, after the paste", function()
    local port = newWorld()
    port.paletteChoice = "/implement"
    promptPalette(port)
    assert.are.equal("/implement", port.pasted[1].text)
    assert.are.equal("enter", port.sent[#port.sent])
  end)

  it("appends the Selection as a fenced block when the entry has no placeholder", function()
    local port = newWorld()
    port.selection = "TypeError: x is undefined"
    port.paletteChoice = "/grill-with-docs"
    promptPalette(port)
    assert.are.equal("/grill-with-docs\n\n" .. fence(3) .. "\nTypeError: x is undefined\n" .. fence(3) .. "\n",
      port.pasted[1].text)
  end)

  it("puts the Selection where {selection} is, without an extra block", function()
    local port = newWorld()
    port.selection = "boom"
    port.paletteChoice = "Explain"
    promptPalette(port)
    assert.are.equal("Explain this: boom", port.pasted[1].text)
  end)

  it("fills {clipboard} with the user's own clipboard, not the captured Selection", function()
    local port = newWorld()
    port.selection = "boom"
    port.paletteChoice = "Compare"
    promptPalette(port)
    assert.are.equal("Compare boom with user's clipboard", port.pasted[1].text)
  end)

  it("with nothing selected inserts the plain entry and blanks {selection}", function()
    local port = newWorld()
    port.paletteChoice = "Explain"
    promptPalette(port)
    assert.are.equal("Explain this:", port.pasted[1].text)
  end)

  it("captures the Selection with Cmd+C before the palette opens", function()
    local port = newWorld()
    port.selection = "chosen text"
    port.paletteStealsFocus = true
    promptPalette(port)
    assert.are.equal("cmd+c", port.sent[1])
  end)

  it("does nothing when dismissed, and restores the clipboard", function()
    local port = newWorld()
    port.selection = "some selection"
    local result = promptPalette(port)
    assert.is_false(result, "should report a no-op")
    assert.are.equal(0, #port.pasted)
    assert.are.equal(100, port.frontmostId)
    assert.are.equal("user's clipboard", port.clipText)
    assert.are.same({ "cmd+c" }, port.sent)
  end)

  it("restores the user's clipboard after a pick", function()
    local port = newWorld()
    port.selection = "sel"
    port.paletteChoice = "Explain"
    promptPalette(port)
    assert.are.equal("user's clipboard", port.clipText)
    assert.are.equal("", port.clipImage)
  end)

  it("restores an image the user had on the clipboard", function()
    local port = newWorld()
    port.clipText, port.clipImage = "", "user's screenshot"
    port.paletteChoice = "/grill-with-docs"
    promptPalette(port)
    assert.are.equal("user's screenshot", port.clipImage)
  end)

  it("picks up palette file edits on the next open", function()
    local port = newWorld()
    local actions = Actions.new(port, helpers.testConfig())
    actions:promptPalette()
    assert.truthy(titles(port.paletteShown):find("Explain", 1, true))
    port.files[helpers.testConfig().paletteFile] = "## Brand new\nhello"
    actions:promptPalette()
    assert.are.equal("Brand new", titles(port.paletteShown))
  end)

  it("with a missing or empty palette file toasts and does nothing", function()
    local port = newWorld()
    port.files[helpers.testConfig().paletteFile] = nil
    assert.is_false(promptPalette(port))
    assert.are.equal(1, #port.toasts)
    assert.is_nil(port.paletteShown)
    port.files[helpers.testConfig().paletteFile] = "nothing useful"
    assert.is_false(promptPalette(port))
    assert.are.equal(2, #port.toasts)
    assert.are.equal(0, #port.pasted)
    assert.are.equal(0, #port.sent)
  end)

  it("pastes nothing and doesn't submit if the Claude App never comes to the front", function()
    local port = newWorld()
    port.activateDelayPolls = math.huge
    port.paletteChoice = "/implement"
    assert.is_false(promptPalette(port))
    assert.are.equal(0, #port.pasted)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
    assert.are.equal("user's clipboard", port.clipText)
  end)
end)

describe("Prompt Palette capture entries", function()
  it("Region Snip snips a region and pastes the image into the Claude App, even with text selected", function()
    local port = newWorld()
    port.selection = "selected but the user wants a snip"
    port.regionResult = "image"
    port.paletteChoice = "Region Snip"
    assert.is_true(promptPalette(port))
    assert.are.equal(1, port.regionCaptures)
    assert.are.equal("region", port.pasted[1].image)
    assert.are.equal(200, port.pasted[1].target)
    assert.are.equal("user's clipboard", port.clipText)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
  end)

  it("a cancelled Region Snip does nothing", function()
    local port = newWorld()
    port.paletteChoice = "Region Snip"
    assert.is_false(promptPalette(port))
    assert.are.equal(0, #port.pasted)
    assert.are.equal("user's clipboard", port.clipText)
  end)

  it("Window Snip captures the user's window by its ID and pastes it into the Claude App", function()
    local port = newWorld()
    port.paletteChoice = "Window Snip"
    assert.is_true(promptPalette(port))
    assert.are.same({ 1000 }, port.windowCaptures)
    assert.are.equal(1, #port.pasted)
    assert.are.equal("window:localhost:3000 - Issue #7", port.pasted[1].image)
    assert.are.equal(200, port.pasted[1].target)
    assert.are.equal("user's clipboard", port.clipText)
    assert.is_false(port:sentKey("enter"), "Enter was sent")
  end)

  it("Window Snip captures the window the user was in even if the palette took focus", function()
    local port = newWorld()
    port.paletteStealsFocus = true
    port.paletteChoice = "Window Snip"
    promptPalette(port)
    assert.are.equal("window:localhost:3000 - Issue #7", port.pasted[1].image)
  end)
end)

describe("Window Snip", function()
  it("pastes the frontmost window into the Claude App and restores the clipboard", function()
    local port = newWorld()
    assert.is_true(Actions.new(port, helpers.testConfig()):windowSnip())
    assert.are.equal("window:localhost:3000 - Issue #7", port.pasted[1].image)
    assert.are.equal(200, port.pasted[1].target)
    assert.are.equal("user's clipboard", port.clipText)
  end)

  it("toasts and does nothing when there is no window to capture", function()
    local port = newWorld()
    port.frontmostId = nil
    assert.is_false(Actions.new(port, helpers.testConfig()):windowSnip())
    assert.are.equal(0, #port.windowCaptures)
    assert.are.equal(0, #port.pasted)
    assert.are.equal(1, #port.toasts)
  end)

  it("toasts and does nothing when the capture can't start", function()
    local port = newWorld()
    port.windowCaptureFails = true
    assert.is_false(Actions.new(port, helpers.testConfig()):windowSnip())
    assert.are.equal(0, #port.pasted)
    assert.are.equal(1, #port.toasts)
    assert.are.equal("user's clipboard", port.clipText)
  end)

  it("gives up quietly if no image arrives in time", function()
    local port = newWorld()
    port.windowCaptureEmpty = true
    assert.is_false(Actions.new(port, helpers.testConfig()):windowSnip())
    assert.are.equal(0, #port.pasted)
    assert.are.equal("user's clipboard", port.clipText)
  end)
end)
