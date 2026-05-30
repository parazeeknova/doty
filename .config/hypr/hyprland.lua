package.path = package.path .. ";/home/parazeeknova/.config/hypr/Hyprspace/?.lua"
local hyprspace = require("hyprspace")
hyprspace.setup()

require('modules.core.monitors')
require('modules.core.input')
require('modules.binds')
require('modules.autostart')
require('modules.env')
require('modules.decorations')
require('modules.layout')
require('modules.misc')
require('modules.windowrules')
