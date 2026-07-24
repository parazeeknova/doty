hl.config({
	general = {
		layout = "scrolling",
	},
	scrolling = {
		column_width = 0.6,
		follow_focus = true,
		direction = "right",
		fullscreen_on_one_column = true,
		wrap_focus = false,
		wrap_swapcol = false,
	},
	dwindle = {
		preserve_split = true,
	},
	plugin = {
		scrolloverview = {
			gesture_distance = 300,
			scale = 0.65,
			workspace_gap = 2,
			layout = "vertical",
			wallpaper = 0,
			blur = true,
		},
		dynamic_cursors = {
			enabled = true,
			mode = "tilt",
			threshold = 1,
			rotate = {
				length = 20,
				offset = 0.0,
			},
			tilt = {
				limit = 5000,
				activation = "negative_quadratic",
				window = 100,
				full = 60,
			},
			shake = {
				enabled = false,
				threshold = 6.0,
				base = 4.0,
				speed = 4.0,
				influence = 0.0,
				limit = 0.0,
				timeout = 2000,
				effects = false,
				ipc = false,
			},
			hyprcursor = {
				nearest = 1,
				enabled = true,
				resolution = -1,
				fallback = "clientside",
			},
		},
	},
})

local colors = {}
local colors_status, c = pcall(require, "modules.colors")
if colors_status then
	colors = c
else
	colors = {
		shadow_color = "0xee1a1a1a",
	}
end

if hl.plugin.hyprglass then
	local hg = hl.plugin.hyprglass

	-- Read initial glass state
	local glass_state_file = io.open(os.getenv("HOME") .. "/.cache/quickshell/glass_state", "r")
	local glass_enabled = true
	if glass_state_file then
		local content = glass_state_file:read("*all"):gsub("%s+", "")
		glass_enabled = (content == "true")
		glass_state_file:close()
	end

	-- Determine matugen generated accent tint color
	local tint_color = 0x8899aa22
	if colors.accent_hex then
		tint_color = tonumber("0x" .. colors.accent_hex .. "22") or 0x8899aa22
	end

	hg.config({
		enabled = glass_enabled,
		default_theme = "dark",
		default_preset = "clear",
		tint_color = tint_color,
		brightness = 0.7,
		layers = {
			enabled = 1,
		},
	})

	hg.layer("waybar", {
		preset = "clear",
	})
	hg.layer("quickshell", {
		preset = "clear",
	})
	hg.layer("github-graph", {
		preset = "clear",
	})
	hg.layer("osd", {
		preset = "clear",
	})
	hg.layer("workspace-overview", {
		preset = "clear",
	})
	hg.layer("notifications", {
		preset = "clear",
	})

	-- @parazeeknova's lg config
	hg.preset("clear", {
		blur_strength = 1.0,
		blur_iterations = 0.82,
		refraction_strength = 0.96,
		chromatic_aberration = 0.95,
		fresnel_strength = 0.95,
		specular_strength = 0.45,
		glass_opacity = 0.91,
		edge_thickness = 0.035,
		lens_distortion = 0.8,
		dark = {
			brightness = 0.82,
			contrast = 0.92,
			saturation = 0.82,
			vibrancy = 0.12,
			vibrancy_darkness = 0.12,
			adaptive_dim = 0.32,
			adaptive_boost = 0.01,
		},
	})

	if glass_enabled then
		hl.window_rule({
			name = "prevent-double-blur",
			match = {
				class = ".*",
			},
			no_blur = true,
		})
	end
end
