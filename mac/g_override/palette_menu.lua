-- The Prompt Palette's on-screen menu: a Hammerspoon chooser at the cursor. Type to filter,
-- Up/Down to move, Enter or click to pick, Esc or clicking away to dismiss.
-- Mirrors windows/lib/PaletteMenu.ahk. rows() and placeNear() are pure and tested; show() is the
-- Hammerspoon glue the real port calls.
local palette = require("g_override.palette")

local M = {}

M.ROWS = 12              -- rows shown before the list scrolls
M.WIDTH_PERCENT = 24     -- chooser width, as a percentage of the screen's
M.SEPARATOR = "──────────────"
-- The chooser can't report its own size, so placement uses an estimate of its height.
M.QUERY_HEIGHT = 44
M.ROW_HEIGHT = 36

-- Chooser rows for the items matching query (palette.filter's rules), and the index of the
-- first row that can be picked (nil if none). Entry rows carry `item`, the index of their
-- item in `items`; group and separator rows are marked valid = false so they can't be picked.
function M.rows(items, query)
  local indexOf = {}
  for i, it in ipairs(items) do indexOf[it] = i end
  local rows, first = {}, nil
  for _, it in ipairs(palette.filter(items, query)) do
    if it.kind == "entry" then
      rows[#rows + 1] = { text = it.title, item = indexOf[it] }
      first = first or #rows
    else
      rows[#rows + 1] = { text = it.kind == "separator" and M.SEPARATOR or it.title, kind = it.kind, valid = false }
    end
  end
  return rows, first
end

-- Top-left for a w x h menu at the cursor, kept inside the cursor's screen frame {x, y, w, h}.
function M.placeNear(mouse, frame, w, h)
  return {
    x = math.max(frame.x, math.min(mouse.x, frame.x + frame.w - w)),
    y = math.max(frame.y, math.min(mouse.y, frame.y + frame.h - h)),
  }
end

-- Shows the menu and waits, via sleep(ms), until the user picks or dismisses it.
-- Returns the chosen entry, or nil. sleep must hand time back to Hammerspoon's run loop
-- (the chooser reports the pick through it), so this only works inside a coroutine.
function M.show(items, sleep)
  -- Blocking here would stop the chooser from ever reporting back.
  assert(coroutine.applicationYield and coroutine.isyieldable(),
    "the Prompt Palette needs a Hammerspoon with coroutine.applicationYield, called inside a coroutine")
  local done, picked = false, nil
  local chooser = hs.chooser.new(function(choice)
    picked = choice and choice.item and items[choice.item] or nil
    done = true
  end)
  local gray = { white = 0.5, alpha = 1 }
  local function refresh(query)
    local rows, first = M.rows(items, query)
    for _, r in ipairs(rows) do
      if r.kind then r.text = hs.styledtext.new(r.text, { color = gray }) end
    end
    chooser:choices(rows)
    if first then chooser:selectedRow(first) end
  end
  -- Setting this hands filtering to us, so the Mac filters exactly like the Windows menu.
  chooser:queryChangedCallback(refresh)
  chooser:invalidCallback(function() end)  -- picking a group or separator row does nothing
  chooser:placeholderText("Prompt Palette: type to filter")
  chooser:width(M.WIDTH_PERCENT)
  local visible = math.min(M.ROWS, math.max(#items, 1))
  chooser:rows(visible)
  refresh("")

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local frame = screen:frame()
  local w = frame.w * M.WIDTH_PERCENT / 100
  local h = M.QUERY_HEIGHT + visible * M.ROW_HEIGHT
  local at = M.placeNear(hs.mouse.absolutePosition(), frame, w, h)
  chooser:show(hs.geometry.point(at.x, at.y))

  while not done do sleep(30) end
  chooser:delete()
  return picked
end

return M
