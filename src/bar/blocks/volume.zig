const std = @import("std");
const format_util = @import("format.zig");

const alsa = @cImport({
    @cInclude("alsa/asoundlib.h");
});

pub const Volume = struct {
    format_muted: []const u8,
    format_low: []const u8,
    format_medium: []const u8,
    format_high: []const u8,
    mixer_name: []const u8,
    interval_secs: u64,
    color: c_ulong,

    pub fn init(
        format_muted: []const u8,
        format_low: []const u8,
        format_medium: []const u8,
        format_high: []const u8,
        mixer_name: []const u8,
        interval_secs: u64,
        color: c_ulong,
    ) Volume {
        return .{
            .format_muted = format_muted,
            .format_low = format_low,
            .format_medium = format_medium,
            .format_high = format_high,
            .mixer_name = if (mixer_name.len > 0) mixer_name else "Master",
            .interval_secs = interval_secs,
            .color = color,
        };
    }

    pub fn content(self: *Volume, buffer: []u8) []const u8 {
        var handle: ?*alsa.snd_mixer_t = null;
        var sid: ?*alsa.snd_mixer_selem_id_t = null;

        if (alsa.snd_mixer_open(&handle, 0) < 0) return buffer[0..0];
        defer _ = alsa.snd_mixer_close(handle);

        if (alsa.snd_mixer_attach(handle, "default") < 0) return buffer[0..0];
        if (alsa.snd_mixer_selem_register(handle, null, null) < 0) return buffer[0..0];
        if (alsa.snd_mixer_load(handle) < 0) return buffer[0..0];

        _ = alsa.snd_mixer_selem_id_malloc(&sid);
        defer alsa.snd_mixer_selem_id_free(sid);

        alsa.snd_mixer_selem_id_set_index(sid, 0);

        var name_buf: [64]u8 = undefined;
        @memcpy(name_buf[0..self.mixer_name.len], self.mixer_name);
        name_buf[self.mixer_name.len] = 0;
        alsa.snd_mixer_selem_id_set_name(sid, &name_buf);

        const elem = alsa.snd_mixer_find_selem(handle, sid);
        if (elem == null) return buffer[0..0];

        var volume: c_long = 0;
        var min: c_long = 0;
        var max: c_long = 0;
        _ = alsa.snd_mixer_selem_get_playback_volume_range(elem, &min, &max);
        _ = alsa.snd_mixer_selem_get_playback_volume(elem, alsa.SND_MIXER_SCHN_FRONT_LEFT, &volume);

        var muted: c_int = 0;
        _ = alsa.snd_mixer_selem_get_playback_switch(elem, alsa.SND_MIXER_SCHN_FRONT_LEFT, &muted);

        const range = max - min;
        const percent: u8 = if (range > 0) @intCast(@divTrunc((volume - min) * 100, range)) else 0;

        const format = if (muted == 0 or percent == 0)
            self.format_muted
        else if (percent <= 33)
            self.format_low
        else if (percent <= 66)
            self.format_medium
        else
            self.format_high;

        var vol_buf: [8]u8 = undefined;
        const vol_str = std.fmt.bufPrint(&vol_buf, "{d}", .{percent}) catch return buffer[0..0];

        return format_util.substitute(format, vol_str, buffer);
    }

    pub fn interval(self: *Volume) u64 {
        return self.interval_secs;
    }

    pub fn get_color(self: *Volume) c_ulong {
        return self.color;
    }
};
