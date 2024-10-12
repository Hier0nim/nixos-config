-- Pull in the wezterm API
local wez = require("wezterm")

-- This table will hold the configuration.
local c = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wez.config_builder then
	c = wez.config_builder()
end

-- General configurations
c.adjust_window_size_when_changing_font_size = false
c.audible_bell = "Disabled"
c.scrollback_lines = 3000
c.default_workspace = "main"
c.status_update_interval = 2000
c.front_end = "WebGpu"
c.enable_wayland = false

-- Appearance
c.color_scheme = "Catppuccin Mocha"
local scheme = wez.color.get_builtin_schemes()["Catppuccin Mocha"]
c.colors = {
	split = scheme.ansi[2],
}
c.inactive_pane_hsb = { brightness = 0.9 }
c.window_padding = { left = "1cell", right = "1cell", top = "0.5cell", bottom = 0 }
c.window_decorations = "RESIZE"

-- Bar settings
c.show_new_tab_button_in_tab_bar = false
c.hide_tab_bar_if_only_one_tab = true
c.use_fancy_tab_bar = false

-- Font settings
c.font = wez.font("JetBrains Mono", { weight = "Medium" })
c.font_rules = {
	{
		italic = true,
		intensity = "Half",
		font = wez.font("JetBrains Mono", { weight = "Medium", italic = true }),
	},
}
c.font_size = 12

-- Keybindings
local act = wez.action

local mod = {
	c = "CTRL",
	s = "SHIFT",
	a = "ALT",
}

local keybind = function(mods, key, action)
	return { mods = table.concat(mods, "|"), key = key, action = action }
end

local keys = function()
	local keys = {
		-- copy and paste
		keybind({ mod.c, mod.s }, "c", act.CopyTo("Clipboard")),
		keybind({ mod.c, mod.s }, "v", act.PasteFrom("Clipboard")),
	}
	return keys
end

c.keys = keys()

return c
