-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
local colors = {}
local colors_status, c = pcall(require, "modules.colors")
if colors_status then
	colors = c
else
	colors = {
		active_border = "rgba(ddc7a1ee)",
		inactive_border = "rgba(595959aa)",
		shadow_color = "0xee1a1a1a",
	}
end

local glass_state_file = io.open(os.getenv("HOME") .. "/.cache/quickshell/glass_state", "r")
local glass_enabled = true
if glass_state_file then
	local content = glass_state_file:read("*all"):gsub("%s+", "")
	glass_enabled = (content == "true")
	glass_state_file:close()
end

local active_opacity = 1.0
local inactive_opacity = 1.0
if glass_enabled then
	active_opacity = 0.85
	inactive_opacity = 0.75
end

hl.config({
	general = {
		gaps_in = 2,
		gaps_out = 2,
		border_size = 1,

		col = {
			active_border = {
				colors = { colors.active_border },
			},
			inactive_border = colors.inactive_border,
		},

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = true,

		-- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		allow_tearing = false,
	},

	decoration = {
		rounding = 0,
		rounding_power = 0,

		active_opacity = active_opacity,
		inactive_opacity = inactive_opacity,
		dim_inactive = true,
		dim_strength = 0.08,
		dim_special = 0.4,

		shadow = {
			enabled = false,
			range = 6,
			render_power = 2,
			color = tonumber(colors.shadow_color) or 0xee1a1a1a,
		},

		blur = {
			enabled = glass_enabled,
			new_optimizations = true,
			size = 4,
			passes = 2,
			contrast = 1.5,
			brightness = 0.8,
			vibrancy = 0,
			vibrancy_darkness = 0,
			popups = true,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Curves
hl.curve("expressiveFastSpatial", {
	type = "bezier",
	points = { { 0.42, 1.67 }, { 0.21, 0.90 } },
})
hl.curve("expressiveSlowSpatial", {
	type = "bezier",
	points = { { 0.39, 1.29 }, { 0.35, 0.98 } },
})
hl.curve("expressiveDefaultSpatial", {
	type = "bezier",
	points = { { 0.38, 1.21 }, { 0.22, 1.00 } },
})
hl.curve("emphasizedDecel", {
	type = "bezier",
	points = { { 0.05, 0.7 }, { 0.1, 1 } },
})
hl.curve("emphasizedAccel", {
	type = "bezier",
	points = { { 0.3, 0 }, { 0.8, 0.15 } },
})
hl.curve("standardDecel", {
	type = "bezier",
	points = { { 0, 0 }, { 0, 1 } },
})
hl.curve("menu_decel", {
	type = "bezier",
	points = { { 0.1, 1 }, { 0, 1 } },
})
hl.curve("menu_accel", {
	type = "bezier",
	points = { { 0.52, 0.03 }, { 0.72, 0.08 } },
})
hl.curve("stall", {
	type = "bezier",
	points = { { 1, -0.1 }, { 0.7, 0.85 } },
})
hl.curve("wobbly", {
	type = "bezier",
	points = { { 0.2, 1.1 }, { 0.2, 1.0 } },
})
-- Configs
-- windows
hl.animation({
	leaf = "windowsIn",
	enabled = true,
	speed = 5,
	bezier = "wobbly",
	style = "popin 85%",
})
hl.animation({
	leaf = "fadeIn",
	enabled = true,
	speed = 4,
	bezier = "emphasizedDecel",
})
hl.animation({
	leaf = "windowsOut",
	enabled = true,
	speed = 4,
	bezier = "wobbly",
	style = "popin 90%",
})
hl.animation({
	leaf = "fadeOut",
	enabled = true,
	speed = 3,
	bezier = "emphasizedDecel",
})
hl.animation({
	leaf = "fade",
	enabled = true,
	speed = 4,
	bezier = "emphasizedDecel",
})
hl.animation({
	leaf = "windowsMove",
	enabled = true,
	speed = 5,
	bezier = "wobbly",
})
hl.animation({
	leaf = "border",
	enabled = true,
	speed = 10,
	bezier = "emphasizedDecel",
})

-- layers
hl.animation({
	leaf = "layersIn",
	enabled = true,
	speed = 2.7,
	bezier = "emphasizedDecel",
	style = "popin 93%",
})
hl.animation({
	leaf = "layersOut",
	enabled = true,
	speed = 2.4,
	bezier = "menu_accel",
	style = "popin 94%",
})
-- fade
hl.animation({
	leaf = "fadeLayersIn",
	enabled = true,
	speed = 0.5,
	bezier = "menu_decel",
})
hl.animation({
	leaf = "fadeLayersOut",
	enabled = true,
	speed = 2.7,
	bezier = "stall",
})
-- workspaces
hl.animation({
	leaf = "workspaces",
	enabled = true,
	speed = 5.5,
	bezier = "expressiveDefaultSpatial",
	style = "slidefade 20%",
})
-- specialWorkspace
hl.animation({
	leaf = "specialWorkspaceIn",
	enabled = true,
	speed = 2.8,
	bezier = "emphasizedDecel",
	style = "slidevert",
})
hl.animation({
	leaf = "specialWorkspaceOut",
	enabled = true,
	speed = 1.2,
	bezier = "emphasizedAccel",
	style = "slidevert",
})
-- zoom
hl.animation({
	leaf = "zoomFactor",
	enabled = true,
	speed = 3,
	bezier = "standardDecel",
})
