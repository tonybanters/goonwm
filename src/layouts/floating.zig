const monitor_mod = @import("../monitor.zig");

pub const layout = monitor_mod.Layout{
    .symbol = "><>",
    .arrange_fn = null,
};
