//! A basic implementation of an augmented red-black tree where each node holds
//! the maximum value of its subtree
//!
//! Note: this implementation is not optimal.
const std = @import("std");
const Order = std.math.Order;

const rbtreelib = @import("rbtree");

fn MaxSubtreeCallbacks(Tree: type) @TypeOf(Tree.args.augmented_callbacks) {
    const Context = Tree.args.Context;
    const Node = Tree.Node;
    const Direction = Tree.Direction;

    const callbacks = struct {
        pub fn afterRotate(
            _: Context,
            _: *Node,
            new_subtree_root: *Node,
            _: Direction,
        ) void {
            if (new_subtree_root.left) |c| {
                if (c.right) |r| {
                    c.additional_data = r.additional_data;
                } else {
                    c.additional_data = c.key;
                }
            }

            if (new_subtree_root.right) |c| {
                if (c.right) |r| {
                    c.additional_data = r.additional_data;
                } else {
                    c.additional_data = c.key;
                }
            }

            if (new_subtree_root.right) |r| {
                new_subtree_root.additional_data = r.additional_data;
            } else {
                new_subtree_root.additional_data = new_subtree_root.key;
            }
        }

        pub fn afterLink(
            _: Context,
            new_node: *Node,
        ) void {
            new_node.additional_data = new_node.key;

            var current: *Node = new_node;
            while (current.getDirection() == .right) {
                const parent = current.getParent().?;
                parent.additional_data = current.additional_data;
                current = parent;
            }
        }

        pub fn beforeUnlink(
            _: Context,
            node: *Node,
        ) void {
            var current: ?*Node = node.getParent();

            if (node.getDirection() == Direction.right) {
                // this node may cause problems
                const c = current.?;
                c.additional_data = c.key;
                current = c.getParent();
            }

            while (current) |c| : (current = c.getParent()) {
                if (c.right) |r| {
                    c.additional_data = r.additional_data;
                } else {
                    c.additional_data = c.key;
                }
            }
        }
    };

    return .{
        .afterRotate = callbacks.afterRotate,
        .afterLink = callbacks.afterLink,
        .beforeUnlink = callbacks.beforeUnlink,
    };
}

pub fn Implementation(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    comptime options: rbtreelib.Options,
) type {
    const patched_options = brk: {
        var tmp = options;
        tmp.AdditionalNodeData = K;
        break :brk tmp;
    };

    const PreTree = rbtreelib.RBTreeImplementation(
        K,
        V,
        Context,
        order,
        patched_options,
        .{},
    );

    const callbacks = MaxSubtreeCallbacks(PreTree);

    return rbtreelib.RBTreeImplementation(
        K,
        V,
        Context,
        order,
        patched_options,
        callbacks,
    );
}

pub fn Unmanaged(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    comptime options: rbtreelib.Options,
) type {
    const patched_options = brk: {
        var tmp = options;
        tmp.AdditionalNodeData = K;
        break :brk tmp;
    };

    const PreTree = rbtreelib.RBTreeUnmanaged(
        K,
        V,
        Context,
        order,
        patched_options,
        .{},
    );

    const callbacks = MaxSubtreeCallbacks(PreTree);

    return rbtreelib.RBTreeUnmanaged(
        K,
        V,
        Context,
        order,
        patched_options,
        callbacks,
    );
}

pub fn Managed(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    comptime options: rbtreelib.Options,
) type {
    const patched_options = brk: {
        var tmp = options;
        tmp.AdditionalNodeData = K;
        break :brk tmp;
    };

    const PreTree = rbtreelib.RBTree(
        K,
        V,
        Context,
        order,
        patched_options,
        .{},
    );

    const callbacks = MaxSubtreeCallbacks(PreTree);

    return rbtreelib.RBTree(
        K,
        V,
        Context,
        order,
        patched_options,
        callbacks,
    );
}

const testing = std.testing;

/// Gets the maximum value in a subtree, or throws an error if the
/// the `additional_data` variable is not correctly set for this subtree
fn getSubtreeMax(comptime Node: type, root: *Node) !(Node.args.K) {
    if (root.left) |l| {
        _ = try getSubtreeMax(Node, l);
    }

    const rightMax: ?Node.args.K = if (root.right) |r| try getSubtreeMax(Node, r) else null;

    if (rightMax) |m| {
        try testing.expectEqual(root.additional_data, m);
        return m;
    } else {
        try testing.expectEqual(root.additional_data, root.key);
        return root.key;
    }
}

