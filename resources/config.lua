oxwm.set_terminal("st")
oxwm.set_modkey("Mod1")
oxwm.set_tags({ "1", "2", "3", "4", "5", "6", "7", "8", "9" })

oxwm.gaps.set_inner(5, 5)
oxwm.gaps.set_outer(5, 5)
oxwm.gaps.set_enabled(true)

oxwm.border.set_width(2)
oxwm.border.set_focused_color(0x6dade3)
oxwm.border.set_unfocused_color(0x444444)
local colors = {
    red = "#f7768e",
    cyan = "#0db9d7",
    green = "#9ece6a",
    light_blue = "#7aa2f7",
    blue = "#6dade3",
    purple = "#ad8ee6",
    grey = "#bbbbbb",
    separator = "#444b6a",
}
-- oxwm.bar.set_font("monospace:size=10")
oxwm.bar.set_font("Iosevka Nerd Font Propo:style=Bold:size=14")
oxwm.bar.set_scheme_normal(0xbbbbbb, 0x1a1b26, 0x444444)
oxwm.bar.set_scheme_selected(0x0db9d7, 0x1a1b26, 0xad8ee6)
oxwm.bar.set_scheme_occupied(0x0db9d7, 0x1a1b26, 0x0db9d7)
oxwm.bar.set_scheme_urgent(0xf7768e, 0x1a1b26, 0xf7768e)

local blocks = {
    -- oxwm.bar.block.battery({
    --     charging = "󰂄 Bat: {}%",
    --     discharging = "󰁹 Bat: {}%",
    --     full = "󰁹 Bat: {}%",
    --     format = "",
    --     interval = 30,
    --     color = colors.green,
    --     underline = true
    -- }),
    -- oxwm.bar.block.static({
    --     text = " │  ",
    --     format = "",
    --     interval = 999999999,
    --     color = colors.lavender,
    --     underline = false
    -- }),
    oxwm.bar.block.ram({
        format = "󰍛 {used}/{total} GB",
        interval = 5,
        color = colors.light_blue,
        underline = true
    }),
    oxwm.bar.block.static({
        text = "│",
        format = "",
        interval = 999999999,
        color = colors.separator,
        underline = false
    }),
    oxwm.bar.block.shell({
        command = "uname -r",
        format = " {}",
        interval = 999999999,
        color = colors.red,
        underline = true
    }),
    oxwm.bar.block.static({
        text = "│",
        format = "",
        interval = 999999999,
        color = colors.separator,
        underline = false
    }),
    oxwm.bar.block.datetime({
        format = "󰸘 {}",
        interval = 1,
        color = colors.cyan,
        underline = true,
        date_format = "%a, %b %d - %-I:%M %P"
    })
}

oxwm.bar.set_blocks(blocks)

local mod = { "Mod1" }
local mod_shift = { "Mod1", "Shift" }
local mod_ctrl = { "Mod1", "Control" }
local mod_ctrl_shift = { "Mod1", "Control", "Shift" }

oxwm.key.bind(mod, "Return", oxwm.spawn_terminal())
oxwm.key.bind(mod, "d", oxwm.spawn("rofi -show drun"))
oxwm.key.bind(mod, "q", oxwm.client.kill())
oxwm.key.bind(mod_shift, "q", oxwm.quit())
oxwm.key.bind(mod_shift, "r", oxwm.restart())

oxwm.key.bind(mod, "j", oxwm.client.focus_stack(1))
oxwm.key.bind(mod, "k", oxwm.client.focus_stack(-1))
oxwm.key.bind(mod_shift, "j", oxwm.client.move_stack(1))
oxwm.key.bind(mod_shift, "k", oxwm.client.move_stack(-1))

oxwm.key.bind(mod, "h", oxwm.set_master_factor(-50))
oxwm.key.bind(mod, "l", oxwm.set_master_factor(50))
oxwm.key.bind(mod, "i", oxwm.inc_num_master(1))
oxwm.key.bind(mod, "p", oxwm.inc_num_master(-1))

oxwm.key.bind(mod, "f", oxwm.client.toggle_fullscreen())
oxwm.key.bind(mod, "Space", oxwm.client.toggle_floating())
oxwm.key.bind(mod, "a", oxwm.toggle_gaps())
oxwm.key.bind(mod, "n", oxwm.layout.cycle())

oxwm.key.bind(mod, "comma", oxwm.monitor.focus(-1))
oxwm.key.bind(mod, "period", oxwm.monitor.focus(1))
oxwm.key.bind(mod_shift, "comma", oxwm.monitor.tag(-1))
oxwm.key.bind(mod_shift, "period", oxwm.monitor.tag(1))

oxwm.key.bind(mod, "Left", oxwm.tag.view_previous())
oxwm.key.bind(mod, "Right", oxwm.tag.view_next())

for i = 1, 9 do
    local key = tostring(i)
    oxwm.key.bind(mod, key, oxwm.tag.view(i))
    oxwm.key.bind(mod_shift, key, oxwm.tag.move_to(i))
    oxwm.key.bind(mod_ctrl, key, oxwm.tag.toggleview(i))
    oxwm.key.bind(mod_ctrl_shift, key, oxwm.tag.toggletag(i))
end

oxwm.rule.add({ class = "Gimp", floating = true })
oxwm.rule.add({ class = "Firefox", tag = 2 })
