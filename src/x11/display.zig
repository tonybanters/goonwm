const std = @import("std");
const xlib = @import("xlib.zig");

pub const DisplayError = error{
    cannot_open_display,
    another_wm_running,
};

var wm_detected: bool = false;

pub const Display = struct {
    handle: *xlib.Display,
    screen: c_int,
    root: xlib.Window,

    pub fn open() DisplayError!Display {
        const handle = xlib.XOpenDisplay(null) orelse return DisplayError.cannot_open_display;
        const screen = xlib.XDefaultScreen(handle);
        const root = xlib.XRootWindow(handle, screen);

        return Display{
            .handle = handle,
            .screen = screen,
            .root = root,
        };
    }

    pub fn close(self: *Display) void {
        _ = xlib.XCloseDisplay(self.handle);
    }

    pub fn become_window_manager(self: *Display) DisplayError!void {
        wm_detected = false;
        _ = xlib.XSetErrorHandler(on_wm_detected);
        _ = xlib.XSelectInput(
            self.handle,
            self.root,
            xlib.SubstructureRedirectMask | xlib.SubstructureNotifyMask | xlib.ButtonPressMask | xlib.PointerMotionMask | xlib.EnterWindowMask,
        );
        _ = xlib.XSync(self.handle, xlib.False);

        if (wm_detected) {
            return DisplayError.another_wm_running;
        }

        _ = xlib.XSetErrorHandler(on_x_error);
    }

    pub fn screen_width(self: *Display) c_int {
        return xlib.XDisplayWidth(self.handle, self.screen);
    }

    pub fn screen_height(self: *Display) c_int {
        return xlib.XDisplayHeight(self.handle, self.screen);
    }

    pub fn next_event(self: *Display) xlib.XEvent {
        var event: xlib.XEvent = undefined;
        _ = xlib.XNextEvent(self.handle, &event);
        return event;
    }

    pub fn pending(self: *Display) c_int {
        return xlib.XPending(self.handle);
    }

    pub fn sync(self: *Display, discard: bool) void {
        _ = xlib.XSync(self.handle, if (discard) xlib.True else xlib.False);
    }

    pub fn grab_key(
        self: *Display,
        keycode: c_int,
        modifiers: c_uint,
    ) void {
        _ = xlib.XGrabKey(
            self.handle,
            keycode,
            modifiers,
            self.root,
            xlib.True,
            xlib.GrabModeAsync,
            xlib.GrabModeAsync,
        );
    }

    pub fn keysym_to_keycode(self: *Display, keysym: xlib.KeySym) c_int {
        return @intCast(xlib.XKeysymToKeycode(self.handle, keysym));
    }
};

fn on_wm_detected(_: ?*xlib.Display, _: [*c]xlib.XErrorEvent) callconv(.c) c_int {
    wm_detected = true;
    return 0;
}

fn on_x_error(_: ?*xlib.Display, event: [*c]xlib.XErrorEvent) callconv(.c) c_int {
    std.debug.print("x11 error: request={d} error={d}\n", .{ event.*.request_code, event.*.error_code });
    return 0;
}
