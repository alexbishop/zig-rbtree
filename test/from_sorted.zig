const std = @import("std");
const rbtreelib = @import("rbtree");

pub const DefaultRBTreeUnmanaged = rbtreelib.DefaultRBTreeUnmanaged;
const Tree = DefaultRBTreeUnmanaged(u32, void);
const Node = Tree.Node;

fn getBlackDepth(node: ?*Node) !usize {
    if (node) |n| {
        const left_depth = try getBlackDepth(n.left);
        const right_depth = try getBlackDepth(n.right);

        if (left_depth != right_depth) return error.BlackViolation;

        if (n.getColor() == .red) {
            if (n.left) |l| {
                if (l.getColor() == .red) return error.RedViolation;
            }
            if (n.right) |r| {
                if (r.getColor() == .red) return error.RedViolation;
            }
        }
        return left_depth;
    } else {
        return 0;
    }
}
fn checkMatchesSlice(node: ?*Node, slice: []const u32) bool {
    var current_node = node;
    for (slice) |item| {
        if (item != current_node.?.key) return false;
        current_node = current_node.?.next();
    }
    if (current_node != null) return false;
    return true;
}

fn printTree(node: ?*Node) void {
    if (node) |n| {
        std.debug.print("({},", .{n.key});
        printTree(n.left);
        std.debug.print(",", .{});
        printTree(n.right);
        std.debug.print(")", .{});
    } else {
        std.debug.print("?", .{});
    }
}

test "from sorted slice" {
    var test_slice: [1024]u32 = undefined;
    const allocator = std.testing.allocator;

    for (test_slice[0..], 0..) |*item, i| item.* = @intCast(i);
    // at this point test_slice = .{0, 1, 2, ...}

    // run our tests
    for (0..(test_slice.len)) |l| {
        var tree = try Tree.initFromSortedSlice(allocator, test_slice[0..l]);
        defer tree.deinit(allocator);

        _ = try getBlackDepth(tree.root);
        std.debug.assert(checkMatchesSlice(tree.findMin(), test_slice[0..l]));
    }
}
