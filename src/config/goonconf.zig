const std = @import("std");
const config_mod = @import("config.zig");
const Config = config_mod.Config;
const Keybind = config_mod.Keybind;
const Action = config_mod.Action;
const Rule = config_mod.Rule;
const Block = config_mod.Block;
const BlockType = config_mod.BlockType;
const MouseButton = config_mod.MouseButton;
const ClickTarget = config_mod.ClickTarget;
const MouseAction = config_mod.MouseAction;

const c = @cImport({
    @cInclude("goonconf.h");
});

var ctx: ?*c.goonconf_ctx_t = null;
var config: ?*Config = null;

pub fn init(cfg: *Config) bool {
    config = cfg;
    ctx = c.goonconf_create();
    if (ctx == null) {
        return false;
    }
    register_functions();
    return true;
}

pub fn deinit() void {
    if (ctx) |context| {
        c.goonconf_destroy(context);
    }
    ctx = null;
    config = null;
}

pub fn load_file(path: []const u8) bool {
    const context = ctx orelse return false;
    var path_buf: [512]u8 = undefined;
    if (path.len >= path_buf.len) return false;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;
    return c.goonconf_load_file(context, &path_buf);
}

pub fn load_config() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.config/goonwm/config.scm", .{home}) catch return false;
    return load_file(path);
}

fn register_functions() void {
    const context = ctx orelse return;
    c.goonconf_register(context, "set-terminal!", gc_set_terminal);
    c.goonconf_register(context, "set-font!", gc_set_font);
    c.goonconf_register(context, "set-tags!", gc_set_tags);
    c.goonconf_register(context, "border-width!", gc_border_width);
    c.goonconf_register(context, "border-focused!", gc_border_focused);
    c.goonconf_register(context, "border-unfocused!", gc_border_unfocused);
    c.goonconf_register(context, "gaps-inner!", gc_gaps_inner);
    c.goonconf_register(context, "gaps-outer!", gc_gaps_outer);
    c.goonconf_register(context, "bind", gc_bind);
    c.goonconf_register(context, "button", gc_button);
    c.goonconf_register(context, "rule", gc_rule);
    c.goonconf_register(context, "block-static", gc_block_static);
    c.goonconf_register(context, "block-datetime", gc_block_datetime);
    c.goonconf_register(context, "block-ram", gc_block_ram);
    c.goonconf_register(context, "block-shell", gc_block_shell);
    c.goonconf_register(context, "block-battery", gc_block_battery);
    c.goonconf_register(context, "spawn", gc_spawn);
    c.goonconf_register(context, "spawn-terminal", gc_spawn_terminal);
    c.goonconf_register(context, "kill-client", gc_kill_client);
    c.goonconf_register(context, "quit", gc_quit);
    c.goonconf_register(context, "focus-next", gc_focus_next);
    c.goonconf_register(context, "focus-prev", gc_focus_prev);
    c.goonconf_register(context, "move-next", gc_move_next);
    c.goonconf_register(context, "move-prev", gc_move_prev);
    c.goonconf_register(context, "resize-master", gc_resize_master);
    c.goonconf_register(context, "inc-master", gc_inc_master);
    c.goonconf_register(context, "dec-master", gc_dec_master);
    c.goonconf_register(context, "toggle-floating", gc_toggle_floating);
    c.goonconf_register(context, "toggle-fullscreen", gc_toggle_fullscreen);
    c.goonconf_register(context, "toggle-gaps", gc_toggle_gaps);
    c.goonconf_register(context, "cycle-layout", gc_cycle_layout);
    c.goonconf_register(context, "set-layout-tiling", gc_set_layout_tiling);
    c.goonconf_register(context, "set-layout-floating", gc_set_layout_floating);
    c.goonconf_register(context, "view-tag", gc_view_tag);
    c.goonconf_register(context, "move-to-tag", gc_move_to_tag);
    c.goonconf_register(context, "toggle-view-tag", gc_toggle_view_tag);
    c.goonconf_register(context, "toggle-tag", gc_toggle_tag);
    c.goonconf_register(context, "focus-monitor", gc_focus_monitor);
    c.goonconf_register(context, "send-to-monitor", gc_send_to_monitor);
    c.goonconf_register(context, "reload-config", gc_reload_config);
    c.goonconf_register(context, "auto-tile!", gc_auto_tile);
    c.goonconf_register(context, "layout-tile-symbol!", gc_layout_tile_symbol);
    c.goonconf_register(context, "layout-monocle-symbol!", gc_layout_monocle_symbol);
    c.goonconf_register(context, "layout-floating-symbol!", gc_layout_floating_symbol);
}

