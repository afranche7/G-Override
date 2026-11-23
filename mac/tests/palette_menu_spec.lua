-- The pure parts of the Prompt Palette's chooser: which rows it shows and where it opens.
local menu = require("g_override.palette_menu")
local palette = require("g_override.palette")

local ITEMS = palette.parse("# Skills\n## /to-spec\na\n## /to-tickets\nb\n---\n## Region Snip\n@region-snip")

local function texts(rows)
  local out = {}
  for _, r in ipairs(rows) do out[#out + 1] = r.text end
  return table.concat(out, "|")
end

describe("Prompt Palette rows", function()
  it("lists every item in order, with groups and separators as rows that can't be picked", function()
    local rows = menu.rows(ITEMS, "")
    assert.are.equal("Skills|/to-spec|/to-tickets|" .. menu.SEPARATOR .. "|Region Snip", texts(rows))
    assert.is_false(rows[1].valid)
    assert.is_nil(rows[2].valid)
    assert.is_false(rows[4].valid)
  end)

  it("points each entry row back at its item", function()
    local rows = menu.rows(ITEMS, "")
    assert.are.equal("/to-tickets", ITEMS[rows[3].item].title)
    assert.are.equal("Region Snip", ITEMS[rows[5].item].title)
    assert.is_nil(rows[1].item)
  end)

  it("selects the first entry, skipping a leading group", function()
    local _, first = menu.rows(ITEMS, "")
    assert.are.equal(2, first)
  end)

  it("filters with the same rules as the Windows menu", function()
    local rows, first = menu.rows(ITEMS, "TO-")
    assert.are.equal("/to-spec|/to-tickets", texts(rows))
    assert.are.equal(1, first)
    rows, first = menu.rows(ITEMS, "zzz")
    assert.are.equal(0, #rows)
    assert.is_nil(first)
  end)
end)

describe("Prompt Palette placement", function()
  local screen = { x = 0, y = 25, w = 1440, h = 875 }

  it("opens with its top-left at the cursor", function()
    assert.are.same({ x = 300, y = 200 }, menu.placeNear({ x = 300, y = 200 }, screen, 400, 300))
  end)

  it("stays inside the cursor's screen near its right and bottom edges", function()
    assert.are.same({ x = 1040, y = 600 }, menu.placeNear({ x = 1430, y = 890 }, screen, 400, 300))
  end)

  it("stays inside a screen that doesn't start at 0,0", function()
    local left = { x = -1920, y = 0, w = 1920, h = 1080 }
    assert.are.same({ x = -1920, y = 0 }, menu.placeNear({ x = -2000, y = -10 }, left, 400, 300))
  end)
end)
