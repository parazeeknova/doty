---------------
---- INPUT ----
---------------
hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
		},
	},
	cursor = {
		no_warps = true,
	},
	plugin = {
		kinetic_scroll = {
			enabled = 1,
			decel = 0.99,
			min_velocity = 1.3,
			interval_ms = 8,
			delta_multiplier = 1.25,
			disable_in_browser = 1,
			stop_on_target_change = 1,
		},
	},
})

hl.gesture({
	fingers = 4,
	direction = "horizontal",
	action = "workspace",
})
