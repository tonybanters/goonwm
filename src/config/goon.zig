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
const ColorScheme = config_mod.ColorScheme;

const c = @cImport({
    @cInclude("goon.h");
});

var ctx: ?*c.Goon_Ctx = null;
var config: ?*Config = null;

pub fn init(cfg: *Config) bool {
    config = cfg;
    ctx = c.goon_create();
    if (ctx == null) {
        return false;
    }
    register_builtins();
    return true;
}

pub fn deinit() void {
    if (ctx) |context| {
        c.goon_destroy(context);
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
    if (!c.goon_load_file(context, &path_buf)) {
        return false;
    }
    const result = c.goon_eval_result(context);
    if (result != null and c.goon_is_record(result)) {
        apply_config(result);
    }
    return true;
}

pub fn load_config() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/.config/goonwm/config.goon", .{home}) catch return false;
    return load_file(path);
}

fn register_builtins() void {
    const context = ctx orelse return;
    c.goon_register(context, "tag_binds", builtin_tag_binds);
}

fn builtin_tag_binds(context: ?*c.Goon_Ctx, args: [*c]?*c.Goon_Value, argc: usize) callconv(.c) ?*c.Goon_Value {
    if (argc < 4) return c.goon_list(context);

    const mods = args[0];
    const action_str = get_string(args[1]);
    const start = c.goon_to_int(args[2]);
    const end = c.goon_to_int(args[3]);

    if (action_str == null) return c.goon_list(context);

    const result = c.goon_list(context);

    var i = start;
    while (i <= end) : (i += 1) {
        const binding = c.goon_record(context);

        c.goon_record_set(context, binding, "mod", mods);

        var key_buf: [2]u8 = undefined;
        key_buf[0] = @intCast(@mod(i, 10) + '0');
        key_buf[1] = 0;
        c.goon_record_set(context, binding, "key", c.goon_string(context, &key_buf));

        c.goon_record_set(context, binding, "action", c.goon_string(context, action_str.?.ptr));
        c.goon_record_set(context, binding, "arg", c.goon_int(context, i - 1));

        c.goon_list_push(context, result, binding);
    }

    return result;
}

fn get_string(val: ?*c.Goon_Value) ?[]const u8 {
    if (!c.goon_is_string(val)) return null;
    const cstr = c.goon_to_string(val);
    if (cstr == null) return null;
    return std.mem.sliceTo(cstr, 0);
}

fn get_int(val: ?*c.Goon_Value) ?i64 {
    if (!c.goon_is_int(val)) return null;
    return c.goon_to_int(val);
}

fn get_bool(val: ?*c.Goon_Value) ?bool {
    if (!c.goon_is_bool(val)) return null;
    return c.goon_to_bool(val);
}

fn parse_color(val: ?*c.Goon_Value) ?u32 {
    if (c.goon_is_int(val)) {
        return @intCast(c.goon_to_int(val));
    }
    if (c.goon_is_string(val)) {
        const str = get_string(val) orelse return null;
        if (str.len > 0 and str[0] == '#') {
            return std.fmt.parseInt(u32, str[1..], 16) catch return null;
        }
        return std.fmt.parseInt(u32, str, 16) catch return null;
    }
    return null;
}

