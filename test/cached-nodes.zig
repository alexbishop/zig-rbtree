const std = @import("std");
const rbtreelib = @import("rbtree");

test "cache first" {
    const Tree = rbtreelib.RBTree(
        usize,
        void,
        void,
        rbtreelib.defaultOrder(usize),
        .{
            .cache_nodes = .{
                .first = true,
            },
        },
        .{},
    );

    // let's initialise a tree
    var tree = try Tree.initFromSortedSlice(
        std.testing.allocator,
        void{},
        &[_]usize{ 1, 40, 100 },
    );
    defer tree.deinit();

    // at this point the tree looks like
    //
    //       40
    //      /  \
    //     1   100
    //

    // the current first should be 1
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 1);

    // let's try adding 2
    try tree.add(2);

    // at this point, the tree should look like
    //
    //       40
    //      /  \
    //     1   100
    //      \
    //       2
    //

    // the cached first should still be 1
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 1);

    // let's add a new minimum
    try tree.add(0);
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 0);

    // let's try deleting this min
    _ = tree.remove(0);
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 1);

    // let's remove the rest one-by-one
    _ = tree.remove(1);
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 2);

    _ = tree.remove(2);
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 40);

    _ = tree.remove(40);
    try std.testing.expect(tree.unmanaged.cache.first != null);
    try std.testing.expect(tree.unmanaged.cache.first.?.key == 100);

    _ = tree.remove(100);
    // at this point the tree is empty
    try std.testing.expect(tree.count() == 0);
    try std.testing.expect(tree.unmanaged.cache.first == null);
}

test "cache last" {
    const Tree = rbtreelib.RBTree(
        usize,
        void,
        void,
        rbtreelib.defaultOrder(usize),
        .{
            .cache_nodes = .{
                .last = true,
            },
        },
        .{},
    );

    // let's initialise a tree
    var tree = try Tree.initFromSortedSlice(
        std.testing.allocator,
        void{},
        &[_]usize{ 1, 40, 100 },
    );
    defer tree.deinit();

    // at this point the tree looks like
    //
    //       40
    //      /  \
    //     1   100
    //

    // the current last should be 100
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 100);

    // let's try adding 2
    try tree.add(50);

    // at this point, the tree should look like
    //
    //       40
    //      /  \
    //     1   100
    //        /
    //       50
    //

    // the cached last should still be 1
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 100);

    // let's add a new maximum
    try tree.add(200);
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 200);

    // let's try deleting this max and testing
    _ = tree.remove(200);
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 100);

    _ = tree.remove(100);
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 50);

    _ = tree.remove(50);
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 40);

    _ = tree.remove(40);
    try std.testing.expect(tree.unmanaged.cache.last != null);
    try std.testing.expect(tree.unmanaged.cache.last.?.key == 1);

    _ = tree.remove(1);
    // at this point the tree is empty
    try std.testing.expect(tree.count() == 0);
    try std.testing.expect(tree.unmanaged.cache.last == null);
}