test "max_subtrees" {
    const allocator = testing.allocator;

    const Tree = Managed(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
    );

    var tree = Tree.init(allocator, void{});
    defer tree.deinit();

    // The following two arrays contain permutations of the interval [-100,100]
    // In the second array, one entry is left out.
    const entries = [_]i32{
        -62, -33, -16, 93,  19,  54,  55,   -39, 20,  99,  60,  -38, -54, 11,  -70, -19, 14,
        58,  90,  -34, 31,  85,  -64, 97,   71,  -79, 66,  -5,  16,  9,   4,   80,  68,  -58,
        37,  -61, 28,  -43, -20, 65,  -92,  -28, -60, -90, 8,   -45, 6,   42,  30,  -56, -63,
        63,  -51, 70,  -78, -68, -21, -10,  84,  87,  -4,  -83, 18,  -49, 98,  69,  -67, 94,
        81,  -50, 2,   -82, -75, 78,  95,   21,  -32, 27,  -27, -18, -2,  -29, -76, -89, -85,
        -35, -42, -72, 48,  5,   -7,  -73,  -95, 50,  -84, 34,  -97, 96,  13,  -93, -23, -98,
        36,  41,  75,  -37, -41, -65, -100, -11, -25, 12,  57,  89,  25,  -94, -81, -96, 74,
        53,  22,  -14, -8,  32,  23,  17,   -44, 26,  -57, 0,   51,  49,  24,  7,   40,  -26,
        44,  -99, 38,  -91, 45,  43,  -1,   92,  15,  -24, -17, 61,  -52, -86, -47, -9,  -6,
        -36, -74, 39,  10,  91,  -22, 1,    3,   29,  -48, -87, -53, 33,  -66, 47,  56,  62,
        100, 35,  -71, -55, 67,  73,  -80,  72,  83,  64,  86,  52,  -15, -69, -31, -77, 82,
        88,  -3,  -13, -46, 46,  -40, 76,   -12, -30, 77,  -59, 59,  79,  -88,
    };
    const entries2 = [_]i32{
        93,  -11, 82,  76,  2,   -51, 78,  40,  -62, 18,  100, -61, -80, -96,  55,  79,
        -9,  52,  22,  -91, 28,  12,  81,  20,  47,  24,  58,  -89, 86,  -10,  -38, -5,
        37,  -12, -79, -60, 39,  13,  -70, -64, 88,  -6,  96,  99,  8,   -100, -24, 80,
        44,  -37, 41,  -56, -95, 60,  38,  -86, 59,  -48, 15,  -29, 68,  6,    -17, 94,
        -57, 97,  23,  -45, -65, -50, -98, -99, 45,  89,  -81, -72, 69,  -41,  74,  -7,
        -74, 84,  -90, -53, -31, 43,  -16, -58, 1,   16,  -20, -39, 25,  -4,   -77, 77,
        -55, 14,  73,  87,  -85, 95,  -97, -78, -14, -19, -43, -3,  57,  27,   3,   -42,
        0,   -23, 75,  31,  4,   -67, 85,  -8,  54,  -25, 72,  -88, -35, 64,   42,  -84,
        -21, -54, -83, 9,   -66, 26,  61,  19,  -1,  32,  71,  66,  -34, 98,   11,  -73,
        48,  -93, 30,  -33, 51,  -32, -69, 29,  62,  -49, -71, -30, 36,  5,    7,   -40,
        -82, -47, 35,  90,  -59, -15, -94, -27, -36, -22, -13, 53,  17,  91,   50,  67,
        33,  -44, -26, 56,  92,  -75, 34,  -2,  10,  -87, 70,  49,  -76, -46,  -28, -63,
        21, -52, 83, -92, -68, 63, 65, -18, // 46,
    };

    for (entries) |e| {
        try tree.add(e);
        _ = try getSubtreeMax(Tree.Node, tree.managed.root.?);
    }
    for (entries2) |e| {
        _ = tree.remove(e);
        _ = try getSubtreeMax(Tree.Node, tree.managed.root.?);
    }
}
