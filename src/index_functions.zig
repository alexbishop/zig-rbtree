//! A collection of function which operate on red-black trees that store a subtree size
//! in each node.
//!
//! You can turn this feature on in the `Options` provided to the function
//! `RBTree`, `RBTreeUnmanaged` or `RBTreeImplementation`
const rbtreelib = @import("./rbtree.zig");
const rbnode = @import("./rb_node.zig");

// These are used for the documentation, in particular, so that the
// links in the namespace documentation actually work
const RBTree = rbtreelib.RBTree;
const RBTreeUnmanaged = rbtreelib.RBTreeUnmanaged;
const RBTreeImplementation = rbtreelib.RBTreeImplementation;
const Options = rbtreelib.Options;

const std = @import("std");
const Order = std.math.Order;

/// Gives a compile error if the given type was not created by
/// `Node` with subtree sizes
fn assertNodeType(comptime Node: type) void {
    if (rbtreelib.isNode(Node)) {
        if (comptime Node.args.options.SubtreeSize == void) {
            @compileError("This function requires that the tree stores the subtree sizes");
        }
    } else {
        @compileError("The given type 'Node' does not describe a node in a red-black tree");
    }
}

fn assertTreeType(comptime Tree: type) void {
    if (rbtreelib.getTreeType(Tree) != null) {
        if (comptime Tree.args.options.SubtreeSize == void) {
            @compileError("This function requires that the tree stores the subtree sizes");
        }
    } else {
        @compileError("The given type 'Tree' does not describe a red-black tree");
    }
}

/// Gets the index of a given node in its associated tree.
///
/// Note that the node has to be a part of a valid red-black tree, and that
/// the nodes in this tree must store a subtree size.
pub fn getNodeIndex(
    comptime Node: type,
    node: *const Node,
) usize {
    comptime assertNodeType(Node);

    var total: usize = 0;
    var parent: ?*Node = node.getParent();
    var direction: ?rbnode.Direction = node.getDirection();

    if (node.left) |left| {
        total = @intCast(left.subtree_size);
    }

    while (parent) |p| {
        // if you have a parent, you have a direction
        if (direction.? == .right) {
            total += 1;
            if (p.left) |left| {
                total += @intCast(left.subtree_size);
            }
        }

        parent = p.getParent();
        direction = p.getDirection();
    }

    return total;
}

test getNodeIndex {
    var array: [128]u16 = undefined;
    for (&array, 0..) |*item, i| item.* = @intCast(i);

    const Tree = rbtreelib.RBTree(
        u16,
        void,
        void,
        rbtreelib.defaultOrder(u16),
        .{
            .SubtreeSize = u16,
        },
        .{},
    );

    var tree = try Tree.initFromSortedSlice(
        std.testing.allocator,
        undefined,
        &array,
    );
    defer tree.deinit();

    // tree now contains the values 0..128
    // where key i is at index i

    var node = tree.findMin();
    while (node) |n| : (node = n.next()) {
        const index = getNodeIndex(Tree.Node, n);
        try std.testing.expect(index == n.key);
    }
}

/// Gets the index at which a key appears as part of a red-black tree.
///
/// This function also returns the node to which the key belongs.
///
/// Note that the tree must store a subtree size.
pub fn getKeyIndex(
    comptime Tree: type,
    root: *Tree.Node,
    ctx: Tree.args.Context,
    key: Tree.args.K,
) ?struct {
    node: *Tree.Node,
    index: usize,
} {
    comptime assertTreeType(Tree);
    const Node = Tree.Node;

    var current: ?*Node = root;
    var index: usize = 0;

    while (current) |c| {
        const cmp = Tree.args.order(ctx, key, c.key);

        switch (cmp) {
            Order.eq => {
                if (c.left) |left| {
                    index += @intCast(left.subtree_size);
                }
                return .{
                    .node = c,
                    .index = index,
                };
            },
            Order.lt => current = c.left,
            Order.gt => {
                if (c.left) |left| {
                    index += @intCast(left.subtree_size);
                }
                index += 1;
                current = c.right;
            },
        }
    }

    return null;
}

test getKeyIndex {
    var array: [128]u16 = undefined;
    for (&array, 0..) |*item, i| item.* = @intCast(i);

    const Tree = rbtreelib.RBTree(
        u16,
        void,
        void,
        rbtreelib.defaultOrder(u16),
        .{
            .SubtreeSize = u16,
        },
        .{},
    );

    var tree = try Tree.initFromSortedSlice(
        std.testing.allocator,
        undefined,
        &array,
    );
    defer tree.deinit();

    // tree now contains the values 0..128
    // where key i is at index i

    for (array) |i| {
        const result = getKeyIndex(Tree, tree.getRoot().?, void{}, i);
        try std.testing.expect(result != null);
        try std.testing.expect(result.?.index == i);
    }

    const not_in_tree = getKeyIndex(Tree, tree.getRoot().?, void{}, 1000);
    try std.testing.expect(not_in_tree == null);
}

/// Retrieves a node at a given index of the tree.
///
/// Note that the node has to be a part of a valid red-black tree, and that
/// the nodes in this tree must store a subtree size.
pub fn getNodeAtIndex(
    comptime Node: type,
    root: *Node,
    index: usize,
) ?*Node {
    comptime assertNodeType(Node);

    var relative_index: usize = index;
    var current: *Node = root;

    while (relative_index < current.subtree_size) {
        if (relative_index == 0) return current.getLeftmostInSubtree();

        if (current.left) |left| {
            if (relative_index < left.subtree_size) {
                current = left;
                continue;
            } else {
                relative_index -= left.subtree_size;
            }
        }

        if (relative_index == 0) return current;
        relative_index -= 1;

        if (current.right) |right| {
            current = right;
        } else {
            return null;
        }
    }

    return null;
}

test getNodeAtIndex {
    var array: [128]u16 = undefined;
    for (&array, 0..) |*item, i| item.* = @intCast(i);

    const Tree = rbtreelib.RBTree(
        u16,
        void,
        void,
        rbtreelib.defaultOrder(u16),
        .{
            .SubtreeSize = u16,
        },
        .{},
    );

    var tree = try Tree.initFromSortedSlice(
        std.testing.allocator,
        undefined,
        &array,
    );
    defer tree.deinit();

    // tree now contains the values 0..128
    // where key i is at index i

    for (array) |i| {
        const node = getNodeAtIndex(Tree.Node, tree.getRoot().?, i);
        try std.testing.expect(node != null);
        try std.testing.expect(node.?.key == i);
    }

    const not_in_tree = getNodeAtIndex(Tree.Node, tree.getRoot().?, 1000);
    try std.testing.expect(not_in_tree == null);
}
