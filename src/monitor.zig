const std = @import("std");
const xlib = @import("x11/xlib.zig");
const Client = @import("client.zig").Client;

pub const Layout = struct {
    symbol: []const u8,
    arrange_fn: ?*const fn (*Monitor) void,
};

pub const Pertag = struct {
    curtag: u32 = 1,
    prevtag: u32 = 1,
    nmasters: [10]i32 = [_]i32{1} ** 10,
    mfacts: [10]f32 = [_]f32{0.55} ** 10,
    sellts: [10]u32 = [_]u32{0} ** 10,
    ltidxs: [10][4]?*const Layout = [_][4]?*const Layout{.{ null, null, null, null }} ** 10,
    showbars: [10]bool = [_]bool{true} ** 10,
};

pub const Monitor = struct {
    lt_symbol: [16]u8 = std.mem.zeroes([16]u8),
    mfact: f32 = 0.55,
    nmaster: i32 = 1,
    num: i32 = 0,
    bar_y: i32 = 0,
    mon_x: i32 = 0,
    mon_y: i32 = 0,
    mon_w: i32 = 0,
    mon_h: i32 = 0,
    win_x: i32 = 0,
    win_y: i32 = 0,
    win_w: i32 = 0,
    win_h: i32 = 0,
    gap_inner_h: i32 = 0,
    gap_inner_v: i32 = 0,
    gap_outer_h: i32 = 0,
    gap_outer_v: i32 = 0,
    scroll_offset: i32 = 0,
    sel_tags: u32 = 0,
    sel_lt: u32 = 0,
    tagset: [2]u32 = .{ 1, 1 },
    show_bar: bool = true,
    top_bar: bool = true,
    clients: ?*Client = null,
    sel: ?*Client = null,
    stack: ?*Client = null,
    next: ?*Monitor = null,
    bar_win: xlib.Window = 0,
    lt: [4]?*const Layout = .{ null, null, null, null },
    pertag: Pertag = Pertag{},
};

pub var monitors: ?*Monitor = null;
pub var selected_monitor: ?*Monitor = null;

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn create() ?*Monitor {
    const mon = allocator.create(Monitor) catch return null;
    mon.* = Monitor{};
    return mon;
}

pub fn destroy(mon: *Monitor) void {
    allocator.destroy(mon);
}

var root_window: xlib.Window = 0;
var display_handle: ?*xlib.Display = null;

pub fn set_root_window(root: xlib.Window, display: *xlib.Display) void {
    root_window = root;
    display_handle = display;
}

pub fn window_to_monitor(win: xlib.Window) ?*Monitor {
    if (win == root_window and display_handle != null) {
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var dummy_win: xlib.Window = undefined;
        var dummy_int: c_int = undefined;
        var dummy_uint: c_uint = undefined;
        if (xlib.XQueryPointer(display_handle.?, root_window, &dummy_win, &dummy_win, &root_x, &root_y, &dummy_int, &dummy_int, &dummy_uint) != 0) {
            return rect_to_monitor(root_x, root_y, 1, 1);
        }
    }

    var current = monitors;
    while (current) |monitor| {
        if (monitor.bar_win == win) {
            return monitor;
        }
        current = monitor.next;
    }

    const client = @import("client.zig").window_to_client(win);
    if (client) |found_client| {
        return found_client.monitor;
    }

    return selected_monitor;
}

pub fn rect_to_monitor(x: i32, y: i32, width: i32, height: i32) ?*Monitor {
    var result = selected_monitor;
    var max_area: i32 = 0;

    var current = monitors;
    while (current) |monitor| {
        const intersect_x = @max(0, @min(x + width, monitor.win_x + monitor.win_w) - @max(x, monitor.win_x));
        const intersect_y = @max(0, @min(y + height, monitor.win_y + monitor.win_h) - @max(y, monitor.win_y));
        const area = intersect_x * intersect_y;
        if (area > max_area) {
            max_area = area;
            result = monitor;
        }
        current = monitor.next;
    }
    return result;
}

pub fn dir_to_monitor(direction: i32) ?*Monitor {
    var target: ?*Monitor = null;

    if (direction > 0) {
        target = if (selected_monitor) |current| current.next else null;
        if (target == null) {
            target = monitors;
        }
    } else if (selected_monitor == monitors) {
        var last = monitors;
        while (last) |iter| {
            if (iter.next == null) {
                target = iter;
                break;
            }
            last = iter.next;
        }
    } else {
        var previous = monitors;
        while (previous) |iter| {
            if (iter.next == selected_monitor) {
                target = iter;
                break;
            }
            previous = iter.next;
        }
    }
    return target;
}
