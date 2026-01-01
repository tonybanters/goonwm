const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "goonwm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.addIncludePath(b.path("src/config"));
    exe.addCSourceFile(.{
        .file = b.path("src/config/goonconf.c"),
        .flags = &.{"-std=c99"},
    });

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xinerama");
    exe.linkSystemLibrary("Xft");
    exe.linkSystemLibrary("fontconfig");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_step = b.step("run", "Run goonwm");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run unit tests");
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    test_step.dependOn(&b.addRunArtifact(exe_tests).step);

    const xephyr_step = b.step("xephyr", "Run in Xephyr (1280x800 on :2)");
    xephyr_step.dependOn(&add_xephyr_run(b, exe, false).step);

    const xephyr_multi_step = b.step("xephyr-multi", "Run in Xephyr multi-monitor on :2");
    xephyr_multi_step.dependOn(&add_xephyr_run(b, exe, true).step);

    const multimon_step = b.step("multimon", "Alias for xephyr-multi");
    multimon_step.dependOn(&add_xephyr_run(b, exe, true).step);

    const kill_step = b.step("kill", "Kill Xephyr and goonwm");
    kill_step.dependOn(&b.addSystemCommand(&.{ "sh", "-c", "pkill -9 Xephyr || true; pkill -9 goonwm || true" }).step);

    const fmt_step = b.step("fmt", "Format source files");
    fmt_step.dependOn(&b.addFmt(.{ .paths = &.{"src/"} }).step);

    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addSystemCommand(&.{ "rm", "-rf", "zig-out", ".zig-cache" }).step);
}

fn add_xephyr_run(b: *std.Build, exe: *std.Build.Step.Compile, multimon: bool) *std.Build.Step.Run {
    const kill_cmd = if (multimon)
        "pkill -9 Xephyr || true; Xephyr +xinerama -glamor -screen 640x480 -screen 640x480 :2 & sleep 1"
    else
        "pkill -9 Xephyr || true; Xephyr -screen 1280x800 :2 & sleep 1";

    const setup = b.addSystemCommand(&.{ "sh", "-c", kill_cmd });

    const run_wm = b.addRunArtifact(exe);
    run_wm.step.dependOn(&setup.step);
    run_wm.setEnvironmentVariable("DISPLAY", ":2");
    run_wm.addArgs(&.{ "-c", "resources/test-config.scm" });

    return run_wm;
}
