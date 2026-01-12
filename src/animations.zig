const std = @import("std");

pub const Easing = enum {
    linear,
    ease_out,
    ease_in_out,

    pub fn apply(self: Easing, t: f64) f64 {
        return switch (self) {
            .linear => t,
            .ease_out => 1.0 - std.math.pow(f64, 1.0 - t, 3),
            .ease_in_out => if (t < 0.5)
                4.0 * t * t * t
            else
                1.0 - std.math.pow(f64, -2.0 * t + 2.0, 3) / 2.0,
        };
    }
};

pub const Animation_Config = struct {
    duration_ms: u64 = 150,
    easing: Easing = .ease_out,
};

pub const Scroll_Animation = struct {
    start_value: i32 = 0,
    end_value: i32 = 0,
    start_time: i64 = 0,
    duration_ms: u64 = 150,
    easing: Easing = .ease_out,
    active: bool = false,

    pub fn start(self: *Scroll_Animation, from: i32, to: i32, config: Animation_Config) void {
        if (from == to) {
            self.active = false;
            return;
        }
        self.start_value = from;
        self.end_value = to;
        self.start_time = std.time.milliTimestamp();
        self.duration_ms = config.duration_ms;
        self.easing = config.easing;
        self.active = true;
    }

    pub fn update(self: *Scroll_Animation) ?i32 {
        if (!self.active) return null;

        const now = std.time.milliTimestamp();
        const elapsed = now - self.start_time;

        if (elapsed >= @as(i64, @intCast(self.duration_ms))) {
            self.active = false;
            return self.end_value;
        }

        const t = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(self.duration_ms));
        const eased = self.easing.apply(t);
        const diff = @as(f64, @floatFromInt(self.end_value - self.start_value));
        const current = @as(f64, @floatFromInt(self.start_value)) + (diff * eased);

        return @intFromFloat(current);
    }

    pub fn is_active(self: *const Scroll_Animation) bool {
        return self.active;
    }

    pub fn target(self: *const Scroll_Animation) i32 {
        return self.end_value;
    }

    pub fn stop(self: *Scroll_Animation) void {
        self.active = false;
    }
};
