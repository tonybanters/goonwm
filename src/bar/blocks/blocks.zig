const std = @import("std");

pub const Static = @import("static.zig").Static;
pub const DateTime = @import("datetime.zig").DateTime;
pub const Ram = @import("ram.zig").Ram;
pub const Shell = @import("shell.zig").Shell;
pub const Battery = @import("battery.zig").Battery;

pub const BlockType = enum {
    static,
    datetime,
    ram,
    shell,
    battery,
};

pub const Block = struct {
    data: Data,
    last_update: i64,
    cached_content: [256]u8,
    cached_len: usize,
    underline: bool,

    pub const Data = union(BlockType) {
        static: Static,
        datetime: DateTime,
        ram: Ram,
        shell: Shell,
        battery: Battery,
    };

    pub fn initStatic(text: []const u8, col: c_ulong, ul: bool) Block {
        var block = Block{
            .data = .{ .static = Static.init(text, col) },
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .underline = ul,
        };
        @memcpy(block.cached_content[0..text.len], text);
        block.cached_len = text.len;
        return block;
    }

    pub fn initDatetime(format: []const u8, datetime_format: []const u8, interval_secs: u64, col: c_ulong, ul: bool) Block {
        return .{
            .data = .{ .datetime = DateTime.init(format, datetime_format, interval_secs, col) },
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .underline = ul,
        };
    }

    pub fn initRam(format: []const u8, interval_secs: u64, col: c_ulong, ul: bool) Block {
        return .{
            .data = .{ .ram = Ram.init(format, interval_secs, col) },
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .underline = ul,
        };
    }

    pub fn initShell(format: []const u8, command: []const u8, interval_secs: u64, col: c_ulong, ul: bool) Block {
        return .{
            .data = .{ .shell = Shell.init(format, command, interval_secs, col) },
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .underline = ul,
        };
    }

    pub fn initBattery(
        format_charging: []const u8,
        format_discharging: []const u8,
        format_full: []const u8,
        battery_name: []const u8,
        interval_secs: u64,
        col: c_ulong,
        ul: bool,
    ) Block {
        return .{
            .data = .{ .battery = Battery.init(format_charging, format_discharging, format_full, battery_name, interval_secs, col) },
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .underline = ul,
        };
    }

    pub fn update(self: *Block) bool {
        const interval_secs = self.interval();
        if (interval_secs == 0) return false;

        const now = std.time.timestamp();
        if (now - self.last_update < @as(i64, @intCast(interval_secs))) {
            return false;
        }

        self.last_update = now;

        const result = switch (self.data) {
            .static => |*s| s.content(&self.cached_content),
            .datetime => |*d| d.content(&self.cached_content),
            .ram => |*r| r.content(&self.cached_content),
            .shell => |*s| s.content(&self.cached_content),
            .battery => |*b| b.content(&self.cached_content),
        };

        self.cached_len = result.len;
        return true;
    }

    pub fn interval(self: *Block) u64 {
        return switch (self.data) {
            .static => |*s| s.interval(),
            .datetime => |*d| d.interval(),
            .ram => |*r| r.interval(),
            .shell => |*s| s.interval(),
            .battery => |*b| b.interval(),
        };
    }

    pub fn color(self: *const Block) c_ulong {
        return switch (self.data) {
            .static => |s| s.color,
            .datetime => |d| d.color,
            .ram => |r| r.color,
            .shell => |s| s.color,
            .battery => |b| b.color,
        };
    }

    pub fn getContent(self: *const Block) []const u8 {
        return self.cached_content[0..self.cached_len];
    }
};
