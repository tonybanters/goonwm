const std = @import("std");
const config_mod = @import("config.zig");
const Config = config_mod.Config;
const Keybind = config_mod.Keybind;
const Action = config_mod.Action;
const Rule = config_mod.Rule;
const Block = config_mod.Block;
const BlockType = config_mod.BlockType;

const s7 = @cImport({
    @cInclude("s7.h");
});

var scheme: ?*s7.s7_scheme = null;
var config: ?*Config = null;

pub fn init(cfg: *Config) bool {
    config = cfg;
    scheme = s7.s7_init();
    if (scheme == null) {
        return false;
    }
    register_functions();
    return true;
}

pub fn deinit() void {
    if (scheme) |scm| {
        s7.s7_quit(scm);
    }
    scheme = null;
    config = null;
}

pub fn load_file(path: []const u8) bool {
    const scm = scheme orelse return false;
    var path_buf: [512]u8 = undefined;
    if (path.len >= path_buf.len) return false;
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;
    const result = s7.s7_load(scm, &path_buf);
    return result != s7.s7_f(scm);
}

pub fn load_config() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.config/goonwm/config.scm", .{home}) catch return false;
    return load_file(path);
}

fn register_functions() void {
    const scm = scheme orelse return;
    _ = s7.s7_define_function(scm, "set-terminal!", &scm_set_terminal, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "set-font!", &scm_set_font, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "set-tags!", &scm_set_tags, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "border-width!", &scm_border_width, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "border-focused!", &scm_border_focused, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "border-unfocused!", &scm_border_unfocused, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "gaps-inner!", &scm_gaps_inner, 2, 0, false, "");
    _ = s7.s7_define_function(scm, "gaps-outer!", &scm_gaps_outer, 2, 0, false, "");
    _ = s7.s7_define_function(scm, "bind", &scm_bind, 3, 0, false, "");
    _ = s7.s7_define_function(scm, "rule", &scm_rule, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "block-static", &scm_block_static, 2, 1, false, "");
    _ = s7.s7_define_function(scm, "block-datetime", &scm_block_datetime, 4, 1, false, "");
    _ = s7.s7_define_function(scm, "block-ram", &scm_block_ram, 3, 1, false, "");
    _ = s7.s7_define_function(scm, "block-shell", &scm_block_shell, 4, 1, false, "");
    _ = s7.s7_define_function(scm, "block-battery", &scm_block_battery, 6, 1, false, "");
    _ = s7.s7_define_function(scm, "spawn", &scm_spawn, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "spawn-terminal", &scm_spawn_terminal, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "kill-client", &scm_kill_client, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "quit", &scm_quit, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "focus-next", &scm_focus_next, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "focus-prev", &scm_focus_prev, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "move-next", &scm_move_next, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "move-prev", &scm_move_prev, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "resize-master", &scm_resize_master, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "inc-master", &scm_inc_master, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "dec-master", &scm_dec_master, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "toggle-floating", &scm_toggle_floating, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "toggle-fullscreen", &scm_toggle_fullscreen, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "toggle-gaps", &scm_toggle_gaps, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "cycle-layout", &scm_cycle_layout, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "set-layout-tiling", &scm_set_layout_tiling, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "set-layout-floating", &scm_set_layout_floating, 0, 0, false, "");
    _ = s7.s7_define_function(scm, "view-tag", &scm_view_tag, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "move-to-tag", &scm_move_to_tag, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "toggle-view-tag", &scm_toggle_view_tag, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "toggle-tag", &scm_toggle_tag, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "focus-monitor", &scm_focus_monitor, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "send-to-monitor", &scm_send_to_monitor, 1, 0, false, "");
    _ = s7.s7_define_function(scm, "reload-config", &scm_reload_config, 0, 0, false, "");
}

fn get_string(ptr: s7.s7_pointer) ?[]const u8 {
    if (!s7.s7_is_string(ptr)) return null;
    const cstr = s7.s7_string(ptr);
    if (cstr == null) return null;
    return std.mem.sliceTo(cstr, 0);
}

