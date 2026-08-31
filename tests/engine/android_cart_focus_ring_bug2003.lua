package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check = T.check
love = love or require("tests.love_stub")

love.graphics.setLineJoin = love.graphics.setLineJoin or function() end
love.graphics.newShader = love.graphics.newShader or function() return {} end

local Kit = require("src.ui.kit.Kit")
local LauncherView = require("src.import.LauncherView")

-- #2003: the spatial-navigation ring is rectangular, while the launcher cart
-- is a projected polygon drawn over it.  When touch leaves the controller ring
-- armed, only the rounded upper-left edge peeks out from behind the cartridge.
-- A touch press changes input modality, so that controller-only decoration
-- must disappear until keyboard/gamepad navigation is used again.
local imp = {
  _flex = true,
  _touchAt = {},
  _tabScrollMax = {},
  _tabScroll = {},
  tab = "red",
}

Kit.focusId = "rom-red"
Kit._ringShown = true

LauncherView.touchpressed(imp, 1, 100, 100)
check(Kit._ringShown == false,
  "touch input hides the controller focus ring behind the cartridge")

Kit.navigate("right")
check(Kit._ringShown == true,
  "controller/keyboard navigation can show the focus ring again")

T.finish("Android cart touch focus ring #2003")
