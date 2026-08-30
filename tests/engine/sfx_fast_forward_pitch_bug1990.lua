-- Regression for #1990: fast-forward must not pitch ordinary SFX up.
-- #1952 intentionally accelerates blocking jingles/fanfares so gameplay
-- does not stall on them, but non-blocking one-shots should keep their
-- native playback pitch just like music does.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local eq = T.eq

local previousLove = _G.love
local sources = {}

local function newStubSource()
  local src = { pitch = 1, playing = false }
  function src:setPitch(value) self.pitch = value end
  function src:getPitch() return self.pitch end
  function src:setVolume() end
  function src:stop() self.playing = false end
  function src:play() self.playing = true end
  function src:isPlaying() return self.playing end
  sources[#sources + 1] = src
  return src
end

_G.love = {
  audio = {
    newSource = function() return newStubSource() end,
  },
}

package.loaded["src.core.Sound"] = nil
local Sound = require("src.core.Sound")

local data = {
  audio = {
    sfx = {
      Bug1990_Beep = { file = "bug1990-beep.wav" },
    },
  },
}

Sound.setRate(4)
local src = Sound.play(data, "Bug1990_Beep")
eq(src and src:getPitch(), 1,
  "ordinary SFX keep native pitch while game logic runs at 4X")

Sound.setRate(1)
package.loaded["src.core.Sound"] = nil
_G.love = previousLove

T.finish("sfx_fast_forward_pitch_bug1990")