fn get_string(val: ?*c.goonconf_value_t) ?[]const u8 {
    if (!c.goonconf_is_string(val)) return null;
    const cstr = c.goonconf_to_string(val);
    if (cstr == null) return null;
    return std.mem.sliceTo(cstr, 0);
}

fn get_int(val: ?*c.goonconf_value_t) ?i64 {
    if (!c.goonconf_is_int(val)) return null;
    return c.goonconf_to_int(val);
}

fn get_bool(val: ?*c.goonconf_value_t, default: bool) bool {
    if (c.goonconf_is_bool(val)) {
        return c.goonconf_to_bool(val);
    }
    return default;
}

fn parse_color(val: ?*c.goonconf_value_t) ?u32 {
    if (c.goonconf_is_int(val)) {
        return @intCast(c.goonconf_to_int(val));
    }
    if (c.goonconf_is_string(val)) {
        const str = get_string(val) orelse return null;
        if (str.len > 0 and str[0] == '#') {
            return std.fmt.parseInt(u32, str[1..], 16) catch return null;
        }
        return std.fmt.parseInt(u32, str, 16) catch return null;
    }
    return null;
}

fn parse_modifiers(mods_list: ?*c.goonconf_value_t) u32 {
    var mod_mask: u32 = 0;
    var current = mods_list;
    while (c.goonconf_is_pair(current)) {
        const mod_sym = c.goonconf_car(current);
        if (c.goonconf_is_symbol(mod_sym)) {
            const name = get_string_from_symbol(mod_sym);
            if (name) |n| {
                if (std.mem.eql(u8, n, "mod4") or std.mem.eql(u8, n, "super")) {
                    mod_mask |= (1 << 6);
                } else if (std.mem.eql(u8, n, "mod1") or std.mem.eql(u8, n, "alt")) {
                    mod_mask |= (1 << 3);
                } else if (std.mem.eql(u8, n, "shift")) {
                    mod_mask |= (1 << 0);
                } else if (std.mem.eql(u8, n, "control") or std.mem.eql(u8, n, "ctrl")) {
                    mod_mask |= (1 << 2);
                }
            }
        }
        current = c.goonconf_cdr(current);
    }
    return mod_mask;
}

fn get_string_from_symbol(val: ?*c.goonconf_value_t) ?[]const u8 {
    if (!c.goonconf_is_symbol(val)) return null;
    const cstr = c.goonconf_to_symbol(val);
    if (cstr == null) return null;
    return std.mem.sliceTo(cstr, 0);
}

fn key_name_to_keysym(name: []const u8) ?u64 {
    const key_map = .{
        .{ "Return", 0xff0d },
        .{ "Enter", 0xff0d },
        .{ "Tab", 0xff09 },
        .{ "Escape", 0xff1b },
        .{ "BackSpace", 0xff08 },
        .{ "Delete", 0xffff },
        .{ "space", 0x0020 },
        .{ "Space", 0x0020 },
        .{ "comma", 0x002c },
        .{ "Comma", 0x002c },
        .{ "period", 0x002e },
        .{ "Period", 0x002e },
        .{ "slash", 0x002f },
        .{ "Slash", 0x002f },
        .{ "Left", 0xff51 },
        .{ "Up", 0xff52 },
        .{ "Right", 0xff53 },
        .{ "Down", 0xff54 },
    };
    inline for (key_map) |entry| {
        if (std.mem.eql(u8, name, entry[0])) {
            return entry[1];
        }
    }
    if (name.len == 1) {
        const char = name[0];
        if (char >= 'a' and char <= 'z') {
            return char;
        }
        if (char >= 'A' and char <= 'Z') {
            return char + 32;
        }
        if (char >= '0' and char <= '9') {
            return char;
        }
    }
    return null;
}

fn gc_set_terminal(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const term = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.terminal = term;
    return c.goonconf_nil(context);
}

fn gc_set_font(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const font = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.font = font;
    return c.goonconf_nil(context);
}

