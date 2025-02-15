// This file was derived from `rb_tree_tests.py` in the repo
//   https://github.com/stanislavkozlovski/Red-Black-Tree
//   
// Many of the comments contained in this file are also derived from there.
//
const std = @import("std");
const Order = std.math.Order;
const testing = std.testing;

const rbtreelib = @import("rbtree");

pub const RBTree = rbtreelib.RBTree;
pub const RBTreeUnmanaged = rbtreelib.RBTreeUnmanaged;
pub const RBTreeImplementation = rbtreelib.RBTreeImplementation;

fn checkTreeEqual(tree: anytype, expected_values: anytype) !void {
    var current = tree.findMin();
    var index: usize = 0;

    while (current) |c| : ({
        index += 1;
        current = c.next();
    }) {
        try testing.expect(c.key == expected_values[index]);
    }

    try testing.expect(index == expected_values.len);
}

test "find_node" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    var allocator = testing.allocator;

    // Use the tree we get from the test_build function
    // and test the find function on each node
    var rb_tree = Tree.init();

    const node_2 = (try rb_tree.insert(allocator, 2, void{}, .no_clobber)).node;
    defer allocator.destroy(node_2);
    const hopefully_node_2 = rb_tree.root.?;
    const node_1 = (try rb_tree.insert(allocator, 1, void{}, .no_clobber)).node;
    defer allocator.destroy(node_1);
    const hopefully_node_1 = rb_tree.root.?.left.?;
    const node_4 = (try rb_tree.insert(allocator, 4, void{}, .no_clobber)).node;
    defer allocator.destroy(node_4);
    const hopefully_node_4 = rb_tree.root.?.right.?;
    const node_5 = (try rb_tree.insert(allocator, 5, void{}, .no_clobber)).node;
    defer allocator.destroy(node_5);
    const hopefully_node_5 = hopefully_node_4.right.?;
    const node_9 = (try rb_tree.insert(allocator, 9, void{}, .no_clobber)).node;
    defer allocator.destroy(node_9);
    const hopefully_node_9 = hopefully_node_5.right.?;
    const node_3 = (try rb_tree.insert(allocator, 3, void{}, .no_clobber)).node;
    defer allocator.destroy(node_3);
    const hopefully_node_3 = hopefully_node_4.left.?;
    const node_6 = (try rb_tree.insert(allocator, 6, void{}, .no_clobber)).node;
    defer allocator.destroy(node_6);
    const hopefully_node_6 = hopefully_node_9.left.?;
    const node_7 = (try rb_tree.insert(allocator, 7, void{}, .no_clobber)).node;
    defer allocator.destroy(node_7);
    const hopefully_node_7 = hopefully_node_5.right.?;
    const node_15 = (try rb_tree.insert(allocator, 15, void{}, .no_clobber)).node;
    defer allocator.destroy(node_15);
    const hopefully_node_15 = hopefully_node_9.right.?;

    //
    //       ___5B___
    //   __2R__      7R
    // 1B     4B    6B 9B
    //       3R         15R
    //
    // valid cases
    try testing.expectEqual(rb_tree.find(5), hopefully_node_5);
    try testing.expectEqual(rb_tree.find(2), hopefully_node_2);
    try testing.expectEqual(rb_tree.find(1), hopefully_node_1);
    try testing.expectEqual(rb_tree.find(4), hopefully_node_4);
    try testing.expectEqual(rb_tree.find(3), hopefully_node_3);
    try testing.expectEqual(rb_tree.find(7), hopefully_node_7);
    try testing.expectEqual(rb_tree.find(6), hopefully_node_6);
    try testing.expectEqual(rb_tree.find(9), hopefully_node_9);
    try testing.expectEqual(rb_tree.find(15), hopefully_node_15);
    // invalid cases
    try testing.expectEqual(rb_tree.find(-1), null);
    try testing.expectEqual(rb_tree.find(52454225), null);
    try testing.expectEqual(rb_tree.find(0), null);
    try testing.expectEqual(rb_tree.find(401), null);
    // try testing.expectEqual(rb_tree.find(3.00001), null);
}
test "recoloring_only" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // Create a red-black tree, add a red node such that we only have to recolor
    // upwards twice
    // add 4, which recolors 2 and 8 to BLACK,
    //         6 to RED
    //             -10, 20 to BLACK
    // :return:
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null });

    // LEFT SUBTREE

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .red, .parent = root });

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .black, .parent = node_m10 });

    const node_8 = try allocator.create(Node);
    defer allocator.destroy(node_8);
    node_8.* = Node.init(.{ .key = 8, .color = .red, .parent = node_6, .left = null, .right = null });

    const node_2 = try allocator.create(Node);
    defer allocator.destroy(node_2);
    node_2.* = Node.init(.{ .key = 2, .color = .red, .parent = node_6, .left = null, .right = null });

    node_6.left = node_2;
    node_6.right = node_8;

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m20;
    node_m10.right = node_6;

    // RIGHT SUBTREE

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .red, .parent = root });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .black, .parent = node_20, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .black, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;
    node_20.right = node_25;

    root.left = node_m10;
    root.right = node_20;

    var rb_tree: Tree = .{ .root = root, .size = 9 };
    const node_4 = (try rb_tree.insert(allocator, 4, void{}, .no_clobber)).node;
    defer allocator.destroy(node_4);

    //
    //                  _____10B_____                                     _____10B_____
    //             __-10R__        __20R__                           __-10R__        __20R__
    //          -20B      6B     15B     25B  --FIRST RECOLOR-->  -20B      6R     15B     25B
    //                  2R  8R                                            2B  8B
    //             Add-->4R                                                4R
    //
    //
    //
    //                                _____10B_____
    //                           __-10B__        __20B__
    // --SECOND RECOLOR-->    -20B      6R     15B     25B
    //                                2B  8B
    //                                 4R
    //

    // This should trigger two recolors.
    // 2 and 8 should turn to black,
    // 6 should turn to red,
    // -10 and 20 should turn to black
    // 10 should try to turn to red, but since it's the root it can't be black
    try checkTreeEqual(rb_tree, [_]i32{ -20, -10, 2, 4, 6, 8, 10, 15, 20, 25 });

    try testing.expect(node_2.getColor() == .black);
    try testing.expect(node_8.getColor() == .black);
    try testing.expect(node_6.getColor() == .red);
    try testing.expect(node_m10.getColor() == .black);
    try testing.expect(node_20.getColor() == .black);
}
test "recoloring_two" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .red, .parent = root, .left = null, .right = null });

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m10, .left = null, .right = null });

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m20;
    node_m10.right = node_6;

    // right subtree

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .red, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .black, .parent = node_20, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .black, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;
    node_20.right = node_25;

    const node_12 = try allocator.create(Node);
    defer allocator.destroy(node_12);
    node_12.* = Node.init(.{ .key = 12, .color = .red, .parent = node_15, .left = null, .right = null });

    const node_17 = try allocator.create(Node);
    defer allocator.destroy(node_17);
    node_17.* = Node.init(.{ .key = 17, .color = .red, .parent = node_15, .left = null, .right = null });

    node_15.left = node_12;
    node_15.right = node_17;

    root.left = node_m10;
    root.right = node_20;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    const node_19 = (try rb_tree.insert(allocator, 19, void{}, .no_clobber)).node;
    defer allocator.destroy(node_19);

    //
    //
    //          _____10B_____                                        _____10B_____
    //     __-10R__        __20R__                              __-10R__        __20R__
    //  -20B      6B     15B     25B     FIRST RECOLOR-->    -20B      6B     15R     25B
    //                12R  17R                                             12B  17B
    //                 Add-->19R                                                 19R
    //
    //
    // SECOND RECOLOR
    //
    //
    //         _____10B_____
    //    __-10B__        __20B__
    // -20B      6B     15R     25B
    //               12B  17B
    //                     19R
    //
    try checkTreeEqual(rb_tree, [_]i32{ -20, -10, 6, 10, 12, 15, 17, 19, 20, 25 });

    const hopefully_node_19 = node_17.right.?;
    try testing.expectEqual(hopefully_node_19.key, 19);
    try testing.expect(hopefully_node_19.getColor() == .red);
    try testing.expectEqual(hopefully_node_19.getParent(), node_17);

    try testing.expect(node_17.getColor() == .black);
    try testing.expect(node_12.getColor() == .black);
    try testing.expect(node_15.getColor() == .red);
    try testing.expect(node_20.getColor() == .black);
    try testing.expect(node_25.getColor() == .black);
    try testing.expect(node_m10.getColor() == .black);
    // FIX:
    // our implementation fails the following test:
    //
    //      try testing.expect(rb_tree.root.?.getColor() == .black);
    //
    // The reason for this is that our implementation trys to make the root red whenever it can.
    // The coloring of the root is still valid as we can verify as follows
    try testing.expect(rb_tree.root.?.getColor() == .red);
    try testing.expect(rb_tree.root.?.left.?.getColor() == .black);
    try testing.expect(rb_tree.root.?.right.?.getColor() == .black);
}
test "right_rotation" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null });

    // LEFT SUBTREE

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .red, .parent = node_m10, .left = null, .right = null });

    node_m10.right = node_7;

    // RIGHT SUBTREE

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;

    root.left = node_m10;
    root.right = node_20;

    var rb_tree: Tree = .{ .root = root, .size = 5 };
    const node_13 = (try rb_tree.insert(allocator, 13, void{}, .no_clobber)).node;
    defer allocator.destroy(node_13);

    //
    //     ____10B____                                           ____10B____
    // -10B          20B       --(LL -> R) RIGHT ROTATE-->    -10B         15B
    //    7R       15R                                           7R      13R 20R
    //    Add -> 13R
    //
    try checkTreeEqual(rb_tree, [_]i32{ -10, 7, 10, 13, 15, 20 });

    const hopefully_node_20 = node_15.right.?;
    const hopefully_node_13 = node_15.left.?;

    try testing.expect(node_15.getColor() == .black);
    try testing.expectEqual(node_15.getParent().?.key, 10);

    try testing.expectEqual(hopefully_node_20.key, 20);
    try testing.expect(hopefully_node_20.getColor() == .red);
    try testing.expectEqual(hopefully_node_20.getParent().?.key, 15);
    try testing.expectEqual(hopefully_node_20.left, null);
    try testing.expectEqual(hopefully_node_20.right, null);

    try testing.expectEqual(hopefully_node_13.key, 13);
    try testing.expect(hopefully_node_13.getColor() == .red);
    try testing.expectEqual(hopefully_node_13.getParent().?.key, 15);
    try testing.expectEqual(hopefully_node_13.left, null);
    try testing.expectEqual(hopefully_node_13.right, null);
}
test "left_rotation_no_sibling" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // LEFT SUBTREE

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .black, .parent = root, .left = null, .right = null });

    const node_8 = try allocator.create(Node);
    defer allocator.destroy(node_8);
    node_8.* = Node.init(.{ .key = 8, .color = .red, .parent = node_7, .left = null, .right = null });

    node_7.right = node_8;

    // RIGHT SUBTREE

    const rightest = try allocator.create(Node);
    defer allocator.destroy(rightest);
    rightest.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    root.left = node_7;
    root.right = rightest;

    var rb_tree: Tree = .{ .root = root, .size = 4 };
    const node_9 = (try rb_tree.insert(allocator, 9, void{}, .no_clobber)).node;
    defer allocator.destroy(node_9);

    //
    //          -->     10B                                10B
    // ORIGINAL -->  7B    20B  --LEFT ROTATION-->       8B   20B
    //          -->    8R                              7R  9R
    //          -->     9R
    // We add 9, which is the right child of 8 and causes a red-red relationship
    // this calls for a left rotation, so 7 becomes left child of 8 and 9 the right child of 8
    // 8 is black, 7 and 9 are red
    //
    try checkTreeEqual(rb_tree, [_]i32{ 7, 8, 9, 10, 20 });

    const hopefully_node_9 = node_8.right.?;

    try testing.expectEqual(hopefully_node_9.key, 9);
    try testing.expect(hopefully_node_9.getColor() == .red);
    try testing.expectEqual(hopefully_node_9.getParent().?.key, 8);
    try testing.expectEqual(hopefully_node_9.left, null);
    try testing.expectEqual(hopefully_node_9.right, null);

    try testing.expectEqual(node_8.getParent().?.key, 10);
    try testing.expect(node_8.getColor() == .black);
    try testing.expectEqual(node_8.left.?.key, 7);
    try testing.expectEqual(node_8.right.?.key, 9);

    try testing.expect(node_7.getColor() == .red);
    try testing.expectEqual(node_7.getParent().?.key, 8);
    try testing.expectEqual(node_7.left, null);
    try testing.expectEqual(node_7.right, null);
}
test "right_rotation_no_sibling_left_subtree" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // LEFT SUBTREE

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    const node_m11 = try allocator.create(Node);
    defer allocator.destroy(node_m11);
    node_m11.* = Node.init(.{ .key = -11, .color = .red, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m11;
    // RIGHT SUBTREE

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;

    root.left = node_m10;
    root.right = node_20;
    var rb_tree: Tree = .{ .root = root, .size = 5 };
    const node_m12 = (try rb_tree.insert(allocator, -12, void{}, .no_clobber)).node;
    defer allocator.destroy(node_m12);

    //
    //
    //
    //                     ____10____                                       ____10____
    //                __-10B__     20B  (LL->R) Right rotate-->          -11B        20B
    //            -11R          15R                                   -12R  -10R   15R
    //   Add--> 12R
    //
    //
    //
    // red-red relationship with -11 -12, so we do a right rotation where -12 becomes the left child of -11,
    //                                                                     -10 becomes the right child of -11
    // -11's parent is root, -11 is black, -10,-12 are RED
    //
    try checkTreeEqual(rb_tree, [_]i32{ -12, -11, -10, 10, 15, 20 });

    const hopefully_node_m12 = node_m11.left.?;
    try testing.expectEqual(rb_tree.root.?.left.?.key, -11);

    try testing.expectEqual(hopefully_node_m12.key, -12);
    try testing.expect(hopefully_node_m12.getColor() == .red);
    try testing.expectEqual(hopefully_node_m12.getParent().?.key, -11);
    try testing.expectEqual(hopefully_node_m12.left, null);
    try testing.expectEqual(hopefully_node_m12.right, null);

    try testing.expect(node_m11.getColor() == .black);
    try testing.expectEqual(node_m11.getParent(), rb_tree.root);
    try testing.expectEqual(node_m11.left.?.key, -12);
    try testing.expectEqual(node_m11.right.?.key, -10);

    try testing.expect(node_m10.getColor() == .red);
    try testing.expectEqual(node_m10.getParent().?.key, -11);
    try testing.expectEqual(node_m10.left, null);
    try testing.expectEqual(node_m10.right, null);
}
test "left_right_rotation_no_sibling" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // LEFT PART

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .red, .parent = node_m10, .left = null, .right = null });

    node_m10.right = node_7;

    // RIGHT PART

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;

    root.left = node_m10;
    root.right = node_20;

    var rb_tree: Tree = .{ .root = root, .size = 5 };
    const node_17 = (try rb_tree.insert(allocator, 17, void{}, .no_clobber)).node;
    defer allocator.destroy(node_17);

    //
    //             ___10___                                                     ____10____
    //          -10B      20B                                                -10B        20B
    //             7R   15R        --(LR=>RL) Left Rotate (no recolor) -->      7R     17R
    //             Add--> 17R                                                         15R
    //
    //
    //
    //                                         ____10____
    // Right Rotate (with recolor) -->      -10B        17B
    //                                         7R     15R 20R
    //
    // 15-17 should do a left rotation so 17 is now the parent of 15.
    // Then, a right rotation should be done so 17 is the parent of 20(15's prev parent)
    // Also, a recoloring should be done such that 17 is now black and his children are red
    //
    try checkTreeEqual(rb_tree, [_]i32{ -10, 7, 10, 15, 17, 20 });

    const hopefully_node_15 = node_15;
    const hopefully_node_20 = node_20;
    const hopefully_node_17 = hopefully_node_15.getParent().?;
    try testing.expectEqual(rb_tree.root.?.right, hopefully_node_17);

    try testing.expectEqual(hopefully_node_17.key, 17);
    try testing.expect(hopefully_node_17.getColor() == .black);
    try testing.expectEqual(hopefully_node_17.getParent(), rb_tree.root);
    try testing.expectEqual(hopefully_node_17.left.?.key, 15);
    try testing.expectEqual(hopefully_node_17.right.?.key, 20);

    try testing.expectEqual(hopefully_node_20.getParent().?.key, 17);
    try testing.expect(hopefully_node_20.getColor() == .red);
    try testing.expectEqual(hopefully_node_20.left, null);
    try testing.expectEqual(hopefully_node_20.right, null);

    try testing.expectEqual(hopefully_node_15.getParent().?.key, 17);
    try testing.expect(hopefully_node_15.getColor() == .red);
    try testing.expectEqual(hopefully_node_15.left, null);
    try testing.expectEqual(hopefully_node_15.right, null);
}
test "right_left_rotation_no_sibling" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // LEFT PART

    const nodem10 = try allocator.create(Node);
    defer allocator.destroy(nodem10);
    nodem10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .red, .parent = nodem10, .left = null, .right = null });

    nodem10.right = node_7;

    // RIGHT PART

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;

    root.left = nodem10;
    root.right = node_20;

    var rb_tree: Tree = .{ .root = root, .size = 5 };
    const node_2 = (try rb_tree.insert(allocator, 2, void{}, .no_clobber)).node;
    defer allocator.destroy(node_2);

    //
    //
    //         ___10___                                                        ___10___
    //      -10B       20B                                                  -10B       20B
    //         7R     15R   --- (LR=>RL) Right Rotation (no recolor)-->        2R    15R
    // Add--> 2R                                                                7R
    //
    //
    //                                              _____10_____
    //     Left Rotation (with recolor) -->     __2B__       __20B__
    //                                      -10R     7R    15R
    //
    //
    //     2 goes as left to 7, but both are red so we do a RIGHT-LEFT rotation
    //     First a right rotation should happen, so that 2 becomes the parent of 7 [2 right-> 7]
    //     Second a left rotation should happen, so that 2 becomes the parent of -10 and 7
    //     2 is black, -10 and 7 are now red. 2's parent is the root - 10
    //
    try checkTreeEqual(rb_tree, [_]i32{ -10, 2, 7, 10, 15, 20 });

    const hopefully_node_2 = node_7.getParent().?;
    try testing.expectEqual(hopefully_node_2.getParent().?.key, 10);
    try testing.expect(hopefully_node_2.getColor() == .black);
    try testing.expectEqual(hopefully_node_2.left.?.key, -10);
    try testing.expectEqual(hopefully_node_2.right.?.key, 7);

    try testing.expect(node_7.getColor() == .red);
    try testing.expectEqual(node_7.getParent().?.key, 2);
    try testing.expectEqual(node_7.left, null);
    try testing.expectEqual(node_7.right, null);

    try testing.expect(nodem10.getColor() == .red);
    try testing.expectEqual(nodem10.getParent().?.key, 2);
    try testing.expectEqual(nodem10.left, null);
    try testing.expectEqual(nodem10.right, null);
}
test "recolor_lr" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null });

    // RIGHT SUBTREE

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .red, .parent = root, .left = null, .right = null });

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m20;

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.right = node_6;

    const node_1 = try allocator.create(Node);
    defer allocator.destroy(node_1);
    node_1.* = Node.init(.{ .key = 1, .color = .red, .parent = node_6, .left = null, .right = null });

    node_6.left = node_1;

    const node_9 = try allocator.create(Node);
    defer allocator.destroy(node_9);
    node_9.* = Node.init(.{ .key = 9, .color = .red, .parent = node_6, .left = null, .right = null });

    node_6.right = node_9;

    // LEFT SUBTREE

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.right = node_30;

    root.left = node_m10;
    root.right = node_20;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    const node_4 = (try rb_tree.insert(allocator, 4, void{}, .no_clobber)).node;
    defer allocator.destroy(node_4);

    //
    //
    //         _________10B_________                                      _________10B_________
    //    ___-10R___              __20B__                            ___-10R___              __20B__
    // -20B      __6B__         15R     30R  ---RECOLORS TO -->   -20B      __6R__         15R     30R
    //         1R     9R                                                  1B     9B
    //           4R                                                         4R
    //
    //                               _________10B_________
    //                          ___6R___              __20B__                                   ______6B__
    // LEFT ROTATOES TO --> __-10B__    9B         15R      30R   ---RIGHT ROTATES TO-->   __-10R__       _10R_
    //                   -20B      1B                                                   -20B      1B    9B   __20B__
    //                               4R                                                             4R     15R     30R
    //
    //
    //
    // Adding 4, we recolor once, then we check upwards and see that there's a black sibling.
    // We see that our direction is RightLeft (RL) and do a Left Rotation followed by a Right Rotation
    // -10 becomes 6's left child and 1 becomes -10's right child
    //
    try checkTreeEqual(rb_tree, [_]i32{ -20, -10, 1, 4, 6, 9, 10, 15, 20, 30 });

    const node_10 = rb_tree.root.?.right.?;
    const hopefully_node_4 = node_1.right.?;

    try testing.expectEqual(rb_tree.root.?.key, 6);
    try testing.expectEqual(rb_tree.root.?.getParent(), null);
    try testing.expectEqual(rb_tree.root.?.left.?.key, -10);
    try testing.expectEqual(rb_tree.root.?.right.?.key, 10);

    try testing.expectEqual(node_m10.getParent().?.key, 6);
    try testing.expect(node_m10.getColor() == .red);
    try testing.expectEqual(node_m10.left.?.key, -20);
    try testing.expectEqual(node_m10.right.?.key, 1);

    try testing.expect(node_10.getColor() == .red);
    try testing.expectEqual(node_10.getParent().?.key, 6);
    try testing.expectEqual(node_10.left.?.key, 9);
    try testing.expectEqual(node_10.right.?.key, 20);

    try testing.expect(node_m20.getColor() == .black);
    try testing.expectEqual(node_m20.getParent().?.key, -10);
    try testing.expectEqual(node_m20.left, null);
    try testing.expectEqual(node_m20.right, null);

    try testing.expect(node_1.getColor() == .black);
    try testing.expectEqual(node_1.getParent().?.key, -10);
    try testing.expectEqual(node_1.left, null);
    try testing.expect(node_1.right.?.getColor() == .red);
    try testing.expectEqual(hopefully_node_4.key, 4);
    try testing.expect(hopefully_node_4.getColor() == .red);
}
test "functional_test_build_tree" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    var allocator = testing.allocator;

    var rb_tree = Tree.init();

    const node_2 = (try rb_tree.insert(allocator, 2, void{}, .no_clobber)).node;
    defer allocator.destroy(node_2);
    try testing.expectEqual(rb_tree.root.?.key, 2);
    try testing.expect(rb_tree.root.?.getColor() == .black);
    const hopefully_node_2 = rb_tree.root.?;
    // 2
    try checkTreeEqual(rb_tree, [_]i32{2});

    const node_1 = (try rb_tree.insert(allocator, 1, void{}, .no_clobber)).node;
    defer allocator.destroy(node_1);

    //
    //  2B
    // 1R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2 });

    const hopefully_node_1 = rb_tree.root.?.left.?;
    try testing.expectEqual(hopefully_node_1.key, 1);
    try testing.expect(hopefully_node_1.getColor() == .red);

    const node_4 = (try rb_tree.insert(allocator, 4, void{}, .no_clobber)).node;
    defer allocator.destroy(node_4);

    //
    //   2B
    // 1R  4R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 4 });

    const hopefully_node_4 = rb_tree.root.?.right.?;
    try testing.expectEqual(hopefully_node_4.key, 4);
    try testing.expect(hopefully_node_4.getColor() == .red);
    try testing.expectEqual(hopefully_node_4.left, null);
    try testing.expectEqual(hopefully_node_4.right, null);

    const node_5 = (try rb_tree.insert(allocator, 5, void{}, .no_clobber)).node;
    defer allocator.destroy(node_5);

    //
    //   2B                              2B
    // 1R  4R    ---CAUSES RECOLOR-->  1B  4B
    //      5R                              5R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 4, 5 });

    const hopefully_node_5 = hopefully_node_4.right.?;
    try testing.expectEqual(hopefully_node_5.key, 5);
    try testing.expect(hopefully_node_4.getColor() == .black);
    try testing.expect(hopefully_node_1.getColor() == .black);
    try testing.expect(hopefully_node_5.getColor() == .red);

    const node_9 = (try rb_tree.insert(allocator, 9, void{}, .no_clobber)).node;
    defer allocator.destroy(node_9);

    //
    //   2B                                           __2B__
    // 1B  4B        ---CAUSES LEFT ROTATION-->     1B     5B
    //       5R                                          4R  9R
    //        9R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 4, 5, 9 });

    const hopefully_node_9 = hopefully_node_5.right.?;
    try testing.expectEqual(hopefully_node_9.key, 9);
    try testing.expect(hopefully_node_9.getColor() == .red);
    try testing.expectEqual(hopefully_node_9.left, null);
    try testing.expectEqual(hopefully_node_9.right, null);

    try testing.expect(hopefully_node_4.getColor() == .red);
    try testing.expectEqual(hopefully_node_4.left, null);
    try testing.expectEqual(hopefully_node_4.right, null);
    try testing.expectEqual(hopefully_node_4.getParent().?.key, 5);

    try testing.expectEqual(hopefully_node_5.getParent().?.key, 2);
    try testing.expect(hopefully_node_5.getColor() == .black);
    try testing.expectEqual(hopefully_node_5.left.?.key, 4);
    try testing.expectEqual(hopefully_node_5.right.?.key, 9);

    const node_3 = (try rb_tree.insert(allocator, 3, void{}, .no_clobber)).node;
    defer allocator.destroy(node_3);

    //
    //   __2B__                                  __2B__
    // 1B      5B     ---CAUSES RECOLOR-->     1B      5R
    //       4R  9R                                  4B  9B
    //      3R                                      3R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 3, 4, 5, 9 });

    const hopefully_node_3 = hopefully_node_4.left.?;
    try testing.expectEqual(hopefully_node_3.key, 3);
    try testing.expect(hopefully_node_3.getColor() == .red);
    try testing.expectEqual(hopefully_node_3.left, null);
    try testing.expectEqual(hopefully_node_3.right, null);
    try testing.expectEqual(hopefully_node_3.getParent().?.key, 4);

    try testing.expect(hopefully_node_4.getColor() == .black);
    try testing.expectEqual(hopefully_node_4.right, null);
    try testing.expectEqual(hopefully_node_4.getParent().?.key, 5);

    try testing.expect(hopefully_node_9.getColor() == .black);
    try testing.expectEqual(hopefully_node_9.getParent().?.key, 5);

    try testing.expect(hopefully_node_5.getColor() == .red);
    try testing.expectEqual(hopefully_node_5.left.?.key, 4);
    try testing.expectEqual(hopefully_node_5.right.?.key, 9);

    const node_6 = (try rb_tree.insert(allocator, 6, void{}, .no_clobber)).node;
    defer allocator.destroy(node_6);

    //
    // Nothing special
    //    __2B__
    //  1B      5R___
    //        4B    _9B
    //       3R    6R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 3, 4, 5, 6, 9 });

    const hopefully_node_6 = hopefully_node_9.left.?;
    try testing.expectEqual(hopefully_node_6.key, 6);
    try testing.expect(hopefully_node_6.getColor() == .red);
    try testing.expectEqual(hopefully_node_6.getParent().?.key, 9);
    try testing.expectEqual(hopefully_node_6.left, null);
    try testing.expectEqual(hopefully_node_6.right, null);

    const node_7 = (try rb_tree.insert(allocator, 7, void{}, .no_clobber)).node;
    defer allocator.destroy(node_7);

    //
    //        __2B__                                                    __2B__
    //      1B      ___5R___             ---LEFT  ROTATION TO-->       1B   ___5R___
    //            4B      _9B_                                             4B      9B
    //          3R       6R                                               3R      7R
    //                    7R                                                     6B
    // RIGHT ROTATION (RECOLOR) TO
    //      __2B__
    //    1B    ___5R___
    //         4B      7B
    //        3R     6R  9R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 3, 4, 5, 6, 7, 9 });

    const hopefully_node_7 = hopefully_node_5.right.?;
    try testing.expectEqual(hopefully_node_7.key, 7);
    try testing.expect(hopefully_node_7.getColor() == .black);
    try testing.expectEqual(hopefully_node_7.left.?.key, 6);
    try testing.expectEqual(hopefully_node_7.right.?.key, 9);
    try testing.expectEqual(hopefully_node_7.getParent().?.key, 5);

    try testing.expect(hopefully_node_5.getColor() == .red);
    try testing.expectEqual(hopefully_node_5.right.?.key, 7);

    try testing.expect(hopefully_node_6.getColor() == .red);
    try testing.expectEqual(hopefully_node_6.left, null);
    try testing.expectEqual(hopefully_node_6.right, null);
    try testing.expectEqual(hopefully_node_6.getParent().?.key, 7);

    try testing.expect(hopefully_node_9.getColor() == .red);
    try testing.expectEqual(hopefully_node_9.left, null);
    try testing.expectEqual(hopefully_node_9.right, null);
    try testing.expectEqual(hopefully_node_9.getParent().?.key, 7);

    const node_15 = (try rb_tree.insert(allocator, 15, void{}, .no_clobber)).node;
    defer allocator.destroy(node_15);

    //
    //      __2B__                                         __2B__
    // 1B    ___5R___                                    1B    ___5R___
    //      4B      7B       ---RECOLORS TO-->                4B       7R
    //     3R     6R  9R                                     3R       6B 9B
    //                 15R                                                15R
    //  Red-red relationship on 5R-7R. 7R's sibling is BLACK, so we need to rotate.
    //  7 is the right child of 5, 5 is the right child of 2, so we have RR => L: Left rotation with recolor
    //  What we get is:
    //
    //              ___5B___
    //          __2R__      7R
    //        1B     4B    6B 9B
    //              3R         15R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 2, 3, 4, 5, 6, 7, 9, 15 });

    const hopefully_node_15 = hopefully_node_9.right.?;
    try testing.expect(hopefully_node_15.getColor() == .red);
    try testing.expectEqual(hopefully_node_15.getParent().?.key, 9);
    try testing.expectEqual(hopefully_node_15.left, null);
    try testing.expectEqual(hopefully_node_15.right, null);

    try testing.expect(hopefully_node_9.getColor() == .black);
    try testing.expectEqual(hopefully_node_9.left, null);
    try testing.expectEqual(hopefully_node_9.right.?.key, 15);
    try testing.expectEqual(hopefully_node_9.getParent().?.key, 7);

    try testing.expect(hopefully_node_6.getColor() == .black);

    try testing.expect(hopefully_node_7.getColor() == .red);
    try testing.expectEqual(hopefully_node_7.left.?.key, 6);
    try testing.expectEqual(hopefully_node_7.right.?.key, 9);

    try testing.expectEqual(rb_tree.root.?.key, 5);
    try testing.expect(hopefully_node_5.getParent() == null);
    try testing.expectEqual(hopefully_node_5.right.?.key, 7);
    try testing.expectEqual(hopefully_node_5.left.?.key, 2);

    try testing.expect(hopefully_node_2.getColor() == .red);
    try testing.expectEqual(hopefully_node_2.getParent().?.key, 5);
    try testing.expectEqual(hopefully_node_2.left.?.key, 1);
    try testing.expectEqual(hopefully_node_2.right.?.key, 4);

    try testing.expectEqual(hopefully_node_4.getParent().?.key, 2);
    try testing.expect(hopefully_node_4.getColor() == .black);
    try testing.expectEqual(hopefully_node_4.left.?.key, 3);
    try testing.expectEqual(hopefully_node_4.right, null);
}
test "right_left_rotation_after_recolor" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    const node_10 = root;

    // left subtree

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .black, .parent = root, .left = null, .right = null });

    // right subtree

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .red, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .black, .parent = node_20, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .black, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;
    node_20.right = node_25;

    const node_12 = try allocator.create(Node);
    defer allocator.destroy(node_12);
    node_12.* = Node.init(.{ .key = 12, .color = .red, .parent = node_15, .left = null, .right = null });

    const node_17 = try allocator.create(Node);
    defer allocator.destroy(node_17);
    node_17.* = Node.init(.{ .key = 17, .color = .red, .parent = node_15, .left = null, .right = null });

    node_15.left = node_12;
    node_15.right = node_17;

    root.left = node_5;
    root.right = node_20;
    var rb_tree: Tree = .{ .root = root, .size = 8 };
    const node_19 = (try rb_tree.insert(allocator, 19, void{}, .no_clobber)).node;
    defer allocator.destroy(node_19);

    //
    //                 ____10B____                           ____10B____
    //                5B      __20R__                       5B      __20R__
    //                   __15B__   25B   --RECOLORS TO-->      __15R__   25B
    //                12R      17R                          12B      17B
    //                    Add-->19R                                   19R
    //
    //
    //                               ____10B____
    // LR=>RL: Right rotation to   5B          ___15R___
    //                                      12B      __20R__
    //                                             17B      25B
    //                                               19R
    //
    //
    //                                  ______15B_____
    //    Left rotation to           10R           __20R__
    //                             5B  12B     __17B__    25B
    //                                               19R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 5, 10, 12, 15, 17, 19, 20, 25 });

    const hopefully_node_19 = node_17.right.?;

    try testing.expectEqual(hopefully_node_19.key, 19);
    try testing.expect(hopefully_node_19.getColor() == .red);
    try testing.expectEqual(hopefully_node_19.left, null);
    try testing.expectEqual(hopefully_node_19.right, null);
    try testing.expectEqual(hopefully_node_19.getParent(), node_17);

    try testing.expectEqual(node_17.getParent(), node_20);
    try testing.expect(node_17.getColor() == .black);
    try testing.expectEqual(node_17.left, null);
    try testing.expectEqual(node_17.right, hopefully_node_19);

    try testing.expectEqual(node_20.getParent(), node_15);
    try testing.expect(node_20.getColor() == .red);
    try testing.expectEqual(node_20.left, node_17);
    try testing.expectEqual(node_20.right, node_25);

    try testing.expectEqual(rb_tree.root, node_15);
    try testing.expect(node_15.getParent() == null);
    try testing.expectEqual(node_15.left, node_10);
    try testing.expectEqual(node_15.right, node_20);
    try testing.expect(node_15.getColor() == .black);

    try testing.expectEqual(node_10.getParent(), node_15);
    try testing.expect(node_10.getColor() == .red);
    try testing.expectEqual(node_10.right, node_12);
    try testing.expectEqual(node_10.left, node_5);

    try testing.expect(node_12.getColor() == .black);
    try testing.expectEqual(node_12.getParent(), node_10);
    try testing.expectEqual(node_12.left, null);
    try testing.expectEqual(node_12.right, null);
}
test "right_rotation_after_recolor" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    const node_10 = root;
    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .red, .parent = root, .left = null, .right = null });

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .black, .parent = node_m10, .left = null, .right = null });

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m20;
    node_m10.right = node_6;

    const node_m21 = try allocator.create(Node);
    defer allocator.destroy(node_m21);
    node_m21.* = Node.init(.{ .key = -21, .color = .red, .parent = node_m20, .left = null, .right = null });

    const node_m19 = try allocator.create(Node);
    defer allocator.destroy(node_m19);
    node_m19.* = Node.init(.{ .key = -19, .color = .red, .parent = node_m20, .left = null, .right = null });

    node_m20.left = node_m21;
    node_m20.right = node_m19;
    // right subtree

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = root, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_20, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .red, .parent = node_20, .left = null, .right = null });

    node_20.left = node_15;
    node_20.right = node_25;

    root.left = node_m10;
    root.right = node_20;
    var rb_tree: Tree = .{ .root = root, .size = 10 };
    const node_m22 = (try rb_tree.insert(allocator, -22, void{}, .no_clobber)).node;
    defer allocator.destroy(node_m22);

    //
    //
    //                    _____10_____                                               _____10_____
    //                   /            \                                             /            \
    //                -10R           20B                                         -10R           20B
    //               /    \          /   \                                      /   \          /    \
    //            -20B    6B       15R  25R     --RECOLOR TO-->              -20R    6B       15R  25R
    //            /   \                                                       /  \
    //          -21R -19R                                                   -21B -19B
    //           /                                                         /
    // Add-> -22R                                                        22R
    //
    //
    //
    //                                        ____-10B_____
    //                                       /             \
    //                                     -20R          __10R__
    //                                     /   \        /       \
    //        Right rotation to->       -21B  -19B     6B    __20B__
    //                                   /                  /       \
    //                                -22R                 15R     25R
    //
    //
    try checkTreeEqual(rb_tree, [_]i32{ -22, -21, -20, -19, -10, 6, 10, 15, 20, 25 });

    try testing.expectEqual(rb_tree.root, node_m10);
    try testing.expectEqual(node_m10.getParent(), null);
    try testing.expectEqual(node_m10.left, node_m20);
    try testing.expectEqual(node_m10.right, node_10);
    try testing.expect(node_m10.getColor() == .black);

    try testing.expectEqual(node_10.getParent(), node_m10);
    try testing.expect(node_10.getColor() == .red);
    try testing.expectEqual(node_10.left, node_6);
    try testing.expectEqual(node_10.right, node_20);

    try testing.expectEqual(node_m20.getParent(), node_m10);
    try testing.expect(node_m20.getColor() == .red);
    try testing.expectEqual(node_m20.left, node_m21);
    try testing.expectEqual(node_m20.right, node_m19);

    try testing.expect(node_m21.getColor() == .black);
    try testing.expectEqual(node_m21.left.?.key, -22);

    try testing.expectEqual(node_6.getParent(), node_10);
    try testing.expect(node_6.getColor() == .black);
    try testing.expectEqual(node_6.left, null);
    try testing.expectEqual(node_6.right, null);

    try testing.expect(node_m19.getColor() == .black);
    try testing.expectEqual(node_m19.getParent(), node_m20);
    try testing.expectEqual(node_m19.left, null);
    try testing.expectEqual(node_m19.right, null);
}
test "deletion_root" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 5, .color = .black, .parent = null, .left = null, .right = null });

    const left_child = try allocator.create(Node);
    defer allocator.destroy(left_child);
    left_child.* = Node.init(.{ .key = 3, .color = .red, .parent = root, .left = null, .right = null });

    const right_child = try allocator.create(Node);
    defer allocator.destroy(right_child);
    right_child.* = Node.init(.{ .key = 8, .color = .red, .parent = root, .left = null, .right = null });

    root.left = left_child;
    root.right = right_child;

    //
    // REMOVE--> __5__                     __8B__
    //          /     \     --Result-->   /
    //        3R      8R                3R
    //
    var rb_tree: Tree = .{ .root = root, .size = 3 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(5).?);

    try checkTreeEqual(rb_tree, [_]i32{ 3, 8 });

    const node_8 = rb_tree.root.?;
    try testing.expectEqual(node_8.key, 8);
    try testing.expect(node_8.getColor() == .black);
    try testing.expectEqual(node_8.getParent(), null);
    try testing.expectEqual(node_8.left.?.key, 3);
    try testing.expectEqual(node_8.right, null);
    const node_3 = node_8.left.?;
    try testing.expect(node_3.getColor() == .red);
    try testing.expectEqual(node_3.getParent(), node_8);
    try testing.expectEqual(node_3.left, null);
    try testing.expectEqual(node_3.right, null);
}
test "deletion_root_2_nodes" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 5, .color = .black, .parent = null, .left = null, .right = null });

    const right_child = try allocator.create(Node);
    defer allocator.destroy(right_child);
    right_child.* = Node.init(.{ .key = 8, .color = .red, .parent = root, .left = null, .right = null });

    root.right = right_child;
    var rb_tree: Tree = .{ .root = root, .size = 2 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(5).?);

    //
    // __5B__ <-- REMOVE        __8B__
    //      \      Should become--^
    //      8R
    //
    try checkTreeEqual(rb_tree, [_]i32{8});

    const hopefully_root = rb_tree.root.?;
    try testing.expectEqual(hopefully_root.key, 8);
    try testing.expectEqual(hopefully_root.getParent(), null);
    try testing.expect(hopefully_root.getColor() == .black);
    try testing.expectEqual(hopefully_root.left, null);
    try testing.expectEqual(hopefully_root.right, null);
}
test "delete_single_child" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 5, .color = .black, .parent = null, .left = null, .right = null });

    const left_child = try allocator.create(Node);
    defer allocator.destroy(left_child);
    left_child.* = Node.init(.{ .key = 1, .color = .red, .parent = root, .left = null, .right = null });

    const right_child = try allocator.create(Node);
    defer allocator.destroy(right_child);
    right_child.* = Node.init(.{ .key = 6, .color = .red, .parent = root, .left = null, .right = null });

    root.left = left_child;
    root.right = right_child;
    var rb_tree: Tree = .{ .root = root, .size = 3 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(6).?);

    //
    //    5                        5B
    //   / \   should become      /
    // 1R   6R                   1R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 1, 5 });

    try testing.expectEqual(root.right, null);
    try testing.expectEqual(root.key, 5);
    try testing.expect(root.getColor() == .black);
    try testing.expectEqual(root.getParent(), null);
    try testing.expectEqual(root.left.?.key, 1);
    const node_1 = root.left.?;
    try testing.expectEqual(node_1.left, null);
    try testing.expectEqual(node_1.right, null);
}
test "delete_single_deep_child" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 20, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_10 = try allocator.create(Node);
    defer allocator.destroy(node_10);
    // FIX: The following node did not have its parent correctly set in the python code
    node_10.* = Node.init(.{ .key = 10, .color = .black, .parent = root, .left = null, .right = null });

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .red, .parent = node_10, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_10, .left = null, .right = null });

    node_10.left = node_5;
    node_10.right = node_15;
    // right subtree

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .red, .parent = root, .left = null, .right = null });

    const node_28 = try allocator.create(Node);
    defer allocator.destroy(node_28);
    node_28.* = Node.init(.{ .key = 28, .color = .black, .parent = node_38, .left = null, .right = null });

    const node_48 = try allocator.create(Node);
    defer allocator.destroy(node_48);
    node_48.* = Node.init(.{ .key = 48, .color = .black, .parent = node_38, .left = null, .right = null });

    node_38.left = node_28;
    node_38.right = node_48;
    // node_28 subtree

    const node_23 = try allocator.create(Node);
    defer allocator.destroy(node_23);
    node_23.* = Node.init(.{ .key = 23, .color = .red, .parent = node_28, .left = null, .right = null });

    const node_29 = try allocator.create(Node);
    defer allocator.destroy(node_29);
    node_29.* = Node.init(.{ .key = 29, .color = .red, .parent = node_28, .left = null, .right = null });

    node_28.left = node_23;
    node_28.right = node_29;
    // node 48 subtree

    const node_41 = try allocator.create(Node);
    defer allocator.destroy(node_41);
    node_41.* = Node.init(.{ .key = 41, .color = .red, .parent = node_48, .left = null, .right = null });

    const node_49 = try allocator.create(Node);
    defer allocator.destroy(node_49);
    node_49.* = Node.init(.{ .key = 49, .color = .red, .parent = node_48, .left = null, .right = null });

    node_48.left = node_41;
    node_48.right = node_49;

    root.left = node_10;
    root.right = node_38;
    var rb_tree: Tree = .{ .root = root, .size = 11 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(49).?);

    //
    //       ______20______
    //      /              \
    //    10B           ___38R___
    //   /   \         /         \
    // 5R    15R      28B         48B
    //               /  \        /   \
    //             23R  29R     41R   49R    <--- REMOVE
    //
    try checkTreeEqual(rb_tree, [_]i32{ 5, 10, 15, 20, 23, 28, 29, 38, 41, 48 });

    try testing.expectEqual(node_48.right, null);
    try testing.expect(node_48.getColor() == .black);
    try testing.expectEqual(node_48.left.?.key, 41);
    try testing.expectEqual(rb_tree.find(49), null);
}
test "deletion_red_node_red_successor_no_children" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // This must be the easiest deletion yet!
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // Left subtree

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .red, .parent = root, .left = null, .right = null });

    const node_m5 = try allocator.create(Node);
    defer allocator.destroy(node_m5);
    // FIX the following node did not have its parent correctly set in the python code
    node_m5.* = Node.init(.{ .key = -5, .color = .black, .parent = node_5, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .black, .parent = node_5, .left = null, .right = null });

    node_5.left = node_m5;
    node_5.right = node_7;

    // right subtree

    const node_35 = try allocator.create(Node);
    defer allocator.destroy(node_35);
    node_35.* = Node.init(.{ .key = 35, .color = .red, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_35, .left = null, .right = null });

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .black, .parent = node_35, .left = null, .right = null });

    node_35.left = node_20;
    node_35.right = node_38;

    const node_36 = try allocator.create(Node);
    defer allocator.destroy(node_36);
    node_36.* = Node.init(.{ .key = 36, .color = .red, .parent = node_38, .left = null, .right = null });

    node_38.left = node_36;

    root.left = node_5;
    root.right = node_35;
    var rb_tree: Tree = .{ .root = root, .size = 8 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(35).?);

    //
    //                10B
    //              /     \
    //            5R       35R   <-- REMOVE THIS
    //           /  \     /   \
    //        -5B   7B   20B  38B   We get it's in-order successor, which is 36
    //                       /
    //                      36R     36 Is red and has no children, so we easily swap it's value with 35 and remove 36
    //
    //                  10B
    //                /     \
    // RESULT IS    5R       36R
    //             /  \     /   \
    //          -5B   7B   20B  38B
    //
    try checkTreeEqual(rb_tree, [_]i32{ -5, 5, 7, 10, 20, 36, 38 });

    // Careful with reference equals
    const hopefully_node_36 = rb_tree.root.?.right.?;
    try testing.expectEqual(hopefully_node_36.key, 36);
    try testing.expect(hopefully_node_36.getColor() == .red);
    try testing.expectEqual(hopefully_node_36.getParent(), rb_tree.root);
    try testing.expectEqual(hopefully_node_36.left.?.key, 20);
    try testing.expectEqual(hopefully_node_36.right.?.key, 38);

    try testing.expectEqual(node_20.getParent().?.key, 36);
    try testing.expectEqual(node_38.getParent().?.key, 36);
    try testing.expectEqual(node_38.left, null);
}
test "mirror_deletion_red_node_red_successor_no_children" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // This must be the easiest deletion yet!
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // Left subtree

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .red, .parent = root, .left = null, .right = null });

    const node_m5 = try allocator.create(Node);
    defer allocator.destroy(node_m5);
    node_m5.* = Node.init(.{ .key = -5, .color = .black, .parent = root, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .black, .parent = node_5, .left = null, .right = null });

    node_5.left = node_m5;
    node_5.right = node_7;

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .red, .parent = node_7, .left = null, .right = null });

    node_7.left = node_6;

    // right subtree

    const node_35 = try allocator.create(Node);
    defer allocator.destroy(node_35);
    node_35.* = Node.init(.{ .key = 35, .color = .red, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_35, .left = null, .right = null });

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .black, .parent = node_35, .left = null, .right = null });

    node_35.left = node_20;
    node_35.right = node_38;

    const node_36 = try allocator.create(Node);
    defer allocator.destroy(node_36);
    node_36.* = Node.init(.{ .key = 36, .color = .red, .parent = node_38, .left = null, .right = null });

    node_38.left = node_36;

    root.left = node_5;
    root.right = node_35;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(5).?);

    //
    //                 10B
    //               /     \
    // REMOVE -->  5R       35R
    //            /  \     /   \
    //         -5B   7B   20B  38B   We get it's in-order successor, which is 6
    //              /         /
    //            6R         36R      6 Is red and has no children,
    //                                 so we easily swap it's value with 5 and remove 6
    //
    //                   10B
    //                 /     \
    //  RESULT IS    6R       35R
    //              /  \     /   \
    //           -5B   7B   20B  38B
    //                          /
    //                         36R
    //
    try checkTreeEqual(rb_tree, [_]i32{ -5, 6, 7, 10, 20, 35, 36, 38 });

    const hopefully_node_6 = rb_tree.root.?.left.?;
    try testing.expectEqual(hopefully_node_6.key, 6);
    try testing.expect(hopefully_node_6.getColor() == .red);
    try testing.expectEqual(hopefully_node_6.getParent(), rb_tree.root);
    try testing.expectEqual(hopefully_node_6.left.?.key, -5);
    try testing.expectEqual(hopefully_node_6.right.?.key, 7);
    const hopefully_node_7 = hopefully_node_6.right.?;
    try testing.expect(hopefully_node_7.getColor() == .black);
    try testing.expectEqual(hopefully_node_7.getParent(), hopefully_node_6);
    try testing.expectEqual(hopefully_node_7.left, null);
    try testing.expectEqual(hopefully_node_7.right, null);
}
test "deletion_black_node_black_successor_right_red_child" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .black, .parent = root, .left = null, .right = null });

    const node_m5 = try allocator.create(Node);
    defer allocator.destroy(node_m5);
    node_m5.* = Node.init(.{ .key = -5, .color = .black, .parent = node_5, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .black, .parent = node_5, .left = null, .right = null });

    node_5.left = node_m5;
    node_5.right = node_7;
    // right subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .black, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_30, .left = null, .right = null });

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .red, .parent = node_30, .left = null, .right = null });

    node_30.left = node_20;
    node_30.right = node_38;
    // 38 subtree

    const node_32 = try allocator.create(Node);
    defer allocator.destroy(node_32);
    node_32.* = Node.init(.{ .key = 32, .color = .black, .parent = node_38, .left = null, .right = null });

    const node_41 = try allocator.create(Node);
    defer allocator.destroy(node_41);
    node_41.* = Node.init(.{ .key = 41, .color = .black, .parent = node_38, .left = null, .right = null });

    node_38.left = node_32;
    node_38.right = node_41;

    const node_35 = try allocator.create(Node);
    defer allocator.destroy(node_35);
    node_35.* = Node.init(.{ .key = 35, .color = .red, .parent = node_32, .left = null, .right = null });

    node_32.right = node_35;

    root.left = node_5;
    root.right = node_30;

    var rb_tree: Tree = .{ .root = root, .size = 10 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(30).?);

    //
    //       ___10B___                                             ___10B___
    //      /         \                                           /         \
    //     5B         30B  <------- REMOVE THIS                  5B         32B  <----
    //    /  \       /   \                                      /  \       /   \
    //  -5B  7B    20B   38R                                  -5B  7B    20B   38R
    //                  /   \                                                 /   \
    // successor ---> 32B    41B                                       -->  35B    41B
    //                   \             30B becomes 32B
    //                   35R           old 32B becomes 35B
    //
    try checkTreeEqual(rb_tree, [_]i32{ -5, 5, 7, 10, 20, 32, 35, 38, 41 });

    // FIX: the following code appeared in the Python code, what is going on here?
    // const hopefully_node_32 = node_30;
    try testing.expectEqual(node_32.key, 32);
    try testing.expectEqual(node_32.getParent().?.key, 10);
    try testing.expect(node_32.getColor() == .black);
    try testing.expectEqual(node_32.left, node_20);
    try testing.expectEqual(node_32.right, node_38);

    const hopefully_node_35 = node_38.left.?;
    try testing.expectEqual(hopefully_node_35.key, 35);
    try testing.expectEqual(hopefully_node_35.getParent().?.key, 38);
    try testing.expect(hopefully_node_35.getColor() == .black);
    try testing.expectEqual(hopefully_node_35.left, null);
    try testing.expectEqual(hopefully_node_35.right, null);
}
test "deletion_black_node_black_successor_no_child_case_4" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    // right subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .red, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_30, .left = null, .right = null });

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .black, .parent = node_30, .left = null, .right = null });

    node_30.left = node_20;
    node_30.right = node_38;

    root.left = node_m10;
    root.right = node_30;
    var rb_tree: Tree = .{ .root = root, .size = 5 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(10).?);

    //
    //          ___10B___   <----- REMOVE THIS       ___20B___
    //         /         \                          /         \
    //       -10B        30R                      -10B        30R
    //                  /   \                                /   \
    // successor --> 20B    38B                double black DB  38B
    //                                        Case 4 applies, since the sibling is black, has no red children and
    //                                        the parent is RED
    //                                        So, we simply exchange colors of the parent and the sibling
    //
    //
    //               ___20B___
    //              /         \
    //            -10B        30B        DONE
    //                           \
    //                          38R
    //
    //
    try checkTreeEqual(rb_tree, [_]i32{ -10, 20, 30, 38 });

    try testing.expectEqual(rb_tree.root.?.key, 20);
    try testing.expect(rb_tree.root.?.getColor() == .black);
    const hopefully_node_30 = rb_tree.root.?.right.?;
    try testing.expectEqual(hopefully_node_30.getParent().?.key, 20);
    try testing.expectEqual(hopefully_node_30.key, 30);
    try testing.expect(hopefully_node_30.getColor() == .black);
    try testing.expectEqual(hopefully_node_30.left, null);
    try testing.expectEqual(hopefully_node_30.right.?.key, 38);
    const hopefully_node_38 = hopefully_node_30.right.?;
    try testing.expectEqual(hopefully_node_38.key, 38);
    try testing.expect(hopefully_node_38.getColor() == .red);
    try testing.expectEqual(hopefully_node_38.left, null);
    try testing.expectEqual(hopefully_node_38.right, null);
}
test "deletion_black_node_no_successor_case_6" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    // right subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .black, .parent = root, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .red, .parent = node_30, .left = null, .right = null });

    const node_40 = try allocator.create(Node);
    defer allocator.destroy(node_40);
    node_40.* = Node.init(.{ .key = 40, .color = .red, .parent = node_30, .left = null, .right = null });

    node_30.left = node_25;
    node_30.right = node_40;

    root.left = node_m10;
    root.right = node_30;
    var rb_tree: Tree = .{ .root = root, .size = 5 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(-10).?);

    //
    //                 ___10B___
    //                /         \           Case 6 applies here, since
    //  REMOVE-->  -10B         30B         The parent's color does not matter
    //  Double Black           /   \        The sibling's color is BLACK
    //                       25R    40R     The sibling's right child is RED (in the MIRROR CASE - left child should be RED)
    // Here we do a left rotation and change the colors such that
    //     the sibling gets the parent's color (30 gets 10's color)
    //     the parent(now sibling's left) and sibling's right become BLACK
    //
    //
    //          ___30B___
    //         /         \
    //       10B         40B
    //     /    \
    //  NULL    25R
    // -10B
    // would be here
    // but we're removing it
    //
    try testing.expect(rb_tree.root.?.getColor() == .black);
    try testing.expectEqual(rb_tree.root.?.key, 30);
    const node_10 = rb_tree.root.?.left.?;
    try testing.expectEqual(node_10.key, 10);
    try testing.expect(node_10.getColor() == .black);
    try testing.expectEqual(node_10.getParent(), rb_tree.root);
    try testing.expectEqual(node_10.left, null);
    const hopefully_node_25 = node_10.right.?;
    try testing.expectEqual(hopefully_node_25.key, 25);
    try testing.expect(hopefully_node_25.getColor() == .red);
    try testing.expectEqual(hopefully_node_25.getParent(), node_10);
    try testing.expectEqual(hopefully_node_25.left, null);
    try testing.expectEqual(hopefully_node_25.right, null);
    const hopefully_node_40 = rb_tree.root.?.right.?;
    try testing.expectEqual(hopefully_node_40.key, 40);
    try testing.expectEqual(hopefully_node_40.getParent(), rb_tree.root);
    try testing.expect(hopefully_node_40.getColor() == .black);
    try testing.expectEqual(hopefully_node_40.left, null);
    try testing.expectEqual(hopefully_node_40.right, null);
}
test "mirror_deletion_black_node_no_successor_case_6" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    const node_12 = try allocator.create(Node);
    defer allocator.destroy(node_12);
    node_12.* = Node.init(.{ .key = 12, .color = .black, .parent = root, .left = null, .right = null });

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .black, .parent = root, .left = null, .right = null });

    const node_1 = try allocator.create(Node);
    defer allocator.destroy(node_1);
    node_1.* = Node.init(.{ .key = 1, .color = .red, .parent = node_5, .left = null, .right = null });

    const node_7 = try allocator.create(Node);
    defer allocator.destroy(node_7);
    node_7.* = Node.init(.{ .key = 7, .color = .red, .parent = node_5, .left = null, .right = null });

    node_5.left = node_1;
    node_5.right = node_7;
    root.left = node_5;
    root.right = node_12;
    var rb_tree: Tree = .{ .root = root, .size = 5 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(12).?);

    //
    //      __10B__                                           __5B__
    //      /      \                                         /      \
    //    5B       12B  <--- REMOVE                        1B        10B
    //   /  \              has no successors                        /
    // 1R   7R                                                    7R
    //               case 6 applies, so we left rotate at 5b
    //
    const hopefully_node_5 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_5.key, 5);
    try testing.expect(hopefully_node_5.getColor() == .black);
    try testing.expectEqual(hopefully_node_5.getParent(), null);
    try testing.expectEqual(hopefully_node_5.left.?.key, 1);
    try testing.expectEqual(hopefully_node_5.right.?.key, 10);
    const hopefully_node_1 = hopefully_node_5.left.?;
    try testing.expectEqual(hopefully_node_1.key, 1);
    try testing.expectEqual(hopefully_node_1.getParent(), hopefully_node_5);
    try testing.expect(hopefully_node_1.getColor() == .black);
    try testing.expectEqual(hopefully_node_1.left, null);
    try testing.expectEqual(hopefully_node_1.right, null);
    const node_10 = hopefully_node_5.right.?;
    try testing.expectEqual(node_10.key, 10);
    try testing.expectEqual(node_10.getParent(), hopefully_node_5);
    try testing.expect(node_10.getColor() == .black);
    try testing.expectEqual(node_10.left.?.key, 7);
    try testing.expectEqual(node_10.right, null);
    const hopefully_node_7 = node_10.left.?;
    try testing.expectEqual(hopefully_node_7.key, 7);
    try testing.expectEqual(hopefully_node_7.getParent(), node_10);
    try testing.expect(hopefully_node_7.getColor() == .red);
    try testing.expectEqual(hopefully_node_7.left, null);
    try testing.expectEqual(hopefully_node_7.right, null);
}
test "deletion_black_node_no_successor_case_3_then_1" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // Delete a node such that case 3 is called, which pushes
    // the double black node upwards into a case 1 problem
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    // right subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .black, .parent = root, .left = null, .right = null });

    root.left = node_m10;
    root.right = node_30;
    var rb_tree: Tree = .{ .root = root, .size = 3 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(-10).?);

    //                                                     Double
    //                                                     Black
    //                 ___10B___                         __|10B|__
    //                /         \     ---->             /         \
    // REMOVE-->   -10B         30B                  REMOVED      30R  <--- COLORED RED
    //
    //         We color the sibling red and try to resolve the double black problem in the root.
    //         We go through the cases 1-6 and find that case 1 is what we're looking for
    //         Case 1 simply recolors the root to black and we are done
    //             ___10B___
    //                      \
    //                      30R
    //
    const node_10 = rb_tree.root.?;
    try testing.expect(node_10.getColor() == .black);
    try testing.expectEqual(node_10.getParent(), null);
    try testing.expectEqual(node_10.left, null);
    try testing.expectEqual(node_10.right.?.key, 30);
    const hopefully_node_30 = node_10.right.?;
    try testing.expectEqual(hopefully_node_30.key, 30);
    try testing.expect(hopefully_node_30.getColor() == .red);
    try testing.expectEqual(hopefully_node_30.getParent(), node_10);
    try testing.expectEqual(hopefully_node_30.left, null);
    try testing.expectEqual(hopefully_node_30.right, null);
}
test "deletion_black_node_no_successor_case_3_then_5_then_6" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // We're going to delete a black node which will cause a case 3 deletion
    // which in turn would pass the double black node up into a case 5, which
    // will restructure the tree in such a way that a case 6 rotation becomes possible
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m30 = try allocator.create(Node);
    defer allocator.destroy(node_m30);
    node_m30.* = Node.init(.{ .key = -30, .color = .black, .parent = root, .left = null, .right = null });

    const node_m40 = try allocator.create(Node);
    defer allocator.destroy(node_m40);
    node_m40.* = Node.init(.{ .key = -40, .color = .black, .parent = node_m30, .left = null, .right = null });

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m30, .left = null, .right = null });

    node_m30.left = node_m40;
    node_m30.right = node_m20;
    // right subtree

    const node_50 = try allocator.create(Node);
    defer allocator.destroy(node_50);
    node_50.* = Node.init(.{ .key = 50, .color = .black, .parent = root, .left = null, .right = null });

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .red, .parent = node_50, .left = null, .right = null });

    const node_70 = try allocator.create(Node);
    defer allocator.destroy(node_70);
    node_70.* = Node.init(.{ .key = 70, .color = .black, .parent = node_50, .left = null, .right = null });

    node_50.left = node_30;
    node_50.right = node_70;

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .black, .parent = node_30, .left = null, .right = null });

    const node_40 = try allocator.create(Node);
    defer allocator.destroy(node_40);
    node_40.* = Node.init(.{ .key = 40, .color = .black, .parent = node_30, .left = null, .right = null });

    node_30.left = node_15;
    node_30.right = node_40;

    root.left = node_m30;
    root.right = node_50;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(-40).?);

    //
    //       In mirror cases, this'd be mirrored
    //       |node| - double black node
    //                   ___10B___                                 ___10B___
    //                  /         \               DOUBLE          /         \
    //               -30B         50B             BLACK-->   |-30B|        50B
    //              /    \       /   \                        /    \       /   \
    // REMOVE-->|-40B|  -20B   30R   70B     --CASE 3--> REMOVED  -20R   30R   70B
    //                        /   \                                     /   \
    //                      15B   40B                                 15B   40B
    //
    //
    //
    //     --CASE 5-->                              ___10B___
    //     parent is black        still double     /         \
    //     sibling is black         black -->  |-30B|        30B
    //     sibling.left is red                     \        /   \
    //     sibling.right is black                  -20R   15B   50R
    //     left rotation on sibling.left                       /   \
    //                                                       40B   70B
    //
    //
    //     What we've done here is we've simply
    //     restructured the tree to be eligible
    //     for a case 6 solution :)                              ___30B___
    //     --CASE 6-->                                          /         \
    //     parent color DOESNT MATTER                         10B         50B
    //     sibling is black                                  /   \       /   \
    //     sibling.left DOESNT MATTER                     -30B   15B   40B   70B
    //     sibling.right is RED                              \
    //     left rotation on sibling (30B on the above)       -20R
    //     where the sibling gets the color of the parent
    //         and the parent is now to the left of sibling and
    //         repainted BLACK
    //         the sibling's right also gets repainted black
    //
    const hopefully_node_30 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_30.key, 30);
    try testing.expectEqual(hopefully_node_30.getParent(), null);
    try testing.expect(hopefully_node_30.getColor() == .black);
    try testing.expectEqual(hopefully_node_30.left.?.key, 10);
    try testing.expectEqual(hopefully_node_30.right.?.key, 50);

    // test left subtree
    const node_10 = hopefully_node_30.left.?;
    try testing.expectEqual(node_10.key, 10);
    try testing.expect(node_10.getColor() == .black);
    try testing.expectEqual(node_10.getParent(), hopefully_node_30);
    try testing.expectEqual(node_10.left.?.key, -30);
    try testing.expectEqual(node_10.right.?.key, 15);
    const hopefully_node_m30 = node_10.left.?;
    try testing.expectEqual(hopefully_node_m30.key, -30);
    try testing.expect(hopefully_node_m30.getColor() == .black);
    try testing.expectEqual(hopefully_node_m30.getParent(), node_10);
    try testing.expectEqual(hopefully_node_m30.left, null);
    try testing.expectEqual(hopefully_node_m30.right.?.key, -20);
    const hopefully_node_15 = node_10.right.?;
    try testing.expectEqual(hopefully_node_15.key, 15);
    try testing.expect(hopefully_node_15.getColor() == .black);
    try testing.expectEqual(hopefully_node_15.getParent(), node_10);
    try testing.expectEqual(hopefully_node_15.left, null);
    try testing.expectEqual(hopefully_node_15.right, null);
    const hopefully_node_m20 = hopefully_node_m30.right.?;
    try testing.expectEqual(hopefully_node_m20.key, -20);
    try testing.expect(hopefully_node_m20.getColor() == .red);
    try testing.expectEqual(hopefully_node_m20.getParent(), hopefully_node_m30);
    try testing.expectEqual(hopefully_node_m20.left, null);
    try testing.expectEqual(hopefully_node_m20.right, null);

    // test right subtree
    const hopefully_node_50 = hopefully_node_30.right.?;
    try testing.expectEqual(hopefully_node_50.key, 50);
    try testing.expect(hopefully_node_50.getColor() == .black);
    try testing.expectEqual(hopefully_node_50.getParent(), hopefully_node_30);
    try testing.expectEqual(hopefully_node_50.left.?.key, 40);
    try testing.expectEqual(hopefully_node_50.right.?.key, 70);
    const hopefully_node_40 = hopefully_node_50.left.?;
    try testing.expectEqual(hopefully_node_40.key, 40);
    try testing.expectEqual(hopefully_node_40.getParent(), hopefully_node_50);
    try testing.expect(hopefully_node_40.getColor() == .black);
    try testing.expectEqual(hopefully_node_40.left, null);
    try testing.expectEqual(hopefully_node_40.right, null);
    const hopefully_node_70 = hopefully_node_50.right.?;
    try testing.expectEqual(hopefully_node_70.key, 70);
    try testing.expect(hopefully_node_70.getColor() == .black);
    try testing.expectEqual(hopefully_node_70.getParent(), hopefully_node_50);
    try testing.expectEqual(hopefully_node_70.left, null);
    try testing.expectEqual(hopefully_node_70.right, null);
}
test "mirror_deletion_black_node_no_successor_case_3_then_5_then_6" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    //
    // We're going to delete a black node which will cause a case 3 deletion
    // which in turn would pass the double black node up into a case 5, which
    // will restructure the tree in such a way that a case 6 rotation becomes possible
    //

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 50, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .black, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_30, .left = null, .right = null });

    const node_35 = try allocator.create(Node);
    defer allocator.destroy(node_35);
    node_35.* = Node.init(.{ .key = 35, .color = .red, .parent = node_30, .left = null, .right = null });

    node_30.left = node_20;
    node_30.right = node_35;

    const node_34 = try allocator.create(Node);
    defer allocator.destroy(node_34);
    node_34.* = Node.init(.{ .key = 34, .color = .black, .parent = node_35, .left = null, .right = null });

    const node_37 = try allocator.create(Node);
    defer allocator.destroy(node_37);
    node_37.* = Node.init(.{ .key = 37, .color = .black, .parent = node_35, .left = null, .right = null });

    node_35.left = node_34;
    node_35.right = node_37;
    // right subtree

    const node_80 = try allocator.create(Node);
    defer allocator.destroy(node_80);
    node_80.* = Node.init(.{ .key = 80, .color = .black, .parent = root, .left = null, .right = null });

    const node_70 = try allocator.create(Node);
    defer allocator.destroy(node_70);
    node_70.* = Node.init(.{ .key = 70, .color = .black, .parent = node_80, .left = null, .right = null });

    const node_90 = try allocator.create(Node);
    defer allocator.destroy(node_90);
    node_90.* = Node.init(.{ .key = 90, .color = .black, .parent = node_80, .left = null, .right = null });

    node_80.left = node_70;
    node_80.right = node_90;

    root.left = node_30;
    root.right = node_80;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(90).?);

    //
    //                         Parent is black
    //            ___50B___    Sibling is black                       ___50B___
    //           /         \   Sibling's children are black          /         \
    //        30B          80B        CASE 3                       30B        |80B|
    //       /   \        /   \        ==>                        /  \        /   \
    //     20B   35R    70B    90B <---REMOVE                   20B  35R     70R   X
    //           /  \                                               /   \
    //         34B   37B                                          34B   37B
    //
    //
    //
    // Case 5
    // Parent is black                                 __50B__
    // Sibling is black             CASE 5            /       \
    // Closer sibling child is RED  =====>          35B      |80B|
    //     (right in this case,                    /   \      /
    //      left in mirror)                     30R   37B    70R
    // Outer sibling child is blck             /  \
    //                                      20B  34B
    //
    //
    // We have now successfully position our tree
    // for a CASE 6 scenario
    // The parent's color does not matter                           __35B__
    // The sibling is black                                        /       \
    // The closer sibling child             CASE 6               30R       50R
    //     's color does not matter         ====>               /   \     /   \
    // The outer sibling child                                20B   34B 37B    80B
    //     (left in this case,                                                 /
    //      right in mirror)                                                  70R
    //      is RED!
    //
    try checkTreeEqual(rb_tree, [_]i32{ 20, 30, 34, 35, 37, 50, 70, 80 });

    const hopefully_node_35 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_35.key, 35);
    try testing.expectEqual(hopefully_node_35.getParent(), null);
    try testing.expect(hopefully_node_35.getColor() == .black);
    try testing.expectEqual(hopefully_node_35.left.?.key, 30);
    try testing.expectEqual(hopefully_node_35.right.?.key, 50);
    // right subtree
    const node_50 = hopefully_node_35.right.?;
    try testing.expectEqual(node_50.key, 50);
    try testing.expect(node_50.getColor() == .black);
    try testing.expectEqual(node_50.getParent(), hopefully_node_35);
    try testing.expectEqual(node_50.left.?.key, 37);
    try testing.expectEqual(node_50.right.?.key, 80);
    const hopefully_node_37 = node_50.left.?;
    try testing.expectEqual(hopefully_node_37.key, 37);
    try testing.expect(hopefully_node_37.getColor() == .black);
    try testing.expectEqual(hopefully_node_37.getParent(), node_50);
    try testing.expectEqual(hopefully_node_37.left, null);
    try testing.expectEqual(hopefully_node_37.right, null);
    const hopefully_node_80 = node_50.right.?;
    try testing.expectEqual(hopefully_node_80.key, 80);
    try testing.expect(hopefully_node_80.getColor() == .black);
    try testing.expectEqual(hopefully_node_80.getParent(), node_50);
    try testing.expectEqual(hopefully_node_80.left.?.key, 70);
    try testing.expectEqual(hopefully_node_80.right, null);
    const hopefully_node_70 = hopefully_node_80.left.?;
    try testing.expectEqual(hopefully_node_70.key, 70);
    try testing.expect(hopefully_node_70.getColor() == .red);
    try testing.expectEqual(hopefully_node_70.getParent(), hopefully_node_80);
    try testing.expectEqual(hopefully_node_70.left, null);
    try testing.expectEqual(hopefully_node_70.right, null);
    // left subtree
    const hopefully_node_30 = hopefully_node_35.left.?;
    try testing.expectEqual(hopefully_node_30.key, 30);
    try testing.expectEqual(hopefully_node_30.getParent(), hopefully_node_35);
    try testing.expect(hopefully_node_30.getColor() == .black);
    try testing.expectEqual(hopefully_node_30.left.?.key, 20);
    try testing.expectEqual(hopefully_node_30.right.?.key, 34);
    const hopefully_node_20 = hopefully_node_30.left.?;
    try testing.expectEqual(hopefully_node_20.key, 20);
    try testing.expect(hopefully_node_20.getColor() == .black);
    try testing.expectEqual(hopefully_node_20.getParent(), hopefully_node_30);
    try testing.expectEqual(hopefully_node_20.left, null);
    try testing.expectEqual(hopefully_node_20.right, null);
    const hopefully_node_34 = hopefully_node_30.right.?;
    try testing.expectEqual(hopefully_node_34.key, 34);
    try testing.expect(hopefully_node_34.getColor() == .black);
    try testing.expectEqual(hopefully_node_34.getParent(), hopefully_node_30);
    try testing.expectEqual(hopefully_node_34.left, null);
    try testing.expectEqual(hopefully_node_34.right, null);
}
test "deletion_black_node_successor_case_2_then_4" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 10, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_m10 = try allocator.create(Node);
    defer allocator.destroy(node_m10);
    node_m10.* = Node.init(.{ .key = -10, .color = .black, .parent = root, .left = null, .right = null });

    const node_m20 = try allocator.create(Node);
    defer allocator.destroy(node_m20);
    node_m20.* = Node.init(.{ .key = -20, .color = .black, .parent = node_m10, .left = null, .right = null });

    const node_m5 = try allocator.create(Node);
    defer allocator.destroy(node_m5);
    node_m5.* = Node.init(.{ .key = -5, .color = .black, .parent = node_m10, .left = null, .right = null });

    node_m10.left = node_m20;
    node_m10.right = node_m5;
    // right subtree

    const node_40 = try allocator.create(Node);
    defer allocator.destroy(node_40);
    node_40.* = Node.init(.{ .key = 40, .color = .black, .parent = root, .left = null, .right = null });

    const node_20 = try allocator.create(Node);
    defer allocator.destroy(node_20);
    node_20.* = Node.init(.{ .key = 20, .color = .black, .parent = node_40, .left = null, .right = null });

    const node_60 = try allocator.create(Node);
    defer allocator.destroy(node_60);
    node_60.* = Node.init(.{ .key = 60, .color = .red, .parent = node_40, .left = null, .right = null });

    node_40.left = node_20;
    node_40.right = node_60;

    const node_50 = try allocator.create(Node);
    defer allocator.destroy(node_50);
    node_50.* = Node.init(.{ .key = 50, .color = .black, .parent = node_60, .left = null, .right = null });

    const node_80 = try allocator.create(Node);
    defer allocator.destroy(node_80);
    node_80.* = Node.init(.{ .key = 80, .color = .black, .parent = node_60, .left = null, .right = null });

    node_60.left = node_50;
    node_60.right = node_80;

    root.left = node_m10;
    root.right = node_40;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(10).?);

    //
    //
    // REMOVE--->    ___10B___           parent is black             ___20B___
    //              /         \          sibling is red            /         \
    //           -10B         40B        s.children aren't red    -10B         60B
    //          /    \       /   \       --CASE 2 ROTATE-->      /    \       /   \
    //       -20B    -5B |20B|   60R       LEFT ROTATE         -20B  -5B    40R   80B
    //   SUCCESSOR IS 20----^   /   \      SIBLING 60                      /   \
    //                        50B    80B                       REMOVE--> 20    50B
    //
    //
    //   CASE 4                                         ___20B___
    //   20'S parent is RED                           /         \
    //   sibling is BLACK                            -10B         60B
    //   sibling's children are NOT RED             /    \       /   \
    //       so we push parent's                  -20B  -5B    40B   80B
    //       redness down to the sibling                      /   \
    //       and remove node                      REMOVED--> X    50R
    //
    try checkTreeEqual(rb_tree, [_]i32{ -20, -10, -5, 20, 40, 50, 60, 80 });

    const hopefully_node_20 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_20.key, 20);
    try testing.expectEqual(hopefully_node_20.getParent(), null);
    try testing.expect(hopefully_node_20.getColor() == .black);
    try testing.expectEqual(hopefully_node_20.left.?.key, -10);
    try testing.expectEqual(hopefully_node_20.right.?.key, 60);
    // test left subtree
    const hopefully_node_m10 = hopefully_node_20.left.?;
    try testing.expectEqual(hopefully_node_m10.key, -10);
    try testing.expect(hopefully_node_m10.getColor() == .black);
    try testing.expectEqual(hopefully_node_m10.getParent(), hopefully_node_20);
    try testing.expectEqual(hopefully_node_m10.left.?.key, -20);
    try testing.expectEqual(hopefully_node_m10.right.?.key, -5);
    const hopefully_node_m20 = hopefully_node_m10.left.?;
    try testing.expectEqual(hopefully_node_m20.key, -20);
    try testing.expect(hopefully_node_m20.getColor() == .black);
    try testing.expectEqual(hopefully_node_m20.getParent(), hopefully_node_m10);
    try testing.expectEqual(hopefully_node_m20.left, null);
    try testing.expectEqual(hopefully_node_m20.right, null);
    const hopefully_node_m5 = hopefully_node_m10.right.?;
    try testing.expectEqual(hopefully_node_m5.key, -5);
    try testing.expect(hopefully_node_m5.getColor() == .black);
    try testing.expectEqual(hopefully_node_m5.getParent(), hopefully_node_m10);
    try testing.expectEqual(hopefully_node_m5.left, null);
    try testing.expectEqual(hopefully_node_m5.right, null);
    // test right subtree
    const hopefully_node_60 = hopefully_node_20.right.?;
    try testing.expectEqual(hopefully_node_60.key, 60);
    try testing.expect(hopefully_node_60.getColor() == .black);
    try testing.expectEqual(hopefully_node_60.getParent(), hopefully_node_20);
    try testing.expectEqual(hopefully_node_60.left.?.key, 40);
    try testing.expectEqual(hopefully_node_60.right.?.key, 80);
    const hopefully_node_80 = hopefully_node_60.right.?;
    try testing.expectEqual(hopefully_node_80.key, 80);
    try testing.expect(hopefully_node_80.getColor() == .black);
    try testing.expectEqual(hopefully_node_80.getParent(), hopefully_node_60);
    try testing.expectEqual(hopefully_node_80.left, null);
    try testing.expectEqual(hopefully_node_80.right, null);
    const hopefully_node_40 = hopefully_node_60.left.?;
    try testing.expectEqual(hopefully_node_40.key, 40);
    try testing.expect(hopefully_node_40.getColor() == .black);
    try testing.expectEqual(hopefully_node_40.getParent(), hopefully_node_60);
    try testing.expectEqual(hopefully_node_40.left, null);
    try testing.expectEqual(hopefully_node_40.right.?.key, 50);
    const hopefully_node_50 = hopefully_node_40.right.?;
    try testing.expectEqual(hopefully_node_50.key, 50);
    try testing.expect(hopefully_node_50.getColor() == .red);
    try testing.expectEqual(hopefully_node_50.getParent(), hopefully_node_40);
    try testing.expectEqual(hopefully_node_50.left, null);
    try testing.expectEqual(hopefully_node_50.right, null);
}
test "mirror_deletion_black_node_successor_case_2_then_4" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 20, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_10 = try allocator.create(Node);
    defer allocator.destroy(node_10);
    node_10.* = Node.init(.{ .key = 10, .color = .black, .parent = root, .left = null, .right = null });

    const node_8 = try allocator.create(Node);
    defer allocator.destroy(node_8);
    node_8.* = Node.init(.{ .key = 8, .color = .red, .parent = node_10, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .black, .parent = node_10, .left = null, .right = null });

    node_10.left = node_8;
    node_10.right = node_15;

    const node_6 = try allocator.create(Node);
    defer allocator.destroy(node_6);
    node_6.* = Node.init(.{ .key = 6, .color = .black, .parent = node_8, .left = null, .right = null });

    const node_9 = try allocator.create(Node);
    defer allocator.destroy(node_9);
    node_9.* = Node.init(.{ .key = 9, .color = .black, .parent = node_8, .left = null, .right = null });

    node_8.left = node_6;
    node_8.right = node_9;
    // right subtree

    const node_30 = try allocator.create(Node);
    defer allocator.destroy(node_30);
    node_30.* = Node.init(.{ .key = 30, .color = .black, .parent = root, .left = null, .right = null });

    const node_25 = try allocator.create(Node);
    defer allocator.destroy(node_25);
    node_25.* = Node.init(.{ .key = 25, .color = .black, .parent = node_30, .left = null, .right = null });

    const node_35 = try allocator.create(Node);
    defer allocator.destroy(node_35);
    node_35.* = Node.init(.{ .key = 35, .color = .black, .parent = node_30, .left = null, .right = null });

    node_30.left = node_25;
    node_30.right = node_35;

    root.left = node_10;
    root.right = node_30;
    var rb_tree: Tree = .{ .root = root, .size = 9 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(15).?);

    //
    //
    //          ___20B___        Parent is black               ___20B___
    //         /         \       Sibling is red               /         \
    //      10B          30B     s.children are black        8B        30B
    //     /   \        /   \    ======>                    /  \       /   \
    //   8R    15B    25B   35B   Case 2                  6B   10R   25B   35B
    //  /  \    ^----Remove    left rotate                    /   \
    // 6B  9B                     on 10                      9B   |15B|
    //
    //
    //
    // Parent is red                                  ___20B___
    // Sibling is black      CASE 4                  /         \
    // s.children are black   ===>                  8B        30B
    //  switch the colors of the parent            /  \       /   \
    //  and the sibling                          6B   10B   25B   35B
    //                                               /   \
    //                                             9R     X
    //
    const node_20 = rb_tree.root.?;
    try testing.expectEqual(node_20.key, 20);
    try testing.expect(node_20.getColor() == .black);
    try testing.expectEqual(node_20.getParent(), null);
    try testing.expectEqual(node_20.left.?.key, 8);
    try testing.expectEqual(node_20.right.?.key, 30);
    // right subtree
    const hopefully_node_30 = node_20.right.?;
    try testing.expectEqual(hopefully_node_30.key, 30);
    try testing.expect(hopefully_node_30.getColor() == .black);
    try testing.expectEqual(hopefully_node_30.getParent(), node_20);
    try testing.expectEqual(hopefully_node_30.left.?.key, 25);
    try testing.expectEqual(hopefully_node_30.right.?.key, 35);
    const hopefully_node_25 = hopefully_node_30.left.?;
    try testing.expectEqual(hopefully_node_25.key, 25);
    try testing.expect(hopefully_node_25.getColor() == .black);
    try testing.expectEqual(hopefully_node_25.getParent(), hopefully_node_30);
    try testing.expectEqual(hopefully_node_25.left, null);
    try testing.expectEqual(hopefully_node_25.right, null);
    const hopefully_node_35 = hopefully_node_30.right.?;
    try testing.expectEqual(hopefully_node_35.key, 35);
    try testing.expect(hopefully_node_35.getColor() == .black);
    try testing.expectEqual(hopefully_node_35.getParent(), hopefully_node_30);
    try testing.expectEqual(hopefully_node_35.left, null);
    try testing.expectEqual(hopefully_node_35.right, null);
    // left subtree
    const hopefully_node_8 = node_20.left.?;
    try testing.expectEqual(hopefully_node_8.key, 8);
    try testing.expectEqual(hopefully_node_8.getParent(), node_20);
    try testing.expect(hopefully_node_8.getColor() == .black);
    try testing.expectEqual(hopefully_node_8.left.?.key, 6);
    try testing.expectEqual(hopefully_node_8.right.?.key, 10);
    const hopefully_node_6 = hopefully_node_8.left.?;
    try testing.expectEqual(hopefully_node_6.key, 6);
    try testing.expect(hopefully_node_6.getColor() == .black);
    try testing.expectEqual(hopefully_node_6.getParent(), hopefully_node_8);
    try testing.expectEqual(hopefully_node_6.left, null);
    try testing.expectEqual(hopefully_node_6.right, null);
    const hopefully_node_10 = hopefully_node_8.right.?;
    try testing.expectEqual(hopefully_node_10.key, 10);
    try testing.expect(hopefully_node_10.getColor() == .black);
    try testing.expectEqual(hopefully_node_10.getParent(), hopefully_node_8);
    try testing.expectEqual(hopefully_node_10.left, node_9);
    try testing.expectEqual(hopefully_node_10.right, null);
    const hopefully_node_9 = hopefully_node_10.left.?;
    try testing.expectEqual(hopefully_node_9.key, 9);
    try testing.expect(hopefully_node_9.getColor() == .red);
    try testing.expectEqual(hopefully_node_9.getParent(), hopefully_node_10);
    try testing.expectEqual(hopefully_node_9.left, null);
    try testing.expectEqual(hopefully_node_9.right, null);
}
test "delete_tree_one_by_one" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    const Node = Tree.Node;
    var allocator = testing.allocator;

    const root = try allocator.create(Node);
    defer allocator.destroy(root);
    root.* = Node.init(.{ .key = 20, .color = .black, .parent = null, .left = null, .right = null });

    // left subtree

    const node_10 = try allocator.create(Node);
    defer allocator.destroy(node_10);
    node_10.* = Node.init(.{ .key = 10, .color = .black, .parent = root, .left = null, .right = null });

    const node_5 = try allocator.create(Node);
    defer allocator.destroy(node_5);
    node_5.* = Node.init(.{ .key = 5, .color = .red, .parent = node_10, .left = null, .right = null });

    const node_15 = try allocator.create(Node);
    defer allocator.destroy(node_15);
    node_15.* = Node.init(.{ .key = 15, .color = .red, .parent = node_10, .left = null, .right = null });

    node_10.left = node_5;
    node_10.right = node_15;
    // right subtree

    const node_38 = try allocator.create(Node);
    defer allocator.destroy(node_38);
    node_38.* = Node.init(.{ .key = 38, .color = .red, .parent = root, .left = null, .right = null });

    const node_28 = try allocator.create(Node);
    defer allocator.destroy(node_28);
    node_28.* = Node.init(.{ .key = 28, .color = .black, .parent = node_38, .left = null, .right = null });

    const node_48 = try allocator.create(Node);
    defer allocator.destroy(node_48);
    node_48.* = Node.init(.{ .key = 48, .color = .black, .parent = node_38, .left = null, .right = null });

    node_38.left = node_28;
    node_38.right = node_48;
    // node_28 subtree

    const node_23 = try allocator.create(Node);
    defer allocator.destroy(node_23);
    node_23.* = Node.init(.{ .key = 23, .color = .red, .parent = node_28, .left = null, .right = null });

    const node_29 = try allocator.create(Node);
    defer allocator.destroy(node_29);
    node_29.* = Node.init(.{ .key = 29, .color = .red, .parent = node_28, .left = null, .right = null });

    node_28.left = node_23;
    node_28.right = node_29;
    // node 48 subtree

    const node_41 = try allocator.create(Node);
    defer allocator.destroy(node_41);
    node_41.* = Node.init(.{ .key = 41, .color = .red, .parent = node_48, .left = null, .right = null });

    const node_49 = try allocator.create(Node);
    defer allocator.destroy(node_49);
    node_49.* = Node.init(.{ .key = 49, .color = .red, .parent = node_48, .left = null, .right = null });

    node_48.left = node_41;
    node_48.right = node_49;

    root.left = node_10;
    root.right = node_38;

    //
    //       ______20______
    //      /              \
    //    10B           ___38R___
    //   /   \         /         \
    // 5R    15R      28B         48B
    //               /  \        /   \
    //             23R  29R     41R   49R
    //
    var rb_tree: Tree = .{ .root = root, .size = 11 };
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(49).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(38).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(28).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(10).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(5).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(15).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(48).?);

    //
    // We're left with
    //                 __23B__
    //                /       \
    //              20B       41B
    //                       /
    //                      29R
    //
    var hopefully_node_23 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_23.key, 23);
    try testing.expect(hopefully_node_23.getColor() == .black);
    try testing.expectEqual(hopefully_node_23.getParent(), null);
    try testing.expectEqual(hopefully_node_23.left.?.key, 20);
    try testing.expectEqual(hopefully_node_23.right.?.key, 41);
    const node_20 = hopefully_node_23.left.?;
    try testing.expect(node_20.getColor() == .black);
    try testing.expectEqual(node_20.getParent(), hopefully_node_23);
    try testing.expectEqual(node_20.left, null);
    try testing.expectEqual(node_20.right, null);
    var hopefully_node_41 = hopefully_node_23.right.?;
    try testing.expect(hopefully_node_41.getColor() == .black);
    try testing.expectEqual(hopefully_node_41.getParent(), hopefully_node_23);
    try testing.expectEqual(hopefully_node_41.key, 41);
    try testing.expectEqual(hopefully_node_41.left.?.key, 29);
    try testing.expectEqual(hopefully_node_41.right, null);
    var hopefully_node_29 = hopefully_node_41.left.?;
    try testing.expectEqual(hopefully_node_29.key, 29);
    try testing.expect(hopefully_node_29.getColor() == .red);
    try testing.expectEqual(hopefully_node_29.left, null);
    try testing.expectEqual(hopefully_node_29.right, null);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(20).?);

    //
    //   _29B_
    //  /     \
    // 23B    41B
    //
    hopefully_node_29 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_29.key, 29);
    try testing.expect(hopefully_node_29.getColor() == .black);
    try testing.expectEqual(hopefully_node_29.getParent(), null);
    try testing.expectEqual(hopefully_node_29.left.?.key, 23);
    try testing.expectEqual(hopefully_node_29.right.?.key, 41);
    hopefully_node_23 = hopefully_node_29.left.?;
    try testing.expectEqual(hopefully_node_23.getParent(), hopefully_node_29);
    try testing.expect(hopefully_node_23.getColor() == .black);
    try testing.expectEqual(hopefully_node_23.left, null);
    try testing.expectEqual(hopefully_node_23.right, null);
    hopefully_node_41 = hopefully_node_29.right.?;
    try testing.expectEqual(hopefully_node_41.getParent(), hopefully_node_29);
    try testing.expect(hopefully_node_41.getColor() == .black);
    try testing.expectEqual(hopefully_node_41.left, null);
    try testing.expectEqual(hopefully_node_41.right, null);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(29).?);

    //
    //    41B
    //   /
    // 23R
    //
    hopefully_node_41 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_41.key, 41);
    try testing.expect(hopefully_node_41.getColor() == .black);
    try testing.expectEqual(hopefully_node_41.getParent(), null);
    try testing.expectEqual(hopefully_node_41.right, null);
    hopefully_node_23 = hopefully_node_41.left.?;
    try testing.expectEqual(hopefully_node_23.key, 23);
    try testing.expect(hopefully_node_23.getColor() == .red);
    try testing.expectEqual(hopefully_node_23.getParent(), hopefully_node_41);
    try testing.expectEqual(hopefully_node_23.left, null);
    try testing.expectEqual(hopefully_node_23.right, null);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(41).?);

    //
    // 23B
    //
    hopefully_node_23 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_23.key, 23);
    try testing.expect(hopefully_node_23.getColor() == .black);
    try testing.expectEqual(hopefully_node_23.getParent(), null);
    try testing.expectEqual(hopefully_node_23.left, null);
    try testing.expectEqual(hopefully_node_23.right, null);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(23).?);
    try testing.expectEqual(rb_tree.root, null);
}
test "add_delete_random_order" {
    const Tree = RBTreeUnmanaged(
        i32,
        void,
        void,
        rbtreelib.defaultOrder(i32),
        .{},
        .{},
    );
    var allocator = testing.allocator;

    var rb_tree = Tree.init();

    const node_90 = (try rb_tree.insert(allocator, 90, void{}, .no_clobber)).node;
    defer allocator.destroy(node_90);
    const node_70 = (try rb_tree.insert(allocator, 70, void{}, .no_clobber)).node;
    defer allocator.destroy(node_70);
    const node_43 = (try rb_tree.insert(allocator, 43, void{}, .no_clobber)).node;
    defer allocator.destroy(node_43);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(70).?);
    const node_24 = (try rb_tree.insert(allocator, 24, void{}, .no_clobber)).node;
    defer allocator.destroy(node_24);
    const node_14 = (try rb_tree.insert(allocator, 14, void{}, .no_clobber)).node;
    defer allocator.destroy(node_14);
    const node_93 = (try rb_tree.insert(allocator, 93, void{}, .no_clobber)).node;
    defer allocator.destroy(node_93);
    const node_47 = (try rb_tree.insert(allocator, 47, void{}, .no_clobber)).node;
    defer allocator.destroy(node_47);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(47).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(90).?);
    const node_57 = (try rb_tree.insert(allocator, 57, void{}, .no_clobber)).node;
    defer allocator.destroy(node_57);
    const node_1 = (try rb_tree.insert(allocator, 1, void{}, .no_clobber)).node;
    defer allocator.destroy(node_1);
    const node_60 = (try rb_tree.insert(allocator, 60, void{}, .no_clobber)).node;
    defer allocator.destroy(node_60);
    const node_47_v2 = (try rb_tree.insert(allocator, 47, void{}, .no_clobber)).node;
    defer allocator.destroy(node_47_v2);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(47).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(1).?);
    // we remove a node without deallocating it
    _ = Tree.implementation.removeNode(&rb_tree.root, void{}, rb_tree.find(43).?);
    const node_49 = (try rb_tree.insert(allocator, 49, void{}, .no_clobber)).node;
    defer allocator.destroy(node_49);

    //
    // well, the results aren't the same, but I'll assume that the algorithms are different
    // Nevertheless, what we're left with is a perfectly valid RedBlack Tree, and, I'd argue, even betterly
    // balanced than the one from the visualization
    //
    //                             VISUALIZATION TREE
    //                                ____24B____
    //                               /           \
    //                             14B           60R
    //                                          /   \
    //                                        57B    93B
    //                                       /
    //                                     49R
    //
    //                                OUR TREE
    //                                ______57B______
    //                               /               \
    //                           __24B__           __60B__
    //                          /       \                 \
    //                        14R       49R               93R
    //
    try checkTreeEqual(rb_tree, [_]i32{ 14, 24, 49, 57, 60, 93 });

    const hopefully_node_57 = rb_tree.root.?;
    try testing.expectEqual(hopefully_node_57.key, 57);
    try testing.expectEqual(hopefully_node_57.getParent(), null);
    try testing.expect(hopefully_node_57.getColor() == .black);
    try testing.expectEqual(hopefully_node_57.left.?.key, 24);
    try testing.expectEqual(hopefully_node_57.right.?.key, 60);
    // right subtree
    const hopefully_node_60 = hopefully_node_57.right.?;
    try testing.expectEqual(hopefully_node_60.key, 60);
    try testing.expect(hopefully_node_60.getColor() == .black);
    try testing.expectEqual(hopefully_node_60.getParent(), hopefully_node_57);
    try testing.expectEqual(hopefully_node_60.right.?.key, 93);
    try testing.expectEqual(hopefully_node_60.left, null);
    const hopefully_node_93 = hopefully_node_60.right.?;
    try testing.expectEqual(hopefully_node_93.key, 93);
    try testing.expect(hopefully_node_93.getColor() == .red);
    try testing.expectEqual(hopefully_node_93.getParent(), hopefully_node_60);
    try testing.expectEqual(hopefully_node_93.left, null);
    try testing.expectEqual(hopefully_node_93.right, null);
    // left subtree
    const hopefully_node_24 = hopefully_node_57.left.?;
    try testing.expectEqual(hopefully_node_24.key, 24);
    try testing.expectEqual(hopefully_node_24.getParent(), hopefully_node_57);
    try testing.expect(hopefully_node_24.getColor() == .black);
    try testing.expectEqual(hopefully_node_24.left.?.key, 14);
    try testing.expectEqual(hopefully_node_24.right.?.key, 49);
    const hopefully_node_14 = hopefully_node_24.left.?;
    try testing.expectEqual(hopefully_node_14.key, 14);
    try testing.expectEqual(hopefully_node_14.getParent(), hopefully_node_24);
    try testing.expect(hopefully_node_14.getColor() == .red);
    try testing.expectEqual(hopefully_node_14.left, null);
    try testing.expectEqual(hopefully_node_14.right, null);
    const hopefully_node_49 = hopefully_node_24.right.?;
    try testing.expectEqual(hopefully_node_49.key, 49);
    try testing.expectEqual(hopefully_node_49.getParent(), hopefully_node_24);
    try testing.expect(hopefully_node_49.getColor() == .red);
    try testing.expectEqual(hopefully_node_49.left, null);
    try testing.expectEqual(hopefully_node_49.right, null);
}
