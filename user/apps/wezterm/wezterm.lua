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
c.color_scheme = "Catppuccin Macchiato"
local scheme = wez.color.get_builtin_schemes()["Catppuccin Macchiato"]
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
local callback = wez.action_callback

local mod = {
	c = "CTRL",
	s = "SHIFT",
	a = "ALT",
	l = "LEADER",
}

local keybind = function(mods, key, action)
	return { mods = table.concat(mods, "|"), key = key, action = action }
end

local keys = function()
	local keys = {
		-- CTRL-A, CTRL-A sends CTRL-A
		keybind({ mod.l, mod.c }, "a", act.SendString("\x01")),

		-- pane and tabs
		keybind({ mod.l }, "v", act.SplitVertical({ domain = "CurrentPaneDomain" })),
		keybind({ mod.l }, "h", act.SplitHorizontal({ domain = "CurrentPaneDomain" })),
		keybind({ mod.l }, "z", act.TogglePaneZoomState),
		keybind({ mod.l }, "c", act.SpawnTab("CurrentPaneDomain")),
		keybind({ mod.l }, "j", act.ActivatePaneDirection("Left")),
		keybind({ mod.l }, "k", act.ActivatePaneDirection("Down")),
		keybind({ mod.l }, "l", act.ActivatePaneDirection("Up")),
		keybind({ mod.l }, ";", act.ActivatePaneDirection("Right")),
		keybind({ mod.l }, "x", act.CloseCurrentPane({ confirm = true })),
		keybind({ mod.l }, "q", act.CloseCurrentTab({ confirm = true })),
		keybind({ mod.l, mod.s }, "j", act.AdjustPaneSize({ "Left", 5 })),
		keybind({ mod.l, mod.s }, "k", act.AdjustPaneSize({ "Down", 5 })),
		keybind({ mod.l, mod.s }, "l", act.AdjustPaneSize({ "Up", 5 })),
		keybind({ mod.l, mod.s }, ";", act.AdjustPaneSize({ "Right", 5 })),
		keybind(
			{ mod.l },
			"e",
			act.PromptInputLine({
				description = wez.format({
					{ Attribute = { Intensity = "Bold" } },
					{ Foreground = { AnsiColor = "Fuchsia" } },
					{ Text = "Renaming Tab Title...:" },
				}),
				action = callback(function(win, _, line)
					if line == "" then
						return
					end
					win:active_tab():set_title(line)
				end),
			})
		),

		-- workspaces
		keybind({ mod.l }, "w", act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" })),

		-- copy and paste
		keybind({ mod.c, mod.s }, "c", act.CopyTo("Clipboard")),
		keybind({ mod.c, mod.s }, "v", act.PasteFrom("Clipboard")),
	}

	-- tab navigation
	for i = 1, 9 do
		table.insert(keys, keybind({ mod.l }, tostring(i), act.ActivateTab(i - 1)))
	end
	return keys
end

c.leader = { mods = mod.c, key = "b", timeout_miliseconds = 2000 }
c.keys = keys()

return c