fn gc_set_tags(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    var tags_list = c.goonconf_car(args);
    var index: usize = 0;
    while (c.goonconf_is_pair(tags_list) and index < 9) {
        const tag = get_string(c.goonconf_car(tags_list));
        if (tag) |tag_str| {
            cfg.tags[index] = tag_str;
        }
        tags_list = c.goonconf_cdr(tags_list);
        index += 1;
    }
    return c.goonconf_nil(context);
}

fn gc_border_width(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const width = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.border_width = @intCast(width);
    return c.goonconf_nil(context);
}

fn gc_border_focused(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.border_focused = color;
    return c.goonconf_nil(context);
}

fn gc_border_unfocused(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.border_unfocused = color;
    return c.goonconf_nil(context);
}

fn gc_gaps_inner(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const horiz = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const vert = get_int(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    cfg.gap_inner_h = @intCast(horiz);
    cfg.gap_inner_v = @intCast(vert);
    return c.goonconf_nil(context);
}

fn gc_gaps_outer(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const horiz = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const vert = get_int(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    cfg.gap_outer_h = @intCast(horiz);
    cfg.gap_outer_v = @intCast(vert);
    return c.goonconf_nil(context);
}

fn gc_bind(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const mods_list = c.goonconf_car(args);
    const key_str = get_string(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const action_obj = c.goonconf_list_nth(args, 2);

    const mod_mask = parse_modifiers(mods_list);
    const keysym = key_name_to_keysym(key_str) orelse return c.goonconf_nil(context);

    var action: Action = .spawn;
    var int_arg: i32 = 0;
    var str_arg: ?[]const u8 = null;

    if (c.goonconf_is_pair(action_obj)) {
        const action_name = c.goonconf_car(action_obj);
        if (c.goonconf_is_symbol(action_name)) {
            const name = get_string_from_symbol(action_name);
            if (name) |n| {
                if (std.mem.eql(u8, n, "spawn")) {
                    action = .spawn;
                    str_arg = get_string(c.goonconf_list_nth(action_obj, 1));
                } else if (std.mem.eql(u8, n, "view-tag")) {
                    action = .view_tag;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "move-to-tag")) {
                    action = .move_to_tag;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "toggle-view-tag")) {
                    action = .toggle_view_tag;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "toggle-tag")) {
                    action = .toggle_tag;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "resize-master")) {
                    action = .resize_master;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "focus-monitor")) {
                    action = .focus_monitor;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                } else if (std.mem.eql(u8, n, "send-to-monitor")) {
                    action = .send_to_monitor;
                    int_arg = @intCast(get_int(c.goonconf_list_nth(action_obj, 1)) orelse 0);
                }
            }
        }
    } else if (c.goonconf_is_symbol(action_obj)) {
        const name = get_string_from_symbol(action_obj);
        if (name) |n| {
            action = parse_simple_action(n) orelse return c.goonconf_nil(context);
        }
    }

    cfg.add_keybind(.{
        .mod_mask = mod_mask,
        .keysym = keysym,
        .action = action,
        .int_arg = int_arg,
        .str_arg = str_arg,
    }) catch return c.goonconf_nil(context);

    return c.goonconf_nil(context);
}

fn gc_button(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);

    const click_sym = c.goonconf_list_nth(args, 0);
    const mods_list = c.goonconf_list_nth(args, 1);
    const button_sym = c.goonconf_list_nth(args, 2);
    const action_sym = c.goonconf_list_nth(args, 3);

    const click_str = get_string_from_symbol(click_sym) orelse return c.goonconf_nil(context);
    const button_str = get_string_from_symbol(button_sym) orelse return c.goonconf_nil(context);
    const action_str = get_string_from_symbol(action_sym) orelse return c.goonconf_nil(context);

    const click: ClickTarget = if (std.mem.eql(u8, click_str, "client-win"))
        .client_win
    else if (std.mem.eql(u8, click_str, "root-win"))
        .root_win
    else if (std.mem.eql(u8, click_str, "tag-bar"))
        .tag_bar
    else
        return c.goonconf_nil(context);

    const mod_mask = parse_modifiers(mods_list);

    const button: u32 = if (std.mem.eql(u8, button_str, "button1"))
        1
    else if (std.mem.eql(u8, button_str, "button2"))
        2
    else if (std.mem.eql(u8, button_str, "button3"))
        3
    else if (std.mem.eql(u8, button_str, "button4"))
        4
    else if (std.mem.eql(u8, button_str, "button5"))
        5
    else
        return c.goonconf_nil(context);

    const action: MouseAction = if (std.mem.eql(u8, action_str, "move-mouse"))
        .move_mouse
    else if (std.mem.eql(u8, action_str, "resize-mouse"))
        .resize_mouse
    else if (std.mem.eql(u8, action_str, "toggle-floating"))
        .toggle_floating
    else
        return c.goonconf_nil(context);

    cfg.add_button(.{
        .click = click,
        .mod_mask = mod_mask,
        .button = button,
        .action = action,
    }) catch return c.goonconf_nil(context);

    return c.goonconf_nil(context);
}

