const std = @import("std");
const display_mod = @import("x11/display.zig");
const events = @import("x11/events.zig");
const xlib = @import("x11/xlib.zig");
const client_mod = @import("client.zig");
const monitor_mod = @import("monitor.zig");
const tiling = @import("layouts/tiling.zig");

const Display = display_mod.Display;
const Client = client_mod.Client;
const Monitor = monitor_mod.Monitor;

var running: bool = true;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var net_wm_state: xlib.Atom = 0;
var net_wm_state_fullscreen: xlib.Atom = 0;

pub fn main() !void {
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    std.debug.print("goonwm starting\n", .{});

    var display = Display.open() catch |err| {
        std.debug.print("failed to open display: {}\n", .{err});
        return;
    };
    defer display.close();

    std.debug.print("display opened: screen={d} root=0x{x}\n", .{ display.screen, display.root });
    std.debug.print("screen size: {d}x{d}\n", .{ display.screen_width(), display.screen_height() });

    display.become_window_manager() catch |err| {
        std.debug.print("failed to become window manager: {}\n", .{err});
        return;
    };

    std.debug.print("successfully became window manager\n", .{});

    setup_atoms(&display);
    client_mod.init(allocator);
    monitor_mod.init(allocator);
    tiling.set_display(display.handle);

    setup_monitors(&display);
    setup_keybinds(&display);
    scan_existing_windows(&display);

    std.debug.print("entering event loop\n", .{});
    run_event_loop(&display);

    std.debug.print("goonwm exiting\n", .{});
}

fn setup_atoms(display: *Display) void {
    net_wm_state = xlib.XInternAtom(display.handle, "_NET_WM_STATE", xlib.False);
    net_wm_state_fullscreen = xlib.XInternAtom(display.handle, "_NET_WM_STATE_FULLSCREEN", xlib.False);
    std.debug.print("atoms initialized\n", .{});
}

fn setup_monitors(display: *Display) void {
    const mon = monitor_mod.create() orelse return;
    mon.mon_x = 0;
    mon.mon_y = 0;
    mon.mon_w = display.screen_width();
    mon.mon_h = display.screen_height();
    mon.win_x = 0;
    mon.win_y = 0;
    mon.win_w = display.screen_width();
    mon.win_h = display.screen_height();
    mon.lt[0] = &tiling.layout;
    monitor_mod.monitors = mon;
    monitor_mod.selected_monitor = mon;
    std.debug.print("monitor created: {d}x{d}\n", .{ mon.mon_w, mon.mon_h });
}

fn setup_keybinds(display: *Display) void {
    const mod_key = xlib.Mod4Mask;
    const alt_key = xlib.Mod1Mask;

    display.grab_key(display.keysym_to_keycode(xlib.XK_q), mod_key | xlib.ShiftMask);
    display.grab_key(display.keysym_to_keycode(xlib.XK_Return), alt_key);
    display.grab_key(display.keysym_to_keycode(xlib.XK_q), alt_key);
    display.grab_key(display.keysym_to_keycode(xlib.XK_f), alt_key);
    display.grab_key(display.keysym_to_keycode(xlib.XK_j), alt_key);
    display.grab_key(display.keysym_to_keycode(xlib.XK_k), alt_key);
    display.grab_key(display.keysym_to_keycode(xlib.XK_space), alt_key);

    const tag_keys = [_]c_ulong{ xlib.XK_1, xlib.XK_2, xlib.XK_3, xlib.XK_4, xlib.XK_5, xlib.XK_6, xlib.XK_7, xlib.XK_8, xlib.XK_9 };
    for (tag_keys) |key| {
        display.grab_key(display.keysym_to_keycode(key), alt_key);
        display.grab_key(display.keysym_to_keycode(key), alt_key | xlib.ShiftMask);
    }

    std.debug.print("keybinds: mod+shift+q=quit, alt+enter=terminal, alt+q=close, alt+f=fullscreen, alt+j/k=focus, alt+space=float, alt+1-9=view, alt+shift+1-9=tag\n", .{});
}

fn scan_existing_windows(display: *Display) void {
    var root_return: xlib.Window = undefined;
    var parent_return: xlib.Window = undefined;
    var children: [*c]xlib.Window = undefined;
    var num_children: c_uint = undefined;

    _ = xlib.XQueryTree(
        display.handle,
        display.root,
        &root_return,
        &parent_return,
        &children,
        &num_children,
    );

    if (num_children > 0) {
        std.debug.print("found {d} existing windows\n", .{num_children});
        _ = xlib.XFree(@ptrCast(children));
    }
}

fn run_event_loop(display: *Display) void {
    while (running) {
        var event = display.next_event();
        handle_event(display, &event);
    }
}

