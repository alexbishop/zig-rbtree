const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // the purpose of this library is to export this module
    const module = b.addModule(
        "rbtree",
        .{
            .root_source_file = b.path("src/rbtree.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    // this is the step to which we will attach all of our tests as follows
    const test_step = b.step("test", "Run library tests");

    //---------------------------------------------------------
    // Add every zig file under src, test and example as a test
    //---------------------------------------------------------
    //
    // To execute all of these tests, run the command
    //
    //      zig build test --summary all
    //
    for ([_][]const u8{ "src", "test", "example" }) |search_dir| {
        const dir = try b.build_root.join(b.allocator, &.{search_dir});
        defer b.allocator.free(dir);

        var open_dir = try std.fs.cwd().openDir(dir, .{ .iterate = true });
        defer open_dir.close();

        var walker = try open_dir.walk(b.allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            const full_path = b.pathJoin(&.{ search_dir, entry.path });
            if (!std.mem.endsWith(u8, full_path, ".zig")) continue;

            const test_name: []u8 = b.dupe(full_path[0..(full_path.len - 4)]);
            std.mem.replaceScalar(u8, test_name, '\\', '.');
            std.mem.replaceScalar(u8, test_name, '/', '.');

            const some_test = b.addTest(.{
                .name = test_name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(full_path),
                    .target = target,
                }),
            });
            some_test.root_module.addImport("rbtree", module);
            const run_some_test = b.addRunArtifact(some_test);
            test_step.dependOn(&run_some_test.step);
        }
    }

    //-----------------------------------------------------
    // Generate the documentation
    //-----------------------------------------------------
    //
    {
        const rbtree_docs_lib = b.addLibrary(.{
            .name = "rbtree",
            .root_module = module,
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