fn parse_simple_action(name: []const u8) ?Action {
    const action_map = .{
        .{ "spawn-terminal", Action.spawn_terminal },
        .{ "kill-client", Action.kill_client },
        .{ "quit", Action.quit },
        .{ "focus-next", Action.focus_next },
        .{ "focus-prev", Action.focus_prev },
        .{ "move-next", Action.move_next },
        .{ "move-prev", Action.move_prev },
        .{ "inc-master", Action.inc_master },
        .{ "dec-master", Action.dec_master },
        .{ "toggle-floating", Action.toggle_floating },
        .{ "toggle-fullscreen", Action.toggle_fullscreen },
        .{ "toggle-gaps", Action.toggle_gaps },
        .{ "cycle-layout", Action.cycle_layout },
        .{ "set-layout-tiling", Action.set_layout_tiling },
        .{ "set-layout-floating", Action.set_layout_floating },
        .{ "reload-config", Action.reload_config },
    };
    inline for (action_map) |entry| {
        if (std.mem.eql(u8, name, entry[0])) {
            return entry[1];
        }
    }
    return null;
}

fn gc_rule(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    var rule_list = c.goonconf_car(args);

    var rule = Rule{
        .class = null,
        .instance = null,
        .title = null,
        .tags = 0,
        .is_floating = false,
        .monitor = -1,
    };

    while (c.goonconf_is_pair(rule_list)) {
        const pair = c.goonconf_car(rule_list);
        if (c.goonconf_is_pair(pair)) {
            const key = c.goonconf_car(pair);
            const value = c.goonconf_cdr(pair);
            if (c.goonconf_is_symbol(key)) {
                const name = get_string_from_symbol(key);
                if (name) |n| {
                    if (std.mem.eql(u8, n, "class")) {
                        rule.class = get_string(value);
                    } else if (std.mem.eql(u8, n, "instance")) {
                        rule.instance = get_string(value);
                    } else if (std.mem.eql(u8, n, "title")) {
                        rule.title = get_string(value);
                    } else if (std.mem.eql(u8, n, "tag")) {
                        const tag_num = get_int(value) orelse 0;
                        rule.tags = @as(u32, 1) << @intCast(tag_num);
                    } else if (std.mem.eql(u8, n, "floating")) {
                        rule.is_floating = c.goonconf_to_bool(value);
                    } else if (std.mem.eql(u8, n, "monitor")) {
                        rule.monitor = @intCast(get_int(value) orelse -1);
                    }
                }
            }
        }
        rule_list = c.goonconf_cdr(rule_list);
    }

    cfg.add_rule(rule) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_block_static(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const text = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const underline = get_bool(c.goonconf_list_nth(args, 2), true);
    cfg.add_block(.{
        .block_type = .static,
        .format = text,
        .interval = 0,
        .color = color,
        .underline = underline,
    }) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_block_datetime(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const format = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const datetime_format = get_string(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const interval = get_int(c.goonconf_list_nth(args, 2)) orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_list_nth(args, 3)) orelse return c.goonconf_nil(context);
    const underline = get_bool(c.goonconf_list_nth(args, 4), true);
    cfg.add_block(.{
        .block_type = .datetime,
        .format = format,
        .datetime_format = datetime_format,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_block_ram(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const format = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const interval = get_int(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_list_nth(args, 2)) orelse return c.goonconf_nil(context);
    const underline = get_bool(c.goonconf_list_nth(args, 3), true);
    cfg.add_block(.{
        .block_type = .ram,
        .format = format,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_block_shell(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const format = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const command = get_string(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const interval = get_int(c.goonconf_list_nth(args, 2)) orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_list_nth(args, 3)) orelse return c.goonconf_nil(context);
    const underline = get_bool(c.goonconf_list_nth(args, 4), true);
    cfg.add_block(.{
        .block_type = .shell,
        .format = format,
        .command = command,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_block_battery(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const format_charging = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const format_discharging = get_string(c.goonconf_list_nth(args, 1)) orelse return c.goonconf_nil(context);
    const format_full = get_string(c.goonconf_list_nth(args, 2)) orelse return c.goonconf_nil(context);
    const battery_name = get_string(c.goonconf_list_nth(args, 3)) orelse return c.goonconf_nil(context);
    const interval = get_int(c.goonconf_list_nth(args, 4)) orelse return c.goonconf_nil(context);
    const color = parse_color(c.goonconf_list_nth(args, 5)) orelse return c.goonconf_nil(context);
    const underline = get_bool(c.goonconf_list_nth(args, 6), true);
    cfg.add_block(.{
        .block_type = .battery,
        .format = format_charging,
        .format_charging = format_charging,
        .format_discharging = format_discharging,
        .format_full = format_full,
        .battery_name = battery_name,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return c.goonconf_nil(context);
    return c.goonconf_nil(context);
}

fn gc_spawn(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cmd = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    const result = c.goonconf_cons(context, c.goonconf_symbol(context, "spawn"), c.goonconf_cons(context, c.goonconf_string(context, cmd.ptr), c.goonconf_nil(context)));
    return result;
}

fn gc_spawn_terminal(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "spawn-terminal");
}

fn gc_kill_client(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "kill-client");
}

fn gc_quit(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "quit");
}

fn gc_focus_next(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "focus-next");
}

fn gc_focus_prev(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "focus-prev");
}

fn gc_move_next(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "move-next");
}

fn gc_move_prev(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "move-prev");
}

fn gc_resize_master(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const delta = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "resize-master"), c.goonconf_cons(context, c.goonconf_int(context, delta), c.goonconf_nil(context)));
}

fn gc_inc_master(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "inc-master");
}

fn gc_dec_master(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "dec-master");
}

fn gc_toggle_floating(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "toggle-floating");
}

fn gc_toggle_fullscreen(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "toggle-fullscreen");
}

