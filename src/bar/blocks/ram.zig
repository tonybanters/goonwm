const std = @import("std");
const format_util = @import("format.zig");

pub const Ram = struct {
    format: []const u8,
    interval_secs: u64,
    color: c_ulong,

    pub fn init(format: []const u8, interval_secs: u64, color: c_ulong) Ram {
        return .{
            .format = format,
            .interval_secs = interval_secs,
            .color = color,
        };
    }

    pub fn content(self: *Ram, buffer: []u8) []const u8 {
        const file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return buffer[0..0];
        defer file.close();

        var read_buffer: [512]u8 = undefined;
        const bytes_read = file.read(&read_buffer) catch return buffer[0..0];
        const file_content = read_buffer[0..bytes_read];

        var total: u64 = 0;
        var available: u64 = 0;

        var lines = std.mem.splitScalar(u8, file_content, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "MemTotal:")) {
                total = parseMemValue(line);
            } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
                available = parseMemValue(line);
            }
        }

        if (total == 0) return buffer[0..0];

        const used = total - available;
        const used_gb = @as(f32, @floatFromInt(used)) / 1024.0 / 1024.0;
        const total_gb = @as(f32, @floatFromInt(total)) / 1024.0 / 1024.0;
        const percent = (@as(f32, @floatFromInt(used)) / @as(f32, @floatFromInt(total))) * 100.0;

        var val_bufs: [3][16]u8 = undefined;
        const used_str = std.fmt.bufPrint(&val_bufs[0], "{d:.1}", .{used_gb}) catch return buffer[0..0];
        const total_str = std.fmt.bufPrint(&val_bufs[1], "{d:.1}", .{total_gb}) catch return buffer[0..0];
        const percent_str = std.fmt.bufPrint(&val_bufs[2], "{d:.0}", .{percent}) catch return buffer[0..0];

        return format_util.substituteMulti(self.format, &.{ used_str, total_str, percent_str }, buffer);
    }

    pub fn interval(self: *Ram) u64 {
        return self.interval_secs;
    }

    pub fn getColor(self: *Ram) c_ulong {
        return self.color;
    }
};

fn parseMemValue(line: []const u8) u64 {
    var iter = std.mem.tokenizeAny(u8, line, ": \tkB");
    _ = iter.next();
    if (iter.next()) |value_str| {
        return std.fmt.parseInt(u64, value_str, 10) catch 0;
    }
    return 0;
}