fn handle_event(display: *Display, event: *xlib.XEvent) void {
    const event_type = events.get_event_type(event);

    switch (event_type) {
        .map_request => handle_map_request(display, &event.xmaprequest),
        .configure_request => handle_configure_request(display, &event.xconfigurerequest),
        .key_press => handle_key_press(display, &event.xkey),
        .destroy_notify => handle_destroy_notify(display, &event.xdestroywindow),
        .unmap_notify => handle_unmap_notify(display, &event.xunmap),
        .enter_notify => handle_enter_notify(display, &event.xcrossing),
        .client_message => handle_client_message(display, &event.xclient),
        else => {},
    }
}

fn handle_map_request(display: *Display, event: *xlib.XMapRequestEvent) void {
    std.debug.print("map_request: window=0x{x}\n", .{event.window});

    if (client_mod.window_to_client(event.window) != null) {
        return;
    }

    var window_attributes: xlib.XWindowAttributes = undefined;
    _ = xlib.XGetWindowAttributes(display.handle, event.window, &window_attributes);

    if (window_attributes.override_redirect != 0) {
        return;
    }

    manage(display, event.window, &window_attributes);
}

fn manage(display: *Display, win: xlib.Window, window_attrs: *xlib.XWindowAttributes) void {
    const client = client_mod.create(win) orelse return;
    const monitor = monitor_mod.selected_monitor orelse return;

    client.x = window_attrs.x;
    client.y = window_attrs.y;
    client.width = window_attrs.width;
    client.height = window_attrs.height;
    client.old_border_width = window_attrs.border_width;
    client.border_width = 1;
    client.monitor = monitor;
    client.tags = monitor.tagset[monitor.sel_tags];

    _ = xlib.XSetWindowBorderWidth(display.handle, win, @intCast(client.border_width));

    client_mod.attach(client);
    client_mod.attach_stack(client);

    _ = xlib.XSelectInput(
        display.handle,
        win,
        xlib.EnterWindowMask | xlib.FocusChangeMask | xlib.PropertyChangeMask | xlib.StructureNotifyMask,
    );

    _ = xlib.XMapWindow(display.handle, win);

    focus(display, client);
    arrange(monitor);
}

fn handle_configure_request(display: *Display, event: *xlib.XConfigureRequestEvent) void {
    const client = client_mod.window_to_client(event.window);

    if (client) |managed_client| {
        if (managed_client.is_floating) {
            if ((event.value_mask & xlib.c.CWX) != 0) managed_client.x = event.x;
            if ((event.value_mask & xlib.c.CWY) != 0) managed_client.y = event.y;
            if ((event.value_mask & xlib.c.CWWidth) != 0) managed_client.width = event.width;
            if ((event.value_mask & xlib.c.CWHeight) != 0) managed_client.height = event.height;
            if ((event.value_mask & xlib.c.CWBorderWidth) != 0) managed_client.border_width = event.border_width;
            _ = xlib.XMoveResizeWindow(display.handle, managed_client.window, managed_client.x, managed_client.y, @intCast(managed_client.width), @intCast(managed_client.height));
        }
    } else {
        var changes: xlib.XWindowChanges = undefined;
        changes.x = event.x;
        changes.y = event.y;
        changes.width = event.width;
        changes.height = event.height;
        changes.border_width = event.border_width;
        changes.sibling = event.above;
        changes.stack_mode = event.detail;
        _ = xlib.XConfigureWindow(display.handle, event.window, @intCast(event.value_mask), &changes);
    }
    _ = xlib.XSync(display.handle, xlib.False);
}

fn handle_key_press(display: *Display, event: *xlib.XKeyEvent) void {
    const keysym = xlib.XKeycodeToKeysym(display.handle, @intCast(event.keycode), 0);
    const alt_pressed = (event.state & xlib.Mod1Mask) != 0;
    const shift_pressed = (event.state & xlib.ShiftMask) != 0;
    const super_pressed = (event.state & xlib.Mod4Mask) != 0;

    if (keysym == xlib.XK_q and super_pressed and shift_pressed) {
        std.debug.print("quit keybind pressed\n", .{});
        running = false;
        return;
    }

    if (keysym == xlib.XK_Return and alt_pressed) {
        spawn_terminal();
        return;
    }

    if (keysym == xlib.XK_q and alt_pressed) {
        kill_focused(display);
        return;
    }

    if (keysym == xlib.XK_f and alt_pressed) {
        toggle_fullscreen(display);
        return;
    }

    if (keysym == xlib.XK_j and alt_pressed) {
        focusstack(display, 1);
        return;
    }

    if (keysym == xlib.XK_k and alt_pressed) {
        focusstack(display, -1);
        return;
    }

    if (keysym == xlib.XK_space and alt_pressed) {
        toggle_floating(display);
        return;
    }

    const tag_keys = [_]c_ulong{ xlib.XK_1, xlib.XK_2, xlib.XK_3, xlib.XK_4, xlib.XK_5, xlib.XK_6, xlib.XK_7, xlib.XK_8, xlib.XK_9 };
    for (tag_keys, 0..) |key, index| {
        if (keysym == key and alt_pressed) {
            const tag_mask: u32 = @as(u32, 1) << @intCast(index);
            if (shift_pressed) {
                tag_client(display, tag_mask);
            } else {
                view(display, tag_mask);
            }
            return;
        }
    }
}

