-- Send to Claude's source line and fenced block, checked against the cases the Windows tests share.
local format = require("g_override.format")
local helpers = require("helpers")

describe("Send to Claude formatting (shared with Windows)", function()
  local cases = helpers.formatCases()

  it("has cases of both kinds", function()
    local kinds = {}
    for _, c in ipairs(cases) do kinds[c.kind] = true end
    assert.is_true(kinds["source line"])
    assert.is_true(kinds["fenced block"])
  end)

  for _, c in ipairs(cases) do
    if c.kind == "source line" then
      it("source line for '" .. c.app .. "' (format_cases.txt:" .. c.line .. ")", function()
        assert.are.equal(c.want, format.sourceLine(c.app, c.title))
      end)
    elseif c.kind == "fenced block" then
      it("fenced block (format_cases.txt:" .. c.line .. ")", function()
        assert.are.equal(c.want, format.fencedBlock(c.text))
      end)
    else
      error("format_cases.txt:" .. c.line .. ": unknown case kind '" .. c.kind .. "'")
    end
  end
end)
