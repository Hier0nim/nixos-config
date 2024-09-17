-- Pull in the wezterm API
local wez = require("wezterm")

local appearance = require("lua/appearance")
local mappings = require("lua/keymappings")

local bar = wez.plugin.require("https://github.com/adriankarlen/bar.wezterm")

-- This table will hold the configuration.
local c = {}

-- in newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wez.config_builder then
	c = wez.config_builder()
end

c.front_end = "WebGpu"

-- General configurations
c.font_rules = {
	{
		italic = true,
		intensity = "Half",
		font = wez.font("JetBrains Mono", { weight = "Medium", italic = true }),
	},
}
c.font_size = 12
c.adjust_window_size_when_changing_font_size = false
c.audible_bell = "Disabled"
c.scrollback_lines = 3000
c.default_workspace = "main"
c.status_update_interval = 2000

-- appearance
appearance.apply_to_config(c)

-- keys
mappings.apply_to_config(c)

-- bar
bar.apply_to_config(c, { enabled_modules = { hostname = false } })

return c
