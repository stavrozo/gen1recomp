-- Regression: a field RARE CANDY evolution must unwind the persistent
-- "What? MON is evolving!" box after the result text finishes.  The candy
-- path deliberately keeps the party picker and bag underneath the evolution;
-- unlike a post-battle evolution, that extra stack depth exposed a stale
-- intro box that could become the top state and soft-lock input.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

package.loaded["src.core.Sound"] = {
  play = function() end,
  playCry = function() end,
  playPress = function() end,
}
package.loaded["src.core.Music"] = {
  stop = function() end,
  play = function() end,
  special = function() return nil end,
  restoreMap = function() end,
}

local Fixtures = require("tests.modkit.fixtures")
local Bag = require("src.inventory.Bag")
local BagMenu = require("src.ui.BagMenu")
local BattleState = require("src.battle.BattleState")
local EvolutionState = require("src.ui.EvolutionState")
local PartyMenu = require("src.ui.PartyMenu")
local Pokemon = require("src.pokemon.Pokemon")
local StateStack = require("src.core.StateStack")
local TextBox = require("src.render.TextBox")
local StatBox = BattleState.StatBox

local Data = Fixtures.fresh()
require("src.render.Font").load(Data)
Data.items.RARE_CANDY = {
  id = "RARE_CANDY", index = 90, name = "RARE CANDY", price = 4800,
  tossable = true,
}
-- FIXMON_C normally stops at level 1 and has no evolution, which makes it a
-- clean fixture for a single 5 -> 6 candy evolution with no move-learning
-- screen in between.
Data.pokemon.FIXMON_C.evolutions = {
  { method = "LEVEL", level = 6, species = "FIXMON_B" },
}

local function newGame()
  local mon = Pokemon.new(Data, "FIXMON_C", 5)
  local game = {
    data = Data,
    save = {
      party = { mon },
      player = { name = "RED", id = 1 },
      inventory = {},
      options = { textSpeed = 1 },
      flags = {},
      pokedex = { seen = {}, owned = {} },
      money = 0,
    },
  }
  game.stack = setmetatable({}, { __index = StateStack })
  game.stack:init()
  game.input = { pressed = nil }
  function game.input:wasPressed(key) return self.pressed == key end
  function game.input:isDown() return false end
  Bag.add(game.save, "FIX_POTION", 1, Data)
  Bag.add(game.save, "RARE_CANDY", 1, Data)
  return game, mon
end

local function step(game)
  game.stack:update(1 / 60)
end

local function tap(game, key)
  game.input.pressed = key
  step(game)
  game.input.pressed = nil
end

local function rowFor(list, id)
  for i, row in ipairs(list.items) do
    if row.value == id then return i end
  end
end

local function isTextBox(s) return getmetatable(s) == TextBox end
local function isPicker(s) return getmetatable(s) == PartyMenu end

local function textOf(box)
  local out = {}
  for _, page in ipairs(box.pages or {}) do
    for _, line in ipairs(page) do out[#out + 1] = line end
  end
  return table.concat(out, " ")
end

local function finishPromptBox(game, box)
  for _ = 1, 2000 do
    if game.stack:top() ~= box then return true end
    -- soundOpts(..., auto.wait=true) drops back to the normal A/B path once
    -- its trailing fanfare has completed.
    if box.done and box.auto == nil and not box.waiting then
      tap(game, "a")
      return game.stack:top() ~= box
    end
    step(game)
  end
  return false
end

local game, mon = newGame()
local list = BagMenu.new(game, {})
game.stack:push(list)
local row = assert(rowFor(list, "RARE_CANDY"), "RARE CANDY row missing")
list.index = row
list.onChoose(list.items[row], list)

-- USE/TOSS pops itself before running USE.
local useToss = game.stack:top()
assert(useToss and useToss.items and useToss.items[1], "USE/TOSS never opened")
game.stack:pop()
useToss.items[1].onSelect()

local picker = game.stack:top()
check(isPicker(picker), "RARE CANDY opened the party picker")
tap(game, "a")
eq(mon.level, 6, "the candy raised the mon to its evolution level")

local levelBox = game.stack:top()
check(isTextBox(levelBox), "the grew-to-level line opened")
check(finishPromptBox(game, levelBox), "the level line completed")

local stat = game.stack:top()
check(getmetatable(stat) == StatBox, "the stat box followed the level line")
tap(game, "a")

local intro = game.stack:top()
if check(isTextBox(intro), "the evolution intro box opened") then
  check(textOf(intro):find("is evolving", 1, true) ~= nil,
        "it is the persistent IsEvolvingText box")
end

local evo
for _ = 1, 1000 do
  evo = game.stack:top()
  if getmetatable(evo) == EvolutionState then break end
  step(game)
end
check(getmetatable(evo) == EvolutionState, "the evolution movie opened")

local result
for _ = 1, 1000 do
  result = game.stack:top()
  if result ~= evo and isTextBox(result)
     and textOf(result):find("evolved", 1, true) then break end
  step(game)
end
if check(isTextBox(result), "the evolved-into result box opened") then
  check(textOf(result):find("evolved", 1, true) ~= nil,
        "the result text says the mon evolved")
end
eq(mon.species, "FIXMON_B", "the species change completed")
check(finishPromptBox(game, result), "the result box completed")

-- This is the Android failure: the result box and movie disappear, but the
-- old stay=true intro is left on top.  A stay box has no exit path once its
-- onShown callback has fired, so the player is stuck forever on
-- "What? ... is evolving!".
check(game.stack:top() ~= intro,
      "the stale 'is evolving!' intro is removed after a candy evolution")
check(not isPicker(game.stack:top()),
      "the kept-open party picker is closed when evolution completes")
eq(game.stack:top(), list,
   "the field bag is restored after the candy evolution, ready for another item")

T.finish()
