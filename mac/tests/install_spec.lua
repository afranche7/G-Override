-- install.sh / uninstall.sh against a temporary home directory, with Homebrew, `open`, `pgrep`,
-- `mdfind` and Hammerspoon's `hs` CLI replaced by stubs. Needs a POSIX shell (macOS or Linux).
local helpers = require("helpers")

local ROOT = helpers.REPO_ROOT

local function sh(cmd)
  local p = assert(io.popen(cmd .. " 2>&1; echo \"exit=$?\""))
  local out = p:read("a")
  p:close()
  local code = tonumber(out:match("exit=(%d+)%s*$"))
  return out:gsub("exit=%d+%s*$", ""), code
end

local function q(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

local function writeFile(path, s)
  local f = assert(io.open(path, "wb"))
  f:write(s)
  f:close()
end

local function writeScript(path, body)
  writeFile(path, "#!/bin/sh\n" .. body)
  sh("chmod +x " .. q(path))
end

-- The hs CLI stub answers `true` to every query, and logs the Lua it was asked to run.
local HS_STUB = [[
echo "$@" >> "$HOME/hs.log"
[ -f "$HOME/.hs-running" ] || { echo "can't access Hammerspoon message port" >&2; exit 69; }
echo true
]]

local function installFakeHammerspoon(app)
  sh("mkdir -p " .. q(app .. "/Contents/Frameworks/hs"))
  writeScript(app .. "/Contents/Frameworks/hs/hs", HS_STUB)
end

-- A fresh temporary home with stubbed system tools. opts.hammerspoon (default true) puts a fake
-- Hammerspoon.app in place; opts.brew (default true) provides a Homebrew stub that installs it.
local function newWorld(opts)
  opts = opts or {}
  local home = (sh("mktemp -d"):gsub("%s+$", ""))
  local bin = home .. "/stub-bin"
  local app = home .. "/Applications/Hammerspoon.app"
  sh("mkdir -p " .. q(bin) .. " " .. q(home .. "/Applications/Claude.app"))
  if opts.hammerspoon ~= false then installFakeHammerspoon(app) end
  if opts.brew ~= false then
    writeScript(bin .. "/brew", 'echo "brew $*" >> "$HOME/calls.log"\n'
      .. 'mkdir -p "$G_OVERRIDE_HAMMERSPOON_APP/Contents/Frameworks/hs"\n'
      .. 'cat > "$G_OVERRIDE_HAMMERSPOON_APP/Contents/Frameworks/hs/hs" <<\'EOF\'\n#!/bin/sh\n' .. HS_STUB .. 'EOF\n'
      .. 'chmod +x "$G_OVERRIDE_HAMMERSPOON_APP/Contents/Frameworks/hs/hs"\n')
  end
  writeScript(bin .. "/open", 'echo "open $*" >> "$HOME/calls.log"\ntouch "$HOME/.hs-running"\n')
  writeScript(bin .. "/pgrep", '[ -f "$HOME/.hs-running" ]\n')
  writeScript(bin .. "/mdfind", "exit 0\n")

  local world = { home = home, app = app, init = home .. "/.hammerspoon/init.lua" }
  function world.run(script, args)
    return sh("HOME=" .. q(home)
      .. " PATH=" .. q(bin .. ":/usr/bin:/bin")
      .. " G_OVERRIDE_HAMMERSPOON_APP=" .. q(app)
      .. " G_OVERRIDE_BREW_FALLBACKS= G_OVERRIDE_WAIT_S=1"
      .. " sh " .. q(ROOT .. "/" .. script) .. " " .. (args or ""))
  end
  function world.log(name) return readFile(home .. "/" .. name) or "" end
  function world.cleanup() sh("rm -rf " .. q(home)) end
  return world
end

local function count(haystack, needle)
  local n, i = 0, 1
  while true do
    local s, e = haystack:find(needle, i, true)
    if not s then return n end
    n, i = n + 1, e + 1
  end
end

local USER_INIT = "-- my own Hammerspoon config\nhs.hotkey.bind({'cmd'}, 'j', function() end)\n"

describe("install.sh", function()
  local w
  after_each(function() if w then w.cleanup() end end)

  it("adds a marked block to a new Hammerspoon init that loads the Helper from this repo", function()
    w = newWorld()
    local out, code = w.run("install.sh")
    assert.are.equal(0, code, out)
    local init = readFile(w.init)
    assert.truthy(init, "init.lua was not created")
    assert.are.equal(1, count(init, "-- >>> G-Override >>>"))
    assert.are.equal(1, count(init, "-- <<< G-Override <<<"))
    assert.truthy(init:find(ROOT .. "/mac/g-override.lua", 1, true), init)
  end)

  it("keeps existing Hammerspoon init content and is idempotent", function()
    w = newWorld()
    sh("mkdir -p " .. q(w.home .. "/.hammerspoon"))
    writeFile(w.init, USER_INIT)
    local _, code1 = w.run("install.sh")
    local first = readFile(w.init)
    local _, code2 = w.run("install.sh")
    local second = readFile(w.init)
    assert.are.equal(0, code1)
    assert.are.equal(0, code2)
    assert.are.equal(USER_INIT, first:sub(1, #USER_INIT))
    assert.are.equal(first, second)
    assert.are.equal(1, count(second, "-- >>> G-Override >>>"))
  end)

  it("installs Hammerspoon with Homebrew when it's missing", function()
    w = newWorld({ hammerspoon = false })
    local out, code = w.run("install.sh")
    assert.are.equal(0, code, out)
    assert.truthy(w.log("calls.log"):find("brew install --cask hammerspoon", 1, true), w.log("calls.log"))
  end)

  it("explains how to get Homebrew and changes nothing when both are missing", function()
    w = newWorld({ hammerspoon = false, brew = false })
    local out, code = w.run("install.sh")
    assert.are_not.equal(0, code)
    assert.truthy(out:find("https://brew.sh", 1, true), out)
    assert.is_nil(readFile(w.init))
  end)

  it("starts Hammerspoon and turns on its auto-launch", function()
    w = newWorld()
    local out, code = w.run("install.sh")
    assert.are.equal(0, code, out)
    assert.truthy(w.log("calls.log"):find("open", 1, true))
    assert.truthy(w.log("hs.log"):find("hs.autoLaunch(true)", 1, true), w.log("hs.log"))
  end)

  it("prints the Accessibility and Screen Recording permission steps", function()
    w = newWorld()
    local out = w.run("install.sh")
    assert.truthy(out:find("Accessibility", 1, true), out)
    assert.truthy(out:find("Screen Recording", 1, true), out)
  end)

  it("--doctor reports all green after an install", function()
    w = newWorld()
    w.run("install.sh")
    local out, code = w.run("install.sh", "--doctor")
    assert.are.equal(0, code, out)
    assert.falsy(out:find("[!!]", 1, true), out)
    assert.truthy(out:find("Claude App found", 1, true), out)
  end)

  it("--doctor changes nothing", function()
    w = newWorld()
    local _, code = w.run("install.sh", "--doctor")
    assert.are_not.equal(0, code)
    assert.is_nil(readFile(w.init))
  end)
end)

describe("uninstall.sh", function()
  local w
  after_each(function() if w then w.cleanup() end end)

  it("removes only the marked block", function()
    w = newWorld()
    sh("mkdir -p " .. q(w.home .. "/.hammerspoon"))
    writeFile(w.init, USER_INIT)
    w.run("install.sh")
    local out, code = w.run("uninstall.sh")
    assert.are.equal(0, code, out)
    assert.are.equal(USER_INIT, readFile(w.init))
  end)

  it("leaves a Hammerspoon init without a block alone", function()
    w = newWorld()
    sh("mkdir -p " .. q(w.home .. "/.hammerspoon"))
    writeFile(w.init, USER_INIT)
    local _, code = w.run("uninstall.sh")
    assert.are.equal(0, code)
    assert.are.equal(USER_INIT, readFile(w.init))
  end)

  it("leaves a block with no end marker alone instead of deleting the rest of the file", function()
    w = newWorld()
    sh("mkdir -p " .. q(w.home .. "/.hammerspoon"))
    local broken = USER_INIT .. "\n-- >>> G-Override >>>\nmy own code after a half-deleted block\n"
    writeFile(w.init, broken)
    local out, code = w.run("uninstall.sh")
    assert.are.equal(0, code, out)
    assert.are.equal(broken, readFile(w.init))
  end)

  it("keeps a symlinked init.lua a symlink", function()
    w = newWorld()
    sh("mkdir -p " .. q(w.home .. "/.hammerspoon") .. " " .. q(w.home .. "/dotfiles"))
    writeFile(w.home .. "/dotfiles/init.lua", USER_INIT)
    sh("ln -s " .. q(w.home .. "/dotfiles/init.lua") .. " " .. q(w.init))
    w.run("install.sh")
    assert.truthy(readFile(w.home .. "/dotfiles/init.lua"):find("G-Override", 1, true))
    w.run("uninstall.sh")
    assert.are.equal(USER_INIT, readFile(w.home .. "/dotfiles/init.lua"))
    assert.are.equal("link", (sh("[ -L " .. q(w.init) .. " ] && echo link"):gsub("%s+$", "")))
  end)

  it("makes --doctor report the block gone", function()
    w = newWorld()
    w.run("install.sh")
    w.run("uninstall.sh")
    local out, code = w.run("install.sh", "--doctor")
    assert.are_not.equal(0, code)
    assert.truthy(out:find("[!!] Loaded by Hammerspoon at startup", 1, true), out)
  end)
end)

describe("install.sh --help", function()
  it("prints the usage text and nothing from the script body", function()
    local w = newWorld()
    local out, code = w.run("install.sh", "--help")
    w.cleanup()
    assert.are.equal(0, code)
    assert.truthy(out:find("--doctor", 1, true))
    assert.falsy(out:find("set -eu", 1, true))
  end)
end)
