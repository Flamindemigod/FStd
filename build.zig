const std = @import("std");
pub fn makeExample(b: *std.Build, path: []const u8, name: []const u8) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path(path),
    });
    exe.root_module.addImport("FStd", lib.root_module);
    return exe;
}

var target: std.Build.ResolvedTarget = undefined;
var optimize: std.builtin.OptimizeMode = undefined;
var lib: *std.Build.Step.Compile = undefined;
pub fn build(b: *std.Build) void {
    target = b.standardTargetOptions(.{});

    optimize = b.standardOptimizeOption(.{});
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib = b.addLibrary(.{
        .linkage = .static,
        .name = "FStd",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const sdl = makeExample(b, "examples/sdl3-kyoto.zig", "sdl3-kyoto");
    sdl.linkSystemLibrary("SDL3");
    sdl.linkLibC();
    b.installArtifact(sdl);

    const counter = makeExample(b, "examples/counter-kyoto.zig", "counter-kyoto");
    b.installArtifact(counter);

    const chaining = makeExample(b, "examples/chaining-kyoto.zig", "chaining-kyoto");
    b.installArtifact(chaining);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    _ = b.addModule("FStd", .{
        .root_source_file = b.path("./src/root.zig"),
    });
}
