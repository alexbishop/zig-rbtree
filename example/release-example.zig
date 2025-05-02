const std = @import("std");
const rbtreelib = @import("rbtree");

pub const DefaultRBTree = rbtreelib.DefaultRBTree;

var use_testing_allocator: bool = false;
var enable_print: bool = true;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator =
        if (use_testing_allocator)
            std.testing.allocator
        else
            gpa.allocator();

    const Tree = DefaultRBTree(i32, f32);

    var tree = Tree.init(allocator, void{});
    defer tree.deinit();

    // insert some stuff into the tree
    var index: i32 = -19;
    while (index < 20) : (index += 1) {
        const value = std.math.pow(
            f32,
            0.5,
            @floatFromInt(index),
        );
        try tree.put(index, value);
    }

    // print the contents of the tree
    {
        if (enable_print) std.debug.print("First print\n", .{});
        var current: ?*Tree.Node = tree.findMin();
        while (current) |c| : (current = c.next()) {
            if (enable_print) std.debug.print("Node {} -> {}\n", .{ c.key, c.value });
        }
    }

    // remove some entries from the tree
    _ = tree.remove(7);
    _ = tree.remove(3);
    _ = tree.remove(5);

    // print it again
    {
        if (enable_print) std.debug.print("\nSecond print\n", .{});
        var current: ?*Tree.Node = tree.findMin();
        while (current) |c| : (current = c.next()) {
            if (enable_print) std.debug.print("Node {} -> {}\n", .{ c.key, c.value });
        }
    }
}

test {
    // turn off the debug functions for this test
    use_testing_allocator = true;
    enable_print = false;
    // run the test
    try main();
}