fn get_integer(ptr: s7.s7_pointer) ?i64 {
    if (!s7.s7_is_integer(ptr)) return null;
    return s7.s7_integer(ptr);
}

fn get_bool_or_default(scm: ?*s7.s7_scheme, ptr: s7.s7_pointer, default: bool) bool {
    if (s7.s7_is_boolean(ptr)) {
        return ptr == s7.s7_t(scm);
    }
    return default;
}

fn parse_color(scm: ?*s7.s7_scheme, ptr: s7.s7_pointer) ?u32 {
    if (s7.s7_is_integer(ptr)) {
        return @intCast(s7.s7_integer(ptr));
    }
    if (s7.s7_is_string(ptr)) {
        const str = get_string(ptr) orelse return null;
        _ = scm;
        if (str.len > 0 and str[0] == '#') {
            return std.fmt.parseInt(u32, str[1..], 16) catch return null;
        }
        return std.fmt.parseInt(u32, str, 16) catch return null;
    }
    return null;
}

fn parse_modifiers(mods_list: s7.s7_pointer) u32 {
    var mod_mask: u32 = 0;
    var current = mods_list;
    while (s7.s7_is_pair(current)) {
        const mod_sym = s7.s7_car(current);
        if (s7.s7_is_symbol(mod_sym)) {
            const mod_name = s7.s7_symbol_name(mod_sym);
            if (mod_name != null) {
                const name = std.mem.sliceTo(mod_name, 0);
                if (std.mem.eql(u8, name, "mod4") or std.mem.eql(u8, name, "super")) {
                    mod_mask |= (1 << 6);
                } else if (std.mem.eql(u8, name, "mod1") or std.mem.eql(u8, name, "alt")) {
                    mod_mask |= (1 << 3);
                } else if (std.mem.eql(u8, name, "shift")) {
                    mod_mask |= (1 << 0);
                } else if (std.mem.eql(u8, name, "control") or std.mem.eql(u8, name, "ctrl")) {
                    mod_mask |= (1 << 2);
                }
            }
        }
        current = s7.s7_cdr(current);
    }
    return mod_mask;
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

fn scm_set_terminal(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const term = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    cfg.terminal = term;
    return s7.s7_t(scm);
}

fn scm_set_font(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const font = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    cfg.font = font;
    return s7.s7_t(scm);
}

fn scm_set_tags(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    var tags_list = s7.s7_car(args);
    var index: usize = 0;
    while (s7.s7_is_pair(tags_list) and index < 9) {
        const tag = get_string(s7.s7_car(tags_list));
        if (tag) |tag_str| {
            cfg.tags[index] = tag_str;
        }
        tags_list = s7.s7_cdr(tags_list);
        index += 1;
    }
    return s7.s7_t(scm);
}

fn scm_border_width(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const width = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    cfg.border_width = @intCast(width);
    return s7.s7_t(scm);
}

fn scm_border_focused(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_car(args)) orelse return s7.s7_f(scm);
    cfg.border_focused = color;
    return s7.s7_t(scm);
}

fn scm_border_unfocused(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_car(args)) orelse return s7.s7_f(scm);
    cfg.border_unfocused = color;
    return s7.s7_t(scm);
}

