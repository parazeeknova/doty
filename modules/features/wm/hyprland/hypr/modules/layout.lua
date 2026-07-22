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

-- This requires https://github.com/yayuuu/hyprland-scroll-overview plugin
-- hyprpm add https://github.com/yayuuu/hyprland-scroll-overview.git && hyprpm update
if hl.plugin and hl.plugin.scrolloverview then
	hl.plugin.scrolloverview.configure({
		gesture_distance = 300,
		scale = 0.6,
		workspace_gap = 10,
		wallpaper = 0,
		blur = true,
		shadow = {
			enabled = false,
			range = 6,
			render_power = 2,
			color = tonumber(colors.shadow_color) or 0xee1a1a1a,
		},
	})
end

-- This requires https://github.com/VirtCode/hypr-dynamic-cursors plugin
-- hyprpm add https://github.com/virtcode/hypr-dynamic-cursors && hyprpm enable dynamic-cursors
local function apply_dynamic_cursors_config()
	pcall(function()
		hl.config({
			["plugin:dynamic-cursors:enabled"] = true,
			["plugin:dynamic-cursors:mode"] = "tilt",
			["plugin:dynamic-cursors:threshold"] = 1,

			["plugin:dynamic-cursors:rotate:length"] = 20,
			["plugin:dynamic-cursors:rotate:offset"] = 0.0,

			["plugin:dynamic-cursors:tilt:limit"] = 2000,
			["plugin:dynamic-cursors:tilt:activation"] = "negative_quadratic",
			["plugin:dynamic-cursors:tilt:window"] = 100,
			["plugin:dynamic-cursors:tilt:full"] = 40,

			["plugin:dynamic-cursors:stretch:limit"] = 3000,
			["plugin:dynamic-cursors:stretch:activation"] = "quadratic",
			["plugin:dynamic-cursors:stretch:window"] = 100,

			["plugin:dynamic-cursors:shake:enabled"] = false,
			["plugin:dynamic-cursors:shake:threshold"] = 6.0,
			["plugin:dynamic-cursors:shake:base"] = 4.0,
			["plugin:dynamic-cursors:shake:speed"] = 4.0,
			["plugin:dynamic-cursors:shake:influence"] = 0.0,
			["plugin:dynamic-cursors:shake:limit"] = 0.0,
			["plugin:dynamic-cursors:shake:timeout"] = 2000,
			["plugin:dynamic-cursors:shake:effects"] = false,
			["plugin:dynamic-cursors:shake:ipc"] = false,

			["plugin:dynamic-cursors:hyprcursor:nearest"] = 1,
			["plugin:dynamic-cursors:hyprcursor:enabled"] = true,
			["plugin:dynamic-cursors:hyprcursor:resolution"] = -1,
			["plugin:dynamic-cursors:hyprcursor:fallback"] = "clientside",
		})
	end)
end

if hl.on then
	hl.on("hyprland.start", apply_dynamic_cursors_config)
end
apply_dynamic_cursors_config()


-- This requires https://github.com/hyprnux/hyprglass plugin
-- hyprpm add https://github.com/hyprnux/hyprglass && hyprpm enable hyprglass
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

	-- Clear Preset for semi glass effect
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
