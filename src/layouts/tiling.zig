const std = @import("std");
const client_mod = @import("../client.zig");
const monitor_mod = @import("../monitor.zig");
const xlib = @import("../x11/xlib.zig");

const Client = client_mod.Client;
const Monitor = monitor_mod.Monitor;

pub const layout = monitor_mod.Layout{
    .symbol = "[]=",
    .arrange_fn = tile,
};

pub fn tile(monitor: *Monitor) void {
    var gap_outer_h: i32 = 0;
    var gap_outer_v: i32 = 0;
    var gap_inner_h: i32 = 0;
    var gap_inner_v: i32 = 0;
    var client_count: u32 = 0;

    get_gaps(monitor, &gap_outer_h, &gap_outer_v, &gap_inner_h, &gap_inner_v, &client_count);
    if (client_count == 0) return;

    const nmaster: i32 = monitor.nmaster;
    const nmaster_count: u32 = @intCast(@max(0, nmaster));

    const master_x: i32 = monitor.win_x + gap_outer_v;
    var master_y: i32 = monitor.win_y + gap_outer_h;
    const master_height: i32 = monitor.win_h - 2 * gap_outer_h - gap_inner_h * (@as(i32, @intCast(@min(client_count, nmaster_count))) - 1);
    var master_width: i32 = monitor.win_w - 2 * gap_outer_v;

    var stack_x: i32 = master_x;
    var stack_y: i32 = monitor.win_y + gap_outer_h;
    const stack_height: i32 = monitor.win_h - 2 * gap_outer_h - gap_inner_h * (@as(i32, @intCast(client_count)) - nmaster - 1);
    var stack_width: i32 = master_width;

    if (nmaster > 0 and client_count > nmaster_count) {
        stack_width = @intFromFloat(@as(f32, @floatFromInt(master_width - gap_inner_v)) * (1.0 - monitor.mfact));
        master_width = master_width - gap_inner_v - stack_width;
        stack_x = master_x + master_width + gap_inner_v;
    }

    var master_facts: f32 = 0;
    var stack_facts: f32 = 0;
    var master_rest: i32 = 0;
    var stack_rest: i32 = 0;
    get_facts(monitor, master_height, stack_height, &master_facts, &stack_facts, &master_rest, &stack_rest);

    var index: u32 = 0;
    var current = client_mod.next_tiled(monitor.clients);
    while (current) |client| : (current = client_mod.next_tiled(client.next)) {
        if (index < nmaster_count) {
            const height = @as(i32, @intFromFloat(@as(f32, @floatFromInt(master_height)) / master_facts)) + (if (index < @as(u32, @intCast(master_rest))) @as(i32, 1) else @as(i32, 0)) - 2 * client.border_width;
            resize(client, master_x, master_y, master_width - 2 * client.border_width, height);
            master_y += client_height(client) + gap_inner_h;
        } else {
            const stack_index = index - nmaster_count;
            const height = @as(i32, @intFromFloat(@as(f32, @floatFromInt(stack_height)) / stack_facts)) + (if (stack_index < @as(u32, @intCast(stack_rest))) @as(i32, 1) else @as(i32, 0)) - 2 * client.border_width;
            resize(client, stack_x, stack_y, stack_width - 2 * client.border_width, height);
            stack_y += client_height(client) + gap_inner_h;
        }
        index += 1;
    }
}

fn get_gaps(monitor: *Monitor, gap_outer_h: *i32, gap_outer_v: *i32, gap_inner_h: *i32, gap_inner_v: *i32, client_count: *u32) void {
    var count: u32 = 0;
    var current = client_mod.next_tiled(monitor.clients);
    while (current) |client| : (current = client_mod.next_tiled(client.next)) {
        count += 1;
    }

    gap_outer_h.* = monitor.gap_outer_h;
    gap_outer_v.* = monitor.gap_outer_v;
    gap_inner_h.* = monitor.gap_inner_h;
    gap_inner_v.* = monitor.gap_inner_v;
    client_count.* = count;
}

fn get_facts(monitor: *Monitor, master_size: i32, stack_size: i32, master_factor: *f32, stack_factor: *f32, master_rest: *i32, stack_rest: *i32) void {
    var count: u32 = 0;
    var current = client_mod.next_tiled(monitor.clients);
    while (current) |client| : (current = client_mod.next_tiled(client.next)) {
        count += 1;
    }

    const nmaster_count: u32 = @intCast(@max(0, monitor.nmaster));
    const master_facts: f32 = @floatFromInt(@min(count, nmaster_count));
    const stack_facts: f32 = @floatFromInt(if (count > nmaster_count) count - nmaster_count else 0);

    var master_total: i32 = 0;
    var stack_total: i32 = 0;

    if (master_facts > 0) {
        master_total = @as(i32, @intFromFloat(@as(f32, @floatFromInt(master_size)) / master_facts)) * @as(i32, @intFromFloat(master_facts));
    }
    if (stack_facts > 0) {
        stack_total = @as(i32, @intFromFloat(@as(f32, @floatFromInt(stack_size)) / stack_facts)) * @as(i32, @intFromFloat(stack_facts));
    }

    master_factor.* = master_facts;
    stack_factor.* = stack_facts;
    master_rest.* = master_size - master_total;
    stack_rest.* = stack_size - stack_total;
}

fn client_width(client: *Client) i32 {
    return client.width + 2 * client.border_width;
}

fn client_height(client: *Client) i32 {
    return client.height + 2 * client.border_width;
}

pub var display_handle: ?*xlib.Display = null;

pub fn set_display(display: *xlib.Display) void {
    display_handle = display;
}

pub fn resize(client: *Client, x: i32, y: i32, width: i32, height: i32) void {
    client.old_x = client.x;
    client.old_y = client.y;
    client.old_width = client.width;
    client.old_height = client.height;
    client.x = x;
    client.y = y;
    client.width = @max(1, width);
    client.height = @max(1, height);

    if (display_handle) |display| {
        _ = xlib.XMoveResizeWindow(display, client.window, x, y, @intCast(@max(1, width)), @intCast(@max(1, height)));
        _ = xlib.XSync(display, xlib.False);
    }
}
