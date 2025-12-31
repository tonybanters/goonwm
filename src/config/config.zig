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

pub const BlockType = enum {
    static,
    datetime,
    ram,
    shell,
    battery,
};

pub const Block = struct {
    block_type: BlockType,
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

    keybinds: std.ArrayListUnmanaged(Keybind) = .{},
    rules: std.ArrayListUnmanaged(Rule) = .{},
    blocks: std.ArrayListUnmanaged(Block) = .{},

    pub fn init(allocator: std.mem.Allocator) Config {
        return Config{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        self.keybinds.deinit(self.allocator);
        self.rules.deinit(self.allocator);
        self.blocks.deinit(self.allocator);
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
};

pub var global_config: ?*Config = null;

pub fn get_config() ?*Config {
    return global_config;
}

pub fn set_config(cfg: *Config) void {
    global_config = cfg;
}
