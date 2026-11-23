-- Palette file parsing, filtering and placeholder filling (pure; no OS access).
-- Mirrors windows/lib/Palette.ahk; tests/palette_cases.txt keeps the two parsing alike.
--
-- Format (shared with the Windows Helper):
--   ## Title           starts a Palette Entry; the lines below it are its body
--   send: true         optional first body line: submit after inserting
--   @region-snip       whole body: run that capture Action instead of inserting text
--   @window-snip
--   ---                separator
--   # Group            group label
--   {selection} {clipboard}   placeholders in a body (matched case-insensitively)
-- <!-- ... --> comments and text before the first heading are ignored.
local M = {}

local ACTIONS = { ["@region-snip"] = "region-snip", ["@window-snip"] = "window-snip" }

-- Spaces and tabs only, like AutoHotkey's Trim.
local function trim(s) return (s:match("^[ \t]*(.-)[ \t]*$")) end

local function item(kind, title)
  return { kind = kind, title = title or "", body = "", send = false, action = "" }
end

-- Turn a heading's collected lines into an entry, or nothing if it has no title or no body.
local function entryFromHeading(heading)
  if heading.title == "" then return nil end
  local body = heading.lines
  while #body > 0 and trim(body[1]) == "" do table.remove(body, 1) end
  local send = false
  local flag = #body > 0 and body[1]:lower():match("^%s*send:%s*(%a+)%s*$")
  if flag == "true" or flag == "false" then
    send = flag == "true"
    table.remove(body, 1)
  end
  local joined = table.concat(body, "\n"):gsub("[ \t\n]+$", ""):gsub("^%s*\n", "")
  if trim(joined) == "" then return nil end
  local entry = item("entry", heading.title)
  entry.body, entry.send, entry.action = joined, send, ACTIONS[joined:lower()] or ""
  return entry
end

-- The items without separators that would come first or straight after another separator.
local function dropLeadingAndDoubledSeparators(items)
  local out = {}
  for _, it in ipairs(items) do
    if not (it.kind == "separator" and (#out == 0 or out[#out].kind == "separator")) then
      out[#out + 1] = it
    end
  end
  return out
end

-- Drop separators that lead, trail or repeat, and groups with nothing under them.
local function tidy(items)
  local out = dropLeadingAndDoubledSeparators(items)
  local withoutEmptyGroups = {}
  for i, it in ipairs(out) do
    if not (it.kind == "group" and not (out[i + 1] and out[i + 1].kind == "entry")) then
      withoutEmptyGroups[#withoutEmptyGroups + 1] = it
    end
  end
  -- Dropping an empty group can leave a separator first or next to another one.
  out = dropLeadingAndDoubledSeparators(withoutEmptyGroups)
  while #out > 0 and out[#out].kind ~= "entry" do table.remove(out) end
  return out
end

-- Returns a list of {kind = "entry"|"separator"|"group", title, body, send, action}.
function M.parse(text)
  local items, cur = {}, nil
  local function flush()
    if cur then items[#items + 1] = entryFromHeading(cur) end
    cur = nil
  end
  -- A UTF-8 byte order mark goes, as AutoHotkey's FileRead drops it on Windows.
  text = text:gsub("^\239\187\191", ""):gsub("<!%-%-.-%-%->", ""):gsub("\r\n", "\n")
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local t = trim(line)
    local heading = t:match("^##%s+(.+)$")
    local group = t:match("^#%s+(.+)$")
    if heading then
      flush()
      cur = { title = trim(heading), lines = {} }
    elseif t:match("^##%s*$") then
      flush()
      cur = { title = "", lines = {} }
    elseif t == "---" then
      flush()
      items[#items + 1] = item("separator")
    elseif group then
      flush()
      items[#items + 1] = item("group", trim(group))
    elseif cur then
      cur.lines[#cur.lines + 1] = line
    end
  end
  flush()
  return tidy(items)
end

-- Entries whose title contains the query (case-insensitive). An empty query keeps everything,
-- separators and groups included; a real query shows only matching entries.
function M.filter(items, query)
  query = trim(query or "")
  if query == "" then return items end
  local q, out = query:lower(), {}
  for _, it in ipairs(items) do
    if it.kind == "entry" and it.title:lower():find(q, 1, true) then out[#out + 1] = it end
  end
  return out
end

-- Replace {selection} and {clipboard} literally (the values are never read as patterns).
function M.fill(body, selection, clipboard)
  return (body:gsub("{(%a+)}", function(name)
    name = name:lower()
    if name == "selection" then return selection end
    if name == "clipboard" then return clipboard end
  end))
end

-- Whether the body says where the Selection goes (otherwise it is appended as a fenced block).
function M.hasSelectionPlaceholder(body)
  return body:lower():find("{selection}", 1, true) ~= nil
end

return M
