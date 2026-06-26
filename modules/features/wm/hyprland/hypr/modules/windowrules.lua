--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = {
		class = ".*",
	},

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

hl.window_rule({
	name = "satty-float",
	match = {
		class = "satty",
	},
	float = true,
	size = { 800, 400 },
	center = true,
})

hl.window_rule({
	name = "thunar-floating",
	match = {
		class = "^thunar$",
	},
	float = true,
	size = { 1000, 650 },
	center = true,
})

hl.window_rule({
	name = "ghostty-floating",
	match = {
		class = "ghostty.floating",
		title = ".+",
	},
	float = true,
	size = { 1000, 600 },
	center = true,
})

hl.layer_rule({
	name = "quickshell-blur",
	match = {
		namespace = "quickshell",
	},
	animation = "slide left",
	blur = true,
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "github-graph-blur",
	match = {
		namespace = "github-graph",
	},
	blur = true,
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "workspace-overview-blur",
	match = {
		namespace = "workspace-overview",
	},
	blur = true,
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "waybar-blur",
	match = {
		namespace = "waybar",
	},
	animation = "slide left",
	blur = true,
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "osd-blur",
	match = {
		namespace = "osd",
	},
	animation = "slide top",
	blur = true,
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "mako-blur",
	match = {
		namespace = "notifications",
	},
	blur = true,
	animation = "slide top",
	ignore_alpha = 0.01,
})

hl.layer_rule({
	name = "wallpaper-switcher-effects",
	match = {
		namespace = "wallpaper_switcher",
	},
	animation = "slide left",
	dim_around = true,
})

-- Workspace assignments for specific applications using exact class names (anchored regex)
local workspace_assignments = {
	["1"] = { "^zen.*$", "^[Vv]ivaldi.*$" },
	["2"] = { "^code-insiders$", "^dev\\.warp\\.Warp$", "^[Ee]macs$" },
	["3"] = { "^com\\.mitchellh\\.ghostty$", "^Code$", "^code$" },
	["4"] = { "^[Ff]ree[Tt]ube$" },
	["5 silent"] = { "^[Ss]potify$" },
	["6"] = { "^vesktop$", "^TelegramDesktop$" },
	["8"] = { "^[Ss]team$", "^[Ll]utris$", "^[Hh]eroic$" },
	["9"] = { "^virt-manager$", "^qemu.*$", "^Qemu.*$" },
	["10"] = { "^[Vv]mware.*$", "^[Pp]odman-[Dd]esktop$" },
}

for ws, classes in pairs(workspace_assignments) do
	for _, class in ipairs(classes) do
		hl.window_rule({
			match = {
				class = class,
			},
			workspace = ws,
		})
	end
end

-- Scratchpad rules for GitKraken & Helium Browser
hl.window_rule({
	name = "gitkraken-scratchpad",
	match = {
		class = "^gitkraken$",
	},
	workspace = "special:gitkraken",
	float = true,
	size = { 1680, 1010 },
	center = true,
})

hl.window_rule({
	name = "helium-scratchpad",
	match = {
		class = "^helium$",
	},
	workspace = "special:helium",
	float = true,
	size = { 1680, 1010 },
	center = true,
})

hl.window_rule({
	name = "obs-scratchpad",
	match = {
		class = "^(com\\.obsproject\\.Studio|obs)$",
	},
	workspace = "special:obs",
	float = true,
	size = { 1680, 1010 },
	center = true,
})

local colors = {}
local colors_status, c = pcall(require, "modules.colors")
if colors_status then
	colors = c
end

-- Pyprland Scratchpads
hl.window_rule({
	name = "pypr-term-scratchpad",
	match = {
		class = "^kitty\\.pypr$",
	},
	float = true,
	animation = "slide",
	border_color = colors.border_color or "rgb(a9b665)",
})

-- Force full opacity for VMware Workstation
hl.window_rule({
	name = "vmware-opacity",
	match = {
		class = "^[Vv]mware.*$",
	},
	opacity = "1.0 override 1.0 override",
})

-- Force full opacity for QEMU/KVM/Virt-manager VMs
hl.window_rule({
	name = "qemu-kvm-opacity",
	match = {
		class = "^(virt-manager|[Qq]emu.*)$",
	},
	opacity = "1.0 override 1.0 override",
})

-- Set starting width for browsers in scrolling layout
hl.window_rule({
	name = "zen-starting-width",
	match = {
		class = "^zen.*$",
	},
	scrolling_width = 0.7,
})

hl.window_rule({
	name = "vivaldi-starting-width",
	match = {
		class = "^[Vv]ivaldi.*$",
	},
	scrolling_width = 0.7,
})

hl.window_rule({
	name = "brave-starting-width",
	match = {
		class = "^brave-origin-nightly$",
	},
	scrolling_width = 0.7,
})