fn spawn_terminal() void {
    const pid = std.posix.fork() catch return;
    if (pid == 0) {
        const argv = [_:null]?[*:0]const u8{"alacritty"};
        _ = std.posix.execvpeZ("alacritty", &argv, std.c.environ) catch {};
        std.posix.exit(1);
    }
}

fn kill_focused(display: *Display) void {
    const selected = monitor_mod.selected_monitor orelse return;
    const client = selected.sel orelse return;
    std.debug.print("killing window: 0x{x}\n", .{client.window});
    _ = xlib.XKillClient(display.handle, client.window);
}

fn toggle_fullscreen(display: *Display) void {
    const selected = monitor_mod.selected_monitor orelse return;
    const client = selected.sel orelse return;
    set_fullscreen(display, client, !client.is_fullscreen);
}

fn set_fullscreen(display: *Display, client: *Client, fullscreen: bool) void {
    const monitor = client.monitor orelse return;

    if (fullscreen and !client.is_fullscreen) {
        var fullscreen_atom = net_wm_state_fullscreen;
        _ = xlib.XChangeProperty(
            display.handle,
            client.window,
            net_wm_state,
            xlib.XA_ATOM,
            32,
            xlib.PropModeReplace,
            @ptrCast(&fullscreen_atom),
            1,
        );
        client.is_fullscreen = true;
        client.old_state = client.is_floating;
        client.old_border_width = client.border_width;
        client.border_width = 0;
        client.is_floating = true;

        _ = xlib.XSetWindowBorderWidth(display.handle, client.window, 0);
        tiling.resize(client, monitor.mon_x, monitor.mon_y, monitor.mon_w, monitor.mon_h);
        _ = xlib.XRaiseWindow(display.handle, client.window);

        std.debug.print("fullscreen enabled: window=0x{x}\n", .{client.window});
    } else if (!fullscreen and client.is_fullscreen) {
        var no_atom: xlib.Atom = 0;
        _ = xlib.XChangeProperty(
            display.handle,
            client.window,
            net_wm_state,
            xlib.XA_ATOM,
            32,
            xlib.PropModeReplace,
            @ptrCast(&no_atom),
            0,
        );
        client.is_fullscreen = false;
        client.is_floating = client.old_state;
        client.border_width = client.old_border_width;

        client.x = client.old_x;
        client.y = client.old_y;
        client.width = client.old_width;
        client.height = client.old_height;

        _ = xlib.XSetWindowBorderWidth(display.handle, client.window, @intCast(client.border_width));
        tiling.resize(client, client.x, client.y, client.width, client.height);
        arrange(monitor);

        std.debug.print("fullscreen disabled: window=0x{x}\n", .{client.window});
    }
}

fn view(display: *Display, tag_mask: u32) void {
    const monitor = monitor_mod.selected_monitor orelse return;
    if (tag_mask == monitor.tagset[monitor.sel_tags]) {
        return;
    }
    monitor.sel_tags ^= 1;
    if (tag_mask != 0) {
        monitor.tagset[monitor.sel_tags] = tag_mask;
    }
    focus_top_client(display, monitor);
    arrange(monitor);
    std.debug.print("view: tag_mask={d}\n", .{monitor.tagset[monitor.sel_tags]});
}

fn tag_client(display: *Display, tag_mask: u32) void {
    const monitor = monitor_mod.selected_monitor orelse return;
    const client = monitor.sel orelse return;
    if (tag_mask == 0) {
        return;
    }
    client.tags = tag_mask;
    focus_top_client(display, monitor);
    arrange(monitor);
    std.debug.print("tag_client: window=0x{x} tag_mask={d}\n", .{ client.window, tag_mask });
}

fn focus_top_client(display: *Display, monitor: *Monitor) void {
    var visible_client = monitor.stack;
    while (visible_client) |client| {
        if (client_mod.is_visible(client)) {
            focus(display, client);
            return;
        }
        visible_client = client.stack_next;
    }
    monitor.sel = null;
    _ = xlib.XSetInputFocus(display.handle, display.root, xlib.RevertToPointerRoot, xlib.CurrentTime);
}