fn scm_gaps_inner(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const horiz = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const vert = get_integer(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    cfg.gap_inner_h = @intCast(horiz);
    cfg.gap_inner_v = @intCast(vert);
    return s7.s7_t(scm);
}

fn scm_gaps_outer(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const horiz = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const vert = get_integer(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    cfg.gap_outer_h = @intCast(horiz);
    cfg.gap_outer_v = @intCast(vert);
    return s7.s7_t(scm);
}

fn scm_bind(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const mods_list = s7.s7_car(args);
    const key_str = get_string(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const action_obj = s7.s7_caddr(args);

    const mod_mask = parse_modifiers(mods_list);
    const keysym = key_name_to_keysym(key_str) orelse return s7.s7_f(scm);

    var action: Action = .spawn;
    var int_arg: i32 = 0;
    var str_arg: ?[]const u8 = null;

    if (s7.s7_is_pair(action_obj)) {
        const action_name = s7.s7_car(action_obj);
        if (s7.s7_is_symbol(action_name)) {
            const name_ptr = s7.s7_symbol_name(action_name);
            if (name_ptr != null) {
                const name = std.mem.sliceTo(name_ptr, 0);
                if (std.mem.eql(u8, name, "spawn")) {
                    action = .spawn;
                    str_arg = get_string(s7.s7_cadr(action_obj));
                } else if (std.mem.eql(u8, name, "view-tag")) {
                    action = .view_tag;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "move-to-tag")) {
                    action = .move_to_tag;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "toggle-view-tag")) {
                    action = .toggle_view_tag;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "toggle-tag")) {
                    action = .toggle_tag;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "resize-master")) {
                    action = .resize_master;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "focus-monitor")) {
                    action = .focus_monitor;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                } else if (std.mem.eql(u8, name, "send-to-monitor")) {
                    action = .send_to_monitor;
                    int_arg = @intCast(get_integer(s7.s7_cadr(action_obj)) orelse 0);
                }
            }
        }
    } else if (s7.s7_is_symbol(action_obj)) {
        const name_ptr = s7.s7_symbol_name(action_obj);
        if (name_ptr != null) {
            const name = std.mem.sliceTo(name_ptr, 0);
            action = parse_simple_action(name) orelse return s7.s7_f(scm);
        }
    }

    cfg.add_keybind(.{
        .mod_mask = mod_mask,
        .keysym = keysym,
        .action = action,
        .int_arg = int_arg,
        .str_arg = str_arg,
    }) catch return s7.s7_f(scm);

    return s7.s7_t(scm);
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