fn parse_modifiers(mods_list: ?*c.Goon_Value) u32 {
    var mod_mask: u32 = 0;
    if (!c.goon_is_list(mods_list)) return mod_mask;

    const len = c.goon_list_len(mods_list);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const mod_val = c.goon_list_get(mods_list, i);
        const name = get_string(mod_val) orelse continue;

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

fn parse_action(name: []const u8) ?Action {
    const action_map = .{
        .{ "spawn-terminal", Action.spawn_terminal },
        .{ "spawn", Action.spawn },
        .{ "kill-client", Action.kill_client },
        .{ "quit", Action.quit },
        .{ "reload-config", Action.reload_config },
        .{ "focus-next", Action.focus_next },
        .{ "focus-prev", Action.focus_prev },
        .{ "move-next", Action.move_next },
        .{ "move-prev", Action.move_prev },
        .{ "resize-master", Action.resize_master },
        .{ "inc-master", Action.inc_master },
        .{ "dec-master", Action.dec_master },
        .{ "toggle-floating", Action.toggle_floating },
        .{ "toggle-fullscreen", Action.toggle_fullscreen },
        .{ "toggle-gaps", Action.toggle_gaps },
        .{ "cycle-layout", Action.cycle_layout },
        .{ "set-layout-tiling", Action.set_layout_tiling },
        .{ "set-layout-floating", Action.set_layout_floating },
        .{ "view-tag", Action.view_tag },
        .{ "move-to-tag", Action.move_to_tag },
        .{ "toggle-view-tag", Action.toggle_view_tag },
        .{ "toggle-tag", Action.toggle_tag },
        .{ "focus-monitor", Action.focus_monitor },
        .{ "send-to-monitor", Action.send_to_monitor },
    };
    inline for (action_map) |entry| {
        if (std.mem.eql(u8, name, entry[0])) {
            return entry[1];
        }
    }
    return null;
}

fn apply_config(root: ?*c.Goon_Value) void {
    const cfg = config orelse return;
    if (root == null or !c.goon_is_record(root)) return;

    if (get_string(c.goon_record_get(root, "terminal"))) |term| {
        cfg.terminal = term;
    }

    if (get_string(c.goon_record_get(root, "font"))) |font| {
        cfg.font = font;
    }

    const tags_list = c.goon_record_get(root, "tags");
    if (c.goon_is_list(tags_list)) {
        const len = c.goon_list_len(tags_list);
        var i: usize = 0;
        while (i < len and i < 9) : (i += 1) {
            if (get_string(c.goon_list_get(tags_list, i))) |tag_str| {
                cfg.tags[i] = tag_str;
            }
        }
    }

    const border_rec = c.goon_record_get(root, "border");
    if (c.goon_is_record(border_rec)) {
        if (get_int(c.goon_record_get(border_rec, "width"))) |w| {
            cfg.border_width = @intCast(w);
        }
        if (parse_color(c.goon_record_get(border_rec, "focused"))) |col| {
            cfg.border_focused = col;
        }
        if (parse_color(c.goon_record_get(border_rec, "unfocused"))) |col| {
            cfg.border_unfocused = col;
        }
    }

    const gaps_rec = c.goon_record_get(root, "gaps");
    if (c.goon_is_record(gaps_rec)) {
        const inner = c.goon_record_get(gaps_rec, "inner");
        if (c.goon_is_list(inner) and c.goon_list_len(inner) >= 2) {
            if (get_int(c.goon_list_get(inner, 0))) |h| {
                cfg.gap_inner_h = @intCast(h);
            }
            if (get_int(c.goon_list_get(inner, 1))) |v| {
                cfg.gap_inner_v = @intCast(v);
            }
        }
        const outer = c.goon_record_get(gaps_rec, "outer");
        if (c.goon_is_list(outer) and c.goon_list_len(outer) >= 2) {
            if (get_int(c.goon_list_get(outer, 0))) |h| {
                cfg.gap_outer_h = @intCast(h);
            }
            if (get_int(c.goon_list_get(outer, 1))) |v| {
                cfg.gap_outer_v = @intCast(v);
            }
        }
    }

    if (get_bool(c.goon_record_get(root, "auto_tile"))) |at| {
        cfg.auto_tile = at;
    }

    apply_schemes_config(root, cfg);
    apply_bar_config(root, cfg);
    apply_keys_config(root, cfg);
    apply_rules_config(root, cfg);
    apply_buttons_config(root, cfg);
}

fn parse_scheme(rec: ?*c.Goon_Value) ?ColorScheme {
    if (!c.goon_is_record(rec)) return null;
    const fg = parse_color(c.goon_record_get(rec, "fg")) orelse return null;
    const bg = parse_color(c.goon_record_get(rec, "bg")) orelse return null;
    const border = parse_color(c.goon_record_get(rec, "border")) orelse return null;
    return ColorScheme{ .fg = fg, .bg = bg, .border = border };
}

fn apply_schemes_config(root: ?*c.Goon_Value, cfg: *Config) void {
    const schemes_rec = c.goon_record_get(root, "schemes");
    if (!c.goon_is_record(schemes_rec)) return;

    if (parse_scheme(c.goon_record_get(schemes_rec, "normal"))) |s| {
        cfg.scheme_normal = s;
    }
    if (parse_scheme(c.goon_record_get(schemes_rec, "selected"))) |s| {
        cfg.scheme_selected = s;
    }
    if (parse_scheme(c.goon_record_get(schemes_rec, "occupied"))) |s| {
        cfg.scheme_occupied = s;
    }
    if (parse_scheme(c.goon_record_get(schemes_rec, "urgent"))) |s| {
        cfg.scheme_urgent = s;
    }
}

fn apply_bar_config(root: ?*c.Goon_Value, cfg: *Config) void {
    const bar_list = c.goon_record_get(root, "bar");
    if (!c.goon_is_list(bar_list)) return;

    const len = c.goon_list_len(bar_list);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const block_rec = c.goon_list_get(bar_list, i);
        if (!c.goon_is_record(block_rec)) continue;

        const type_str = get_string(c.goon_record_get(block_rec, "type")) orelse continue;
        const color = parse_color(c.goon_record_get(block_rec, "color")) orelse 0xbbbbbb;
        const interval: u32 = @intCast(get_int(c.goon_record_get(block_rec, "interval")) orelse 0);
        const underline = get_bool(c.goon_record_get(block_rec, "underline")) orelse true;

        var block = Block{
            .block_type = .static,
            .format = "",
            .interval = interval,
            .color = color,
            .underline = underline,
        };

        if (std.mem.eql(u8, type_str, "static")) {
            block.block_type = .static;
            block.format = get_string(c.goon_record_get(block_rec, "text")) orelse "";
        } else if (std.mem.eql(u8, type_str, "datetime")) {
            block.block_type = .datetime;
            block.format = get_string(c.goon_record_get(block_rec, "fmt")) orelse "";
            block.datetime_format = get_string(c.goon_record_get(block_rec, "strftime"));
        } else if (std.mem.eql(u8, type_str, "ram")) {
            block.block_type = .ram;
            block.format = get_string(c.goon_record_get(block_rec, "fmt")) orelse "";
        } else if (std.mem.eql(u8, type_str, "shell")) {
            block.block_type = .shell;
            block.format = get_string(c.goon_record_get(block_rec, "fmt")) orelse "";
            block.command = get_string(c.goon_record_get(block_rec, "cmd"));
        } else if (std.mem.eql(u8, type_str, "battery")) {
            block.block_type = .battery;
            block.format = get_string(c.goon_record_get(block_rec, "fmt_charging")) orelse "";
            block.format_charging = get_string(c.goon_record_get(block_rec, "fmt_charging"));
            block.format_discharging = get_string(c.goon_record_get(block_rec, "fmt_discharging"));
            block.format_full = get_string(c.goon_record_get(block_rec, "fmt_full"));
            block.battery_name = get_string(c.goon_record_get(block_rec, "device"));
        } else {
            continue;
        }

        cfg.add_block(block) catch continue;
    }
}

