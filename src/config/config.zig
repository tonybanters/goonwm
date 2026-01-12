const std = @import("std");

pub const Action = enum {
    spawn_terminal,
    spawn,
    kill_client,
    quit,
    reload_config,
    restart,
    focus_next,
    focus_prev,
    move_next,
    move_prev,
    resize_master,
    inc_master,
    dec_master,
    toggle_floating,
    toggle_fullscreen,
    toggle_gaps,
    cycle_layout,
    set_layout_tiling,
    set_layout_floating,
    view_tag,
    move_to_tag,
    toggle_view_tag,
    toggle_tag,
    focus_monitor,
    send_to_monitor,
    volume_up,
    volume_down,
    volume_mute,
};

pub const Keybind = struct {
    mod_mask: u32,
    keysym: u64,
    action: Action,
    int_arg: i32 = 0,
    str_arg: ?[]const u8 = null,
};

pub const Rule = struct {
    class: ?[]const u8,
    instance: ?[]const u8,
    title: ?[]const u8,
    tags: u32,
    is_floating: bool,
    monitor: i32,
};

pub const Block_Type = enum {
    static,
    datetime,
    ram,
    shell,
    battery,
    cpu_temp,
    pulseaudio,
};

pub const ClickTarget = enum {
    client_win,
    root_win,
    tag_bar,
};

pub const MouseAction = enum {
    move_mouse,
    resize_mouse,
    toggle_floating,
};

pub const MouseButton = struct {
    click: ClickTarget,
    mod_mask: u32,
    button: u32,
    action: MouseAction,
};

pub const Block = struct {
    block_type: Block_Type,
    format: []const u8,
    command: ?[]const u8 = null,
    interval: u32,
    color: u32,
    underline: bool = true,
    datetime_format: ?[]const u8 = null,
    format_charging: ?[]const u8 = null,
    format_discharging: ?[]const u8 = null,
    format_full: ?[]const u8 = null,
    battery_name: ?[]const u8 = null,
    thermal_zone: ?[]const u8 = null,
    format_muted: ?[]const u8 = null,
    format_low: ?[]const u8 = null,
    format_medium: ?[]const u8 = null,
    format_high: ?[]const u8 = null,
    mixer_name: ?[]const u8 = null,
};

pub const ColorScheme = struct {
    fg: u32 = 0xbbbbbb,
    bg: u32 = 0x1a1b26,
    border: u32 = 0x444444,
};

pub const Config = struct {
    allocator: std.mem.Allocator,

    terminal: []const u8 = "st",
    font: []const u8 = "monospace:size=10",
    tags: [9][]const u8 = .{ "1", "2", "3", "4", "5", "6", "7", "8", "9" },

    border_width: i32 = 2,
    border_focused: u32 = 0x6dade3,
    border_unfocused: u32 = 0x444444,

    gap_inner_h: i32 = 5,
    gap_inner_v: i32 = 5,
    gap_outer_h: i32 = 5,
    gap_outer_v: i32 = 5,

    auto_tile: bool = false,

    layout_tile_symbol: []const u8 = "[]=",
    layout_monocle_symbol: []const u8 = "[M]",
    layout_floating_symbol: []const u8 = "><>",

    scheme_normal: ColorScheme = .{ .fg = 0xbbbbbb, .bg = 0x1a1b26, .border = 0x444444 },
    scheme_selected: ColorScheme = .{ .fg = 0x0db9d7, .bg = 0x1a1b26, .border = 0xad8ee6 },
    scheme_occupied: ColorScheme = .{ .fg = 0x0db9d7, .bg = 0x1a1b26, .border = 0x0db9d7 },
    scheme_urgent: ColorScheme = .{ .fg = 0xf7768e, .bg = 0x1a1b26, .border = 0xf7768e },

    keybinds: std.ArrayListUnmanaged(Keybind) = .{},
    rules: std.ArrayListUnmanaged(Rule) = .{},
    blocks: std.ArrayListUnmanaged(Block) = .{},
    buttons: std.ArrayListUnmanaged(MouseButton) = .{},

    pub fn init(allocator: std.mem.Allocator) Config {
        return Config{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        self.keybinds.deinit(self.allocator);
        self.rules.deinit(self.allocator);
        self.blocks.deinit(self.allocator);
        self.buttons.deinit(self.allocator);
    }

    pub fn add_keybind(self: *Config, keybind: Keybind) !void {
        try self.keybinds.append(self.allocator, keybind);
    }

    pub fn add_rule(self: *Config, rule: Rule) !void {
        try self.rules.append(self.allocator, rule);
    }

    pub fn add_block(self: *Config, block: Block) !void {
        try self.blocks.append(self.allocator, block);
    }

    pub fn add_button(self: *Config, button: MouseButton) !void {
        try self.buttons.append(self.allocator, button);
    }
};

pub var global_config: ?*Config = null;

pub fn get_config() ?*Config {
    return global_config;
}

pub fn set_config(cfg: *Config) void {
    global_config = cfg;
}