fn gc_toggle_gaps(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "toggle-gaps");
}

fn gc_cycle_layout(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "cycle-layout");
}

fn gc_set_layout_tiling(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "set-layout-tiling");
}

fn gc_set_layout_floating(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "set-layout-floating");
}

fn gc_view_tag(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const tag = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "view-tag"), c.goonconf_cons(context, c.goonconf_int(context, tag), c.goonconf_nil(context)));
}

fn gc_move_to_tag(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const tag = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "move-to-tag"), c.goonconf_cons(context, c.goonconf_int(context, tag), c.goonconf_nil(context)));
}

fn gc_toggle_view_tag(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const tag = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "toggle-view-tag"), c.goonconf_cons(context, c.goonconf_int(context, tag), c.goonconf_nil(context)));
}

fn gc_toggle_tag(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const tag = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "toggle-tag"), c.goonconf_cons(context, c.goonconf_int(context, tag), c.goonconf_nil(context)));
}

fn gc_focus_monitor(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const dir = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "focus-monitor"), c.goonconf_cons(context, c.goonconf_int(context, dir), c.goonconf_nil(context)));
}

fn gc_send_to_monitor(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const dir = get_int(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    return c.goonconf_cons(context, c.goonconf_symbol(context, "send-to-monitor"), c.goonconf_cons(context, c.goonconf_int(context, dir), c.goonconf_nil(context)));
}

fn gc_reload_config(context: ?*c.goonconf_ctx_t, _: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    return c.goonconf_symbol(context, "reload-config");
}

fn gc_auto_tile(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    cfg.auto_tile = get_bool(c.goonconf_car(args), false);
    return c.goonconf_nil(context);
}

fn gc_layout_tile_symbol(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const symbol = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.layout_tile_symbol = symbol;
    return c.goonconf_nil(context);
}

fn gc_layout_monocle_symbol(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const symbol = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.layout_monocle_symbol = symbol;
    return c.goonconf_nil(context);
}

fn gc_layout_floating_symbol(context: ?*c.goonconf_ctx_t, args: ?*c.goonconf_value_t) callconv(.c) ?*c.goonconf_value_t {
    const cfg = config orelse return c.goonconf_nil(context);
    const symbol = get_string(c.goonconf_car(args)) orelse return c.goonconf_nil(context);
    cfg.layout_floating_symbol = symbol;
    return c.goonconf_nil(context);
}
