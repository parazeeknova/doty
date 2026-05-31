-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
  general = {
    gaps_in          = 2,
    gaps_out         = 4,

    border_size      = 2,

    col              = {
      active_border   = { colors = { "rgba(ddc7a1ee)" } },
      inactive_border = "rgba(595959aa)",
    },

    -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = true,

    -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
    allow_tearing    = false,

  },

  decoration = {
    rounding         = 0,
    rounding_power   = 0,

    active_opacity   = 0.85,
    inactive_opacity = 0.75,
    dim_inactive     = true,
    dim_strength     = 0.08,
    dim_special      = 0.4,

    shadow           = {
      enabled      = false,
      range        = 10,
      render_power = 3,
      color        = 0xee1a1a1a,
    },

    blur             = {
      enabled           = true,
      new_optimizations = true,
      size              = 4,
      passes            = 2,
      contrast          = 1.5,
      brightness        = 0.8,
      vibrancy          = 0,
      vibrancy_darkness = 0,
    },
  },

  animations = {
    enabled = true,
  },

  plugin = {
    hyprspace = {
      panel_height = 200,
      panel_border_width = 2,
      workspace_margin = 4,
      reserved_area = 4,
      workspace_border_size = 1,

      center_aligned = true,
      on_bottom = false,
      draw_active_workspace = true,
      hide_real_layers = false,
      affect_strut = false,

      auto_drag = false,
      auto_scroll = true,
      exit_on_click = true,
      exit_on_switch = true,

      disable_gestures = false,
      swipe_fingers = 3,
      swipe_distance = 300,
      swipe_force_speed = 30,
      swipe_cancel_ratio = 0.5,
      click_release_threshold_ms = 200,
    },
  },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Custom Animations
hl.curve("easeInOutQuart", { type = "bezier", points = { { 0.76, 0 }, { 0.24, 1 } } })

-- Default springs
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 3.5, bezier = "almostLinear" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2.5, bezier = "easeInOutQuart", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.5, bezier = "easeInOutQuart", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