fn apply_keys_config(root: ?*c.Goon_Value, cfg: *Config) void {
    const keys_list = c.goon_record_get(root, "keys");
    if (!c.goon_is_list(keys_list)) return;

    const len = c.goon_list_len(keys_list);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const key_rec = c.goon_list_get(keys_list, i);
        if (!c.goon_is_record(key_rec)) continue;

        const mod_mask = parse_modifiers(c.goon_record_get(key_rec, "mod"));
        const key_str = get_string(c.goon_record_get(key_rec, "key")) orelse continue;
        const action_str = get_string(c.goon_record_get(key_rec, "action")) orelse continue;

        const keysym = key_name_to_keysym(key_str) orelse continue;
        const action = parse_action(action_str) orelse continue;

        var int_arg: i32 = 0;
        var str_arg: ?[]const u8 = null;

        if (get_int(c.goon_record_get(key_rec, "arg"))) |arg| {
            int_arg = @intCast(arg);
        }
        if (get_string(c.goon_record_get(key_rec, "arg"))) |arg| {
            str_arg = arg;
        }

        cfg.add_keybind(.{
            .mod_mask = mod_mask,
            .keysym = keysym,
            .action = action,
            .int_arg = int_arg,
            .str_arg = str_arg,
        }) catch continue;
    }
}

fn apply_rules_config(root: ?*c.Goon_Value, cfg: *Config) void {
    const rules_list = c.goon_record_get(root, "rules");
    if (!c.goon_is_list(rules_list)) return;

    const len = c.goon_list_len(rules_list);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const rule_rec = c.goon_list_get(rules_list, i);
        if (!c.goon_is_record(rule_rec)) continue;

        var rule = Rule{
            .class = null,
            .instance = null,
            .title = null,
            .tags = 0,
            .is_floating = false,
            .monitor = -1,
        };

        rule.class = get_string(c.goon_record_get(rule_rec, "class"));
        rule.instance = get_string(c.goon_record_get(rule_rec, "instance"));
        rule.title = get_string(c.goon_record_get(rule_rec, "title"));

        if (get_int(c.goon_record_get(rule_rec, "tag"))) |tag| {
            rule.tags = @as(u32, 1) << @intCast(tag);
        }

        if (get_bool(c.goon_record_get(rule_rec, "floating"))) |fl| {
            rule.is_floating = fl;
        }

        if (get_int(c.goon_record_get(rule_rec, "monitor"))) |mon| {
            rule.monitor = @intCast(mon);
        }

        cfg.add_rule(rule) catch continue;
    }
}

fn apply_buttons_config(root: ?*c.Goon_Value, cfg: *Config) void {
    const buttons_list = c.goon_record_get(root, "buttons");
    if (!c.goon_is_list(buttons_list)) return;

    const len = c.goon_list_len(buttons_list);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const btn_rec = c.goon_list_get(buttons_list, i);
        if (!c.goon_is_record(btn_rec)) continue;

        const context_str = get_string(c.goon_record_get(btn_rec, "context")) orelse continue;
        const button_str = get_string(c.goon_record_get(btn_rec, "button")) orelse continue;
        const action_str = get_string(c.goon_record_get(btn_rec, "action")) orelse continue;

        const click: ClickTarget = if (std.mem.eql(u8, context_str, "client-win"))
            .client_win
        else if (std.mem.eql(u8, context_str, "root-win"))
            .root_win
        else if (std.mem.eql(u8, context_str, "tag-bar"))
            .tag_bar
        else
            continue;

        const mod_mask = parse_modifiers(c.goon_record_get(btn_rec, "mod"));

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
            continue;

        const action: MouseAction = if (std.mem.eql(u8, action_str, "move-mouse"))
            .move_mouse
        else if (std.mem.eql(u8, action_str, "resize-mouse"))
            .resize_mouse
        else if (std.mem.eql(u8, action_str, "toggle-floating"))
            .toggle_floating
        else
            continue;

        cfg.add_button(.{
            .click = click,
            .mod_mask = mod_mask,
            .button = button,
            .action = action,
        }) catch continue;
    }
}
