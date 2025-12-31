const std = @import("std");

pub const BlockType = enum {
    static,
    datetime,
    shell,
    ram,
};

pub const Block = struct {
    block_type: BlockType,
    format: []const u8,
    color: c_ulong,
    interval_seconds: u64,
    last_update: i64,
    cached_content: [256]u8,
    cached_len: usize,

    command: ?[]const u8,
    datetime_format: ?[]const u8,

    pub fn init_static(text: []const u8, color: c_ulong) Block {
        var block = Block{
            .block_type = .static,
            .format = text,
            .color = color,
            .interval_seconds = 0,
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .command = null,
            .datetime_format = null,
        };
        @memcpy(block.cached_content[0..text.len], text);
        block.cached_len = text.len;
        return block;
    }

    pub fn init_datetime(format: []const u8, datetime_format: []const u8, interval: u64, color: c_ulong) Block {
        return Block{
            .block_type = .datetime,
            .format = format,
            .color = color,
            .interval_seconds = interval,
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .command = null,
            .datetime_format = datetime_format,
        };
    }

    pub fn init_shell(format: []const u8, command: []const u8, interval: u64, color: c_ulong) Block {
        return Block{
            .block_type = .shell,
            .format = format,
            .color = color,
            .interval_seconds = interval,
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .command = command,
            .datetime_format = null,
        };
    }

    pub fn init_ram(format: []const u8, interval: u64, color: c_ulong) Block {
        return Block{
            .block_type = .ram,
            .format = format,
            .color = color,
            .interval_seconds = interval,
            .last_update = 0,
            .cached_content = undefined,
            .cached_len = 0,
            .command = null,
            .datetime_format = null,
        };
    }

    pub fn update(self: *Block) bool {
        const now = std.time.timestamp();

        if (self.block_type == .static) {
            return false;
        }

        if (now - self.last_update < @as(i64, @intCast(self.interval_seconds))) {
            return false;
        }

        self.last_update = now;

        switch (self.block_type) {
            .datetime => self.update_datetime(),
            .shell => self.update_shell(),
            .ram => self.update_ram(),
            .static => {},
        }

        return true;
    }

    fn update_datetime(self: *Block) void {
        const timestamp = std.time.timestamp();
        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
        const day_seconds = epoch_seconds.getDaySeconds();
        const hours = day_seconds.getHoursIntoDay();
        const minutes = day_seconds.getMinutesIntoHour();

        const result = std.fmt.bufPrint(&self.cached_content, "{d:0>2}:{d:0>2}", .{ hours, minutes }) catch return;
        self.cached_len = result.len;
    }

    fn update_shell(self: *Block) void {
        _ = self;
    }

    fn update_ram(self: *Block) void {
        const file = std.fs.openFileAbsolute("/proc/meminfo", .{}) catch return;
        defer file.close();

        var buffer: [512]u8 = undefined;
        const bytes_read = file.read(&buffer) catch return;
        const content = buffer[0..bytes_read];

        var total: u64 = 0;
        var available: u64 = 0;

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "MemTotal:")) {
                total = parse_meminfo_value(line);
            } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
                available = parse_meminfo_value(line);
            }
        }

        if (total > 0) {
            const used = total - available;
            const used_gb = @as(f32, @floatFromInt(used)) / 1024.0 / 1024.0;
            const total_gb = @as(f32, @floatFromInt(total)) / 1024.0 / 1024.0;

            const result = std.fmt.bufPrint(&self.cached_content, "RAM: {d:.1}/{d:.1}GB", .{ used_gb, total_gb }) catch return;
            self.cached_len = result.len;
        }
    }

    pub fn get_content(self: *const Block) []const u8 {
        return self.cached_content[0..self.cached_len];
    }
};

fn parse_meminfo_value(line: []const u8) u64 {
    var iter = std.mem.tokenizeAny(u8, line, ": \tkB");
    _ = iter.next();
    if (iter.next()) |value_str| {
        return std.fmt.parseInt(u64, value_str, 10) catch 0;
    }
    return 0;
}
