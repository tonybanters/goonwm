const std = @import("std");
const format_util = @import("format.zig");

const pulse = @cImport({
    @cInclude("pulse/pulseaudio.h");
});

var global_volume: u8 = 0;
var global_muted: bool = false;
var current_cvolume: pulse.pa_cvolume = undefined;
var initialized: bool = false;
var pa_ml: ?*pulse.pa_threaded_mainloop = null;
var pa_ctx: ?*pulse.pa_context = null;

fn sink_info_cb(
    ctx: ?*pulse.pa_context,
    info: ?*const pulse.pa_sink_info,
    eol: c_int,
    userdata: ?*anyopaque,
) callconv(.c) void {
    _ = ctx;
    _ = userdata;
    if (eol != 0 or info == null) return;

    if (info) |sink| {
        const avg = pulse.pa_cvolume_avg(&sink.volume);
        const pct = (avg * 100 + pulse.PA_VOLUME_NORM / 2) / pulse.PA_VOLUME_NORM;
        global_volume = @intCast(@min(pct, 100));
        global_muted = sink.mute != 0;
        current_cvolume = sink.volume;
    }
}

fn subscribe_cb(
    ctx: ?*pulse.pa_context,
    event_type: pulse.pa_subscription_event_type_t,
    idx: u32,
    userdata: ?*anyopaque,
) callconv(.c) void {
    _ = idx;
    _ = userdata;
    const facility = event_type & pulse.PA_SUBSCRIPTION_EVENT_FACILITY_MASK;
    if (facility == pulse.PA_SUBSCRIPTION_EVENT_SINK or facility == pulse.PA_SUBSCRIPTION_EVENT_SERVER) {
        _ = pulse.pa_context_get_sink_info_by_name(ctx, "@DEFAULT_SINK@", sink_info_cb, null);
    }
}

fn context_state_cb(ctx: ?*pulse.pa_context, userdata: ?*anyopaque) callconv(.c) void {
    _ = userdata;
    const state = pulse.pa_context_get_state(ctx);
    if (state == pulse.PA_CONTEXT_READY) {
        pulse.pa_context_set_subscribe_callback(ctx, subscribe_cb, null);
        _ = pulse.pa_context_subscribe(ctx, pulse.PA_SUBSCRIPTION_MASK_SINK | pulse.PA_SUBSCRIPTION_MASK_SERVER, null, null);
        _ = pulse.pa_context_get_sink_info_by_name(ctx, "@DEFAULT_SINK@", sink_info_cb, null);
    }
}

pub fn init_pa() void {
    if (initialized) return;

    pa_ml = pulse.pa_threaded_mainloop_new();
    if (pa_ml == null) return;

    const api = pulse.pa_threaded_mainloop_get_api(pa_ml);
    pa_ctx = pulse.pa_context_new(api, "goonwm");
    if (pa_ctx == null) {
        pulse.pa_threaded_mainloop_free(pa_ml);
        pa_ml = null;
        return;
    }

    pulse.pa_context_set_state_callback(pa_ctx, context_state_cb, null);

    if (pulse.pa_context_connect(pa_ctx, null, pulse.PA_CONTEXT_NOFLAGS, null) < 0) {
        pulse.pa_context_unref(pa_ctx);
        pulse.pa_threaded_mainloop_free(pa_ml);
        pa_ctx = null;
        pa_ml = null;
        return;
    }

    _ = pulse.pa_threaded_mainloop_start(pa_ml);
    initialized = true;
}

pub fn deinit_pa() void {
    if (!initialized) return;
    if (pa_ml) |ml| {
        pulse.pa_threaded_mainloop_stop(ml);
        if (pa_ctx) |ctx| {
            pulse.pa_context_disconnect(ctx);
            pulse.pa_context_unref(ctx);
        }
        pulse.pa_threaded_mainloop_free(ml);
    }
    pa_ml = null;
    pa_ctx = null;
    initialized = false;
}

pub fn adjust_volume(delta: i32) void {
    const ml = pa_ml orelse return;
    const ctx = pa_ctx orelse return;

    pulse.pa_threaded_mainloop_lock(ml);
    defer pulse.pa_threaded_mainloop_unlock(ml);

    if (pulse.pa_context_get_state(ctx) != pulse.PA_CONTEXT_READY) return;

    var vol = current_cvolume;
    const step: u32 = @intCast(@abs(delta));
    const change = (pulse.PA_VOLUME_NORM * step) / 100;

    if (delta > 0) {
        _ = pulse.pa_cvolume_inc_clamp(&vol, change, pulse.PA_VOLUME_NORM);
    } else {
        _ = pulse.pa_cvolume_dec(&vol, change);
    }

    _ = pulse.pa_context_set_sink_volume_by_name(ctx, "@DEFAULT_SINK@", &vol, null, null);
}

pub fn toggle_mute() void {
    const ml = pa_ml orelse return;
    const ctx = pa_ctx orelse return;

    pulse.pa_threaded_mainloop_lock(ml);
    defer pulse.pa_threaded_mainloop_unlock(ml);

    if (pulse.pa_context_get_state(ctx) != pulse.PA_CONTEXT_READY) return;

    const new_mute: c_int = if (global_muted) 0 else 1;
    _ = pulse.pa_context_set_sink_mute_by_name(ctx, "@DEFAULT_SINK@", new_mute, null, null);
}

pub const Pulseaudio = struct {
    format_muted: []const u8,
    format_low: []const u8,
    format_medium: []const u8,
    format_high: []const u8,
    interval_secs: u64,
    color: c_ulong,

    pub fn init(
        format_muted: []const u8,
        format_low: []const u8,
        format_medium: []const u8,
        format_high: []const u8,
        interval_secs: u64,
        color: c_ulong,
    ) Pulseaudio {
        init_pa();
        return .{
            .format_muted = format_muted,
            .format_low = format_low,
            .format_medium = format_medium,
            .format_high = format_high,
            .interval_secs = interval_secs,
            .color = color,
        };
    }

    pub fn content(self: *Pulseaudio, buffer: []u8) []const u8 {
        const format = if (global_muted or global_volume == 0)
            self.format_muted
        else if (global_volume <= 33)
            self.format_low
        else if (global_volume <= 66)
            self.format_medium
        else
            self.format_high;

        var vol_buf: [8]u8 = undefined;
        const vol_str = std.fmt.bufPrint(&vol_buf, "{d}", .{global_volume}) catch return buffer[0..0];

        return format_util.substitute(format, vol_str, buffer);
    }

    pub fn interval(self: *Pulseaudio) u64 {
        return self.interval_secs;
    }

    pub fn get_color(self: *Pulseaudio) c_ulong {
        return self.color;
    }
};