fn scm_rule(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    var rule_list = s7.s7_car(args);

    var rule = Rule{
        .class = null,
        .instance = null,
        .title = null,
        .tags = 0,
        .is_floating = false,
        .monitor = -1,
    };

    while (s7.s7_is_pair(rule_list)) {
        const pair = s7.s7_car(rule_list);
        if (s7.s7_is_pair(pair)) {
            const key = s7.s7_car(pair);
            const value = s7.s7_cdr(pair);
            if (s7.s7_is_symbol(key)) {
                const key_name = s7.s7_symbol_name(key);
                if (key_name != null) {
                    const name = std.mem.sliceTo(key_name, 0);
                    if (std.mem.eql(u8, name, "class")) {
                        rule.class = get_string(value);
                    } else if (std.mem.eql(u8, name, "instance")) {
                        rule.instance = get_string(value);
                    } else if (std.mem.eql(u8, name, "title")) {
                        rule.title = get_string(value);
                    } else if (std.mem.eql(u8, name, "tag")) {
                        const tag_num = get_integer(value) orelse 0;
                        rule.tags = @as(u32, 1) << @intCast(tag_num);
                    } else if (std.mem.eql(u8, name, "floating")) {
                        rule.is_floating = s7.s7_boolean(scm, value);
                    } else if (std.mem.eql(u8, name, "monitor")) {
                        rule.monitor = @intCast(get_integer(value) orelse -1);
                    }
                }
            }
        }
        rule_list = s7.s7_cdr(rule_list);
    }

    cfg.add_rule(rule) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_block_static(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const text = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const rest = s7.s7_cddr(args);
    const underline = get_bool_or_default(scm, s7.s7_car(rest), true);
    cfg.add_block(.{
        .block_type = .static,
        .format = text,
        .interval = 0,
        .color = color,
        .underline = underline,
    }) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_block_datetime(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const format = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const datetime_format = get_string(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const interval = get_integer(s7.s7_caddr(args)) orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_cadddr(args)) orelse return s7.s7_f(scm);
    const rest = s7.s7_cddddr(args);
    const underline = get_bool_or_default(scm, s7.s7_car(rest), true);
    cfg.add_block(.{
        .block_type = .datetime,
        .format = format,
        .datetime_format = datetime_format,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_block_ram(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const format = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const interval = get_integer(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_caddr(args)) orelse return s7.s7_f(scm);
    const rest = s7.s7_cdddr(args);
    const underline = get_bool_or_default(scm, s7.s7_car(rest), true);
    cfg.add_block(.{
        .block_type = .ram,
        .format = format,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_block_shell(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const format = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const command = get_string(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const interval = get_integer(s7.s7_caddr(args)) orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_cadddr(args)) orelse return s7.s7_f(scm);
    const rest = s7.s7_cddddr(args);
    const underline = get_bool_or_default(scm, s7.s7_car(rest), true);
    cfg.add_block(.{
        .block_type = .shell,
        .format = format,
        .command = command,
        .interval = @intCast(interval),
        .color = color,
        .underline = underline,
    }) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_block_battery(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cfg = config orelse return s7.s7_f(scm);
    const format_charging = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    const format_discharging = get_string(s7.s7_cadr(args)) orelse return s7.s7_f(scm);
    const format_full = get_string(s7.s7_caddr(args)) orelse return s7.s7_f(scm);
    const battery_name = get_string(s7.s7_cadddr(args)) orelse return s7.s7_f(scm);
    const rest = s7.s7_cddddr(args);
    const interval = get_integer(s7.s7_car(rest)) orelse return s7.s7_f(scm);
    const color = parse_color(scm, s7.s7_cadr(rest)) orelse return s7.s7_f(scm);
    const rest2 = s7.s7_cddr(rest);
    const underline = get_bool_or_default(scm, s7.s7_car(rest2), true);
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
    }) catch return s7.s7_f(scm);
    return s7.s7_t(scm);
}

fn scm_spawn(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const cmd = get_string(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "spawn"), s7.s7_make_string(scm, cmd.ptr));
}

fn scm_spawn_terminal(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "spawn-terminal");
}

fn scm_kill_client(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "kill-client");
}

fn scm_quit(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "quit");
}

fn scm_focus_next(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "focus-next");
}

fn scm_focus_prev(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "focus-prev");
}

fn scm_move_next(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "move-next");
}

fn scm_move_prev(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "move-prev");
}

fn scm_resize_master(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const delta = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "resize-master"), s7.s7_make_integer(scm, delta));
}

fn scm_inc_master(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "inc-master");
}

fn scm_dec_master(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "dec-master");
}

fn scm_toggle_floating(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "toggle-floating");
}

fn scm_toggle_fullscreen(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "toggle-fullscreen");
}

fn scm_toggle_gaps(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "toggle-gaps");
}

fn scm_cycle_layout(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "cycle-layout");
}

fn scm_set_layout_tiling(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "set-layout-tiling");
}

fn scm_set_layout_floating(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "set-layout-floating");
}

fn scm_view_tag(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const tag = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "view-tag"), s7.s7_make_integer(scm, tag));
}

fn scm_move_to_tag(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const tag = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "move-to-tag"), s7.s7_make_integer(scm, tag));
}

fn scm_toggle_view_tag(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const tag = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "toggle-view-tag"), s7.s7_make_integer(scm, tag));
}

fn scm_toggle_tag(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const tag = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "toggle-tag"), s7.s7_make_integer(scm, tag));
}

fn scm_focus_monitor(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const dir = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "focus-monitor"), s7.s7_make_integer(scm, dir));
}

fn scm_send_to_monitor(scm: ?*s7.s7_scheme, args: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    const dir = get_integer(s7.s7_car(args)) orelse return s7.s7_f(scm);
    return s7.s7_list(scm, 2, s7.s7_make_symbol(scm, "send-to-monitor"), s7.s7_make_integer(scm, dir));
}

fn scm_reload_config(scm: ?*s7.s7_scheme, _: s7.s7_pointer) callconv(.c) s7.s7_pointer {
    return s7.s7_make_symbol(scm, "reload-config");
}
