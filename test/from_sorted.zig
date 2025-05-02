const std = @import("std");
const rbtreelib = @import("rbtree");

pub const DefaultRBTreeUnmanaged = rbtreelib.DefaultRBTreeUnmanaged;
const Tree = DefaultRBTreeUnmanaged(u16, void);
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

        if (n.getColor() == .black) {
            return left_depth + 1;
        } else {
            return left_depth;
        }
    } else {
        return 0;
    }
}

fn checkMatchesSlice(node: ?*Node, slice: []const u16) bool {
    var current_node = node;
    for (slice) |item| {
        if (item != current_node.?.key) return false;
        current_node = current_node.?.next();
    }
    if (current_node != null) return false;
    return true;
}

const AllocatorWithLimit = struct {
    limit: usize,
    wrapped: std.mem.Allocator,

    pub fn allocator(self: *@This()) std.mem.Allocator {
        const VTable = struct {
            pub fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
                const a: *AllocatorWithLimit = @alignCast(@ptrCast(ptr));
                if (a.limit <= 0) return null;
                a.limit -= 1;
                return a.wrapped.vtable.alloc(a.wrapped.ptr, len, alignment, ret_addr);
            }
            pub fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
                const a: *AllocatorWithLimit = @alignCast(@ptrCast(ptr));
                if (a.limit <= 0) return false;
                a.limit -= 1;
                return a.wrapped.vtable.resize(a.wrapped.ptr, memory, alignment, new_len, ret_addr);
            }
            pub fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
                const a: *AllocatorWithLimit = @alignCast(@ptrCast(ptr));
                if (a.limit <= 0) return null;
                a.limit -= 1;
                return a.wrapped.vtable.remap(a.wrapped.ptr, memory, alignment, new_len, ret_addr);
            }
            pub fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
                const a: *AllocatorWithLimit = @alignCast(@ptrCast(ptr));
                return a.wrapped.vtable.free(a.wrapped.ptr, memory, alignment, ret_addr);
            }
        };

        const vtable = std.mem.Allocator.VTable{
            .alloc = VTable.alloc,
            .resize = VTable.resize,
            .remap = VTable.remap,
            .free = VTable.free,
        };

        return std.mem.Allocator{
            .ptr = self,
            .vtable = &vtable,
        };
    }
};

test "from sorted slice" {
    var test_slice: [256]u16 = undefined;
    for (test_slice[0..], 0..) |*item, i| item.* = @intCast(i);
    // at this point test_slice = .{0, 1, 2, ...}

    const allocator = std.testing.allocator;

    // run our tests
    for (0..(test_slice.len)) |l| {
        var tree = try Tree.initFromSortedSlice(allocator, test_slice[0..l]);
        defer tree.deinit(allocator);

        _ = try getBlackDepth(tree.root);
        std.debug.assert(checkMatchesSlice(tree.findMin(), test_slice[0..l]));
    }
}

test "when allocator fails" {
    var test_slice: [256]u16 = undefined;
    for (test_slice[0..], 0..) |*item, i| item.* = @intCast(i);
    // at this point test_slice = .{0, 1, 2, ...}

    const allocator = std.testing.allocator;

    // check that we correctly deal with a failed allocator
    for (0..255) |limit| {
        var limited_allocator = AllocatorWithLimit{
            .limit = limit,
            .wrapped = allocator,
        };

        const res = Tree.initFromSortedSlice(
            limited_allocator.allocator(),
            test_slice[0..],
        );
        errdefer {
            var tree = res catch unreachable;
            tree.deinit(limited_allocator.allocator());
        }
        try std.testing.expectError(
            Tree.InitFromSortedError.OutOfMemory,
            res,
        );
    }
}

// check that we correctly deal with the case where the list isn't long enough
const KVSliceIterator = struct {
    data: []const u16,
    index: usize = 0,

    pub fn next(self: *KVSliceIterator) ?Tree.KV {
        if (self.index == self.data.len) {
            return null;
        } else {
            const k = self.data[self.index];
            self.index += 1;
            return .{ .key = k, .value = undefined };
        }
    }
};

test "undersized iterator" {
    var test_slice: [64]u16 = undefined;
    for (test_slice[0..], 0..) |*item, i| item.* = @intCast(i);
    // at this point test_slice = .{0, 1, 2, ...}

    // note that if something isn't correctly deallator, then
    // the test will give an error at the end
    const allocator = std.testing.allocator;

    for (0..(test_slice.len - 1)) |limit1| {
        for ((limit1 + 1)..(test_slice.len)) |limit2| {
            const res = Tree.initFromSortedKVIterator(
                KVSliceIterator,
                allocator,
                limit2,
                KVSliceIterator{
                    .data = test_slice[0..limit1],
                    .index = 0,
                },
            );
            errdefer {
                var tree = res catch unreachable;
                tree.deinit(allocator);
            }
            try std.testing.expectError(
                Tree.InitFromSortedError.ReachedEndOfIterator,
                res,
            );
        }
    }
}
