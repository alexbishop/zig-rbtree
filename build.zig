const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule(
        "rbtree",
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    const test_step = b.step("test", "Run library tests");

    // tests under the ./test directory
    {
        const main_tests = b.addTest(.{
            .root_source_file = b.path("test/test.zig"),
            .target = target,
            .optimize = optimize,
        });
        main_tests.root_module.addImport("rbtree", module);
        const run_main_tests = b.addRunArtifact(main_tests);
        test_step.dependOn(&run_main_tests.step);
    }

    // tests under the `./example` directory
    {
        const example_tests = b.addTest(.{
            .root_source_file = b.path("example/augmented_example.zig"),
            .target = target,
            .optimize = optimize,
        });
        example_tests.root_module.addImport("rbtree", module);
        const run_example_tests = b.addRunArtifact(example_tests);
        test_step.dependOn(&run_example_tests.step);
    }

    // generate docs
    {
        const rbtree_docs_lib = b.addStaticLibrary(.{
            .name = "rbtreelib",
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        });
        const docs_step = b.step("docs", "Emit docs");
        const docs_install = b.addInstallDirectory(.{
            .install_dir = .prefix,
            .install_subdir = "docs",
            .source_dir = rbtree_docs_lib.getEmittedDocs(),
        });
        docs_step.dependOn(&docs_install.step);
    }
}