fn focusstack(display: *Display, direction: i32) void {
    const monitor = monitor_mod.selected_monitor orelse return;
    const current = monitor.sel orelse return;

    var next_client: ?*Client = null;

    if (direction > 0) {
        next_client = current.next;
        while (next_client) |client| {
            if (client_mod.is_visible(client)) {
                break;
            }
            next_client = client.next;
        }
        if (next_client == null) {
            next_client = monitor.clients;
            while (next_client) |client| {
                if (client_mod.is_visible(client)) {
                    break;
                }
                next_client = client.next;
            }
        }
    } else {
        var prev: ?*Client = null;
        var iter = monitor.clients;
        while (iter) |client| {
            if (client == current) {
                break;
            }
            if (client_mod.is_visible(client)) {
                prev = client;
            }
            iter = client.next;
        }
        if (prev == null) {
            iter = current.next;
            while (iter) |client| {
                if (client_mod.is_visible(client)) {
                    prev = client;
                }
                iter = client.next;
            }
        }
        next_client = prev;
    }

    if (next_client) |client| {
        focus(display, client);
    }
}

fn toggle_floating(display: *Display) void {
    const monitor = monitor_mod.selected_monitor orelse return;
    const client = monitor.sel orelse return;

    if (client.is_fullscreen) {
        return;
    }

    client.is_floating = !client.is_floating;

    if (client.is_floating) {
        tiling.resize(client, client.x, client.y, client.width, client.height);
    }

    arrange(monitor);
    _ = xlib.XRaiseWindow(display.handle, client.window);
    std.debug.print("toggle_floating: window=0x{x} floating={}\n", .{ client.window, client.is_floating });
}

fn handle_client_message(display: *Display, event: *xlib.XClientMessageEvent) void {
    const client = client_mod.window_to_client(event.window) orelse return;

    if (event.message_type == net_wm_state) {
        const action = event.data.l[0];
        const first_property = @as(xlib.Atom, @intCast(event.data.l[1]));

        if (first_property == net_wm_state_fullscreen) {
            const net_wm_state_remove = 0;
            const net_wm_state_add = 1;
            const net_wm_state_toggle = 2;

            if (action == net_wm_state_add) {
                set_fullscreen(display, client, true);
            } else if (action == net_wm_state_remove) {
                set_fullscreen(display, client, false);
            } else if (action == net_wm_state_toggle) {
                set_fullscreen(display, client, !client.is_fullscreen);
            }
        }
    }
}

fn handle_destroy_notify(display: *Display, event: *xlib.XDestroyWindowEvent) void {
    const client = client_mod.window_to_client(event.window) orelse return;
    std.debug.print("destroy_notify: window=0x{x}\n", .{event.window});
    unmanage(display, client);
}

fn handle_unmap_notify(display: *Display, event: *xlib.XUnmapEvent) void {
    const client = client_mod.window_to_client(event.window) orelse return;
    std.debug.print("unmap_notify: window=0x{x}\n", .{event.window});
    unmanage(display, client);
}

fn unmanage(display: *Display, client: *Client) void {
    const client_monitor = client.monitor;
    client_mod.detach(client);
    client_mod.detach_stack(client);

    if (client_monitor) |monitor| {
        if (monitor.sel == client) {
            monitor.sel = monitor.stack;
        }
        arrange(monitor);
    }

    if (client_monitor) |monitor| {
        if (monitor.sel) |selected| {
            focus(display, selected);
        }
    }

    client_mod.destroy(client);
}

fn handle_enter_notify(display: *Display, event: *xlib.XCrossingEvent) void {
    if (event.mode != xlib.NotifyNormal) {
        return;
    }
    const client = client_mod.window_to_client(event.window) orelse return;
    focus(display, client);
}

fn focus(display: *Display, client: *Client) void {
    if (client.monitor) |monitor| {
        monitor.sel = client;
        monitor_mod.selected_monitor = monitor;
    }
    _ = xlib.XSetInputFocus(display.handle, client.window, xlib.RevertToPointerRoot, xlib.CurrentTime);
    _ = xlib.XRaiseWindow(display.handle, client.window);
}

fn arrange(monitor: *Monitor) void {
    showhide(monitor);
    if (monitor.lt[monitor.sel_lt]) |layout| {
        if (layout.arrange_fn) |arrange_fn| {
            arrange_fn(monitor);
        }
    }
}

fn showhide(monitor: *Monitor) void {
    const display = tiling.display_handle orelse return;
    var current = monitor.clients;
    while (current) |client| {
        if (client_mod.is_visible(client)) {
            _ = xlib.XMoveWindow(display, client.window, client.x, client.y);
        } else {
            const hidden_x = -2 * monitor.mon_w;
            _ = xlib.XMoveWindow(display, client.window, hidden_x, client.y);
        }
        current = client.next;
    }
}
