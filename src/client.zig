const std = @import("std");
const xlib = @import("x11/xlib.zig");
const Monitor = @import("monitor.zig").Monitor;

pub const Client = struct {
    name: [256]u8 = std.mem.zeroes([256]u8),
    min_aspect: f32 = 0,
    max_aspect: f32 = 0,
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    old_x: i32 = 0,
    old_y: i32 = 0,
    old_width: i32 = 0,
    old_height: i32 = 0,
    base_width: i32 = 0,
    base_height: i32 = 0,
    increment_width: i32 = 0,
    increment_height: i32 = 0,
    max_width: i32 = 0,
    max_height: i32 = 0,
    min_width: i32 = 0,
    min_height: i32 = 0,
    hints_valid: bool = false,
    border_width: i32 = 0,
    old_border_width: i32 = 0,
    tags: u32 = 0,
    is_fixed: bool = false,
    is_floating: bool = false,
    is_urgent: bool = false,
    never_focus: bool = false,
    old_state: bool = false,
    is_fullscreen: bool = false,
    next: ?*Client = null,
    stack_next: ?*Client = null,
    monitor: ?*Monitor = null,
    window: xlib.Window = 0,
};

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn create(window: xlib.Window) ?*Client {
    const client = allocator.create(Client) catch return null;
    client.* = Client{ .window = window };
    return client;
}

pub fn destroy(client: *Client) void {
    allocator.destroy(client);
}

pub fn attach(client: *Client) void {
    if (client.monitor) |monitor| {
        client.next = monitor.clients;
        monitor.clients = client;
    }
}

pub fn detach(client: *Client) void {
    if (client.monitor) |monitor| {
        var current_ptr: *?*Client = &monitor.clients;
        while (current_ptr.*) |current| {
            if (current == client) {
                current_ptr.* = client.next;
                return;
            }
            current_ptr = &current.next;
        }
    }
}

pub fn attach_stack(client: *Client) void {
    if (client.monitor) |monitor| {
        client.stack_next = monitor.stack;
        monitor.stack = client;
    }
}

pub fn detach_stack(client: *Client) void {
    if (client.monitor) |monitor| {
        var current_ptr: *?*Client = &monitor.stack;
        while (current_ptr.*) |current| {
            if (current == client) {
                current_ptr.* = client.stack_next;
                return;
            }
            current_ptr = &current.stack_next;
        }
    }
}

pub fn window_to_client(window: xlib.Window) ?*Client {
    const monitor_mod = @import("monitor.zig");
    var current_monitor = monitor_mod.monitors;
    while (current_monitor) |monitor| {
        var current_client = monitor.clients;
        while (current_client) |client| {
            if (client.window == window) {
                return client;
            }
            current_client = client.next;
        }
        current_monitor = monitor.next;
    }
    return null;
}

pub fn next_tiled(client: ?*Client) ?*Client {
    var current = client;
    while (current) |iter| {
        if (!iter.is_floating and is_visible(iter)) {
            return iter;
        }
        current = iter.next;
    }
    return null;
}

pub fn is_visible(client: *Client) bool {
    if (client.monitor) |monitor| {
        return (client.tags & monitor.tagset[monitor.sel_tags]) != 0;
    }
    return false;
}

pub fn count_tiled(monitor: *Monitor) u32 {
    var count: u32 = 0;
    var current = next_tiled(monitor.clients);
    while (current) |client| {
        count += 1;
        current = next_tiled(client.next);
    }
    return count;
}

pub fn swap_clients(client_a: *Client, client_b: *Client) void {
    const monitor = client_a.monitor orelse return;
    if (client_b.monitor != monitor) return;

    var prev_a: ?*Client = null;
    var prev_b: ?*Client = null;
    var iter = monitor.clients;

    while (iter) |client| {
        if (client.next == client_a) prev_a = client;
        if (client.next == client_b) prev_b = client;
        iter = client.next;
    }

    const next_a = client_a.next;
    const next_b = client_b.next;

    if (next_a == client_b) {
        client_a.next = next_b;
        client_b.next = client_a;
        if (prev_a) |prev| {
            prev.next = client_b;
        } else {
            monitor.clients = client_b;
        }
    } else if (next_b == client_a) {
        client_b.next = next_a;
        client_a.next = client_b;
        if (prev_b) |prev| {
            prev.next = client_a;
        } else {
            monitor.clients = client_a;
        }
    } else {
        client_a.next = next_b;
        client_b.next = next_a;
        if (prev_a) |prev| {
            prev.next = client_b;
        } else {
            monitor.clients = client_b;
        }
        if (prev_b) |prev| {
            prev.next = client_a;
        } else {
            monitor.clients = client_a;
        }
    }
}
