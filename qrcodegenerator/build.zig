const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

    const c_mod = translate_c.createModule();

    const exe = b.addExecutable(.{
        .name = "qrcodegenerator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "c",
                    .module = c_mod,
                },
            },
        }),
    });

    const lexopts = b.dependency("lexopts", .{});
    exe.root_module.addImport("lexopts", lexopts.module("lexopts"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);

    const mode_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/modes.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(mode_tests).step);

    const encode_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/encode.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = c_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(encode_tests).step);

    const kanji_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/modeEncode/kanji.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "c", .module = c_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(kanji_tests).step);

    const numeric_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/modeEncode/numerical.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(numeric_tests).step);

    const alphanumeric_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/modeEncode/alphanumerical.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(alphanumeric_tests).step);

    const byte_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/modeEncode/byte.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(byte_tests).step);
}
