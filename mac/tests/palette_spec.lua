-- Palette file parsing, filtering and placeholder filling (pure). Parsing is checked against the
-- fixtures the Windows tests share (tests/palette_cases.txt), so both Helpers read a palette alike.
local palette = require("g_override.palette")
local helpers = require("helpers")

local function describeAll(items)
  local out = {}
  for _, it in ipairs(items) do out[#out + 1] = helpers.describeItem(it) end
  return table.concat(out, "\n")
end

local function titles(items)
  local out = {}
  for _, it in ipairs(items) do out[#out + 1] = it.kind == "separator" and "---" or it.title end
  return table.concat(out, "|")
end

describe("Palette parsing (shared with Windows)", function()
  local cases = helpers.paletteCases()

  it("has cases", function()
    assert.is_true(#cases > 0)
  end)

  for _, c in ipairs(cases) do
    local text = helpers.readRepoFile("tests/palette/" .. c.file)

    it(c.file .. " (palette_cases.txt:" .. c.line .. ")", function()
      assert.are.equal(describeAll(c.items), describeAll(palette.parse(text)))
    end)

    it(c.file .. " with CRLF line endings (palette_cases.txt:" .. c.line .. ")", function()
      assert.are.equal(describeAll(c.items), describeAll(palette.parse((text:gsub("\n", "\r\n")))))
    end)
  end
end)

describe("Palette", function()
  it("the starter palette has the six Main Flow skills in order, a separator, then both snips", function()
    local e = palette.parse(helpers.readRepoFile("palette.md"))
    assert.are.equal("/grill-with-docs|/to-spec|/to-tickets|/implement|/code-review|/retro|---|Region Snip|Window Snip",
      titles(e))
    assert.are.equal("/grill-with-docs", e[1].body)
    assert.are.equal("region-snip", e[8].action)
    assert.are.equal("window-snip", e[9].action)
  end)

  it("filtering matches titles case-insensitively and drops separators and groups", function()
    local e = palette.parse("# G\n## /to-spec\na\n## /to-tickets\nb\n---\n## Region Snip\n@region-snip")
    assert.are.equal("/to-spec|/to-tickets", titles(palette.filter(e, "TO-")))
    assert.are.equal("Region Snip", titles(palette.filter(e, "snip")))
    assert.are.equal(0, #palette.filter(e, "zzz"))
    assert.are.equal(#e, #palette.filter(e, ""))
    assert.are.equal(#e, #palette.filter(e, "  "))
  end)

  it("filtering treats the query as plain text, not a pattern", function()
    local e = palette.parse("## 100% done\nx\n## (a)\ny")
    assert.are.equal("100% done", titles(palette.filter(e, "0% d")))
    assert.are.equal("(a)", titles(palette.filter(e, "(a")))
  end)
end)

describe("Placeholders", function()
  it("{selection} and {clipboard} are replaced where they appear", function()
    assert.are.equal("Fix: ERR (was old)", palette.fill("Fix: {selection} (was {clipboard})", "ERR", "old"))
    assert.are.equal("aa", palette.fill("{selection}{selection}", "a", ""))
  end)

  it("a replacement containing braces or % is inserted literally", function()
    assert.are.equal("x {clipboard} %1 $1", palette.fill("x {selection}", "{clipboard} %1 $1", "NO"))
  end)

  it("matches placeholders case-insensitively, like the Windows Helper, and leaves other braces alone", function()
    assert.are.equal("{other} a a b", palette.fill("{other} {Selection} {SELECTION} {Clipboard}", "a", "b"))
    assert.is_true(palette.hasSelectionPlaceholder("see {Selection}"))
    assert.is_false(palette.hasSelectionPlaceholder("see {clipboard}"))
  end)
end)
