-- Pure text helpers used by the Action layer (no OS access).
-- Mirrors windows/lib/Format.ahk; tests/format_cases.txt keeps the two identical.
local M = {}

-- "From Google Chrome — localhost:3000": where a Selection came from. A Windows ".exe" is dropped.
function M.sourceLine(app, title)
  app = app:gsub("%.[eE][xX][eE]$", "")
  if title and title ~= "" then return "From " .. app .. " — " .. title end
  return "From " .. app
end

-- Wrap text in a Markdown code fence that is longer than any backtick run inside it,
-- so the text can't close the fence early. Ends with a newline.
function M.fencedBlock(text)
  text = text:gsub("\r\n", "\n"):gsub("\n+$", "")
  local longest = 0
  for run in text:gmatch("`+") do longest = math.max(longest, #run) end
  local fence = ("`"):rep(math.max(3, longest + 1))
  return fence .. "\n" .. text .. "\n" .. fence .. "\n"
end

return M
