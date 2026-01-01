const std = @import("std");
const client_mod = @import("../client.zig");
const monitor_mod = @import("../monitor.zig");
const xlib = @import("../x11/xlib.zig");
const tiling = @import("tiling.zig");

const Client = client_mod.Client;
const Monitor = monitor_mod.Monitor;

pub const layout = monitor_mod.Layout{
    .symbol = "[M]",
    .arrange_fn = monocle,
};

pub fn monocle(monitor: *Monitor) void {
    const gap_h = monitor.gap_outer_h;
    const gap_v = monitor.gap_outer_v;

    var current = client_mod.next_tiled(monitor.clients);
    while (current) |client| {
        tiling.resize(
            client,
            monitor.win_x + gap_v,
            monitor.win_y + gap_h,
            monitor.win_w - 2 * gap_v - 2 * client.border_width,
            monitor.win_h - 2 * gap_h - 2 * client.border_width,
            false,
        );
        current = client_mod.next_tiled(client.next);
    }
}
