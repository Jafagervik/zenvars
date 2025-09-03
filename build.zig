const std = @import("std");
const builtin = @import("builtin");

const zig_version: std.SemanticVersion = .{ .major = 0, .minor = 15, .patch = 1 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (zig_version.major != builtin.zig_version.major or zig_version.minor != builtin.zig_version.minor or zig_version.patch != builtin.zig_version.patch) {
        std.debug.print(
            "Your zig version ({d}.{d}.{d}) is not compatible with the one used in zenvars: {d}.{d}.{d}\n",
            .{
                builtin.zig_version.major,
                builtin.zig_version.minor,
                builtin.zig_version.patch,
                zig_version.major,
                zig_version.minor,
                zig_version.patch,
            },
        );
        std.process.exit(1);
    }

    // Zenvars
    const lib_mod = b.addModule("zenvars", .{
        .root_source_file = b.path("zenvars.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Examples
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("zenvars", lib_mod);

    const exe = b.addExecutable(.{
        .name = "zenvars",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{ .root_module = lib_mod });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
