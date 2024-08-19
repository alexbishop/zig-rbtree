//! This file defines red-black tree nodes.
const std = @import("std");

pub const NodeColor = enum(u1) {
    red = 0,
    black = 1,
};

pub const Direction = enum {
    left,
    right,
    pub fn invert(direction: Direction) Direction {
        switch (direction) {
            .left => return .right,
            .right => return .left,
        }
    }
};

/// Options which can be passed to a red-black tree
pub const Options = struct {
    /// Indicates if each node of the tree should maintain a count of the
    /// number of elements in its associated subtree
    store_subtree_sizes: bool = false,
    /// Indicates if the color of a red-black tree node should be stored
    /// as the least-significant bit of the parent pointer
    store_color_in_parent_pointer: bool = true,
    /// Gives any additional data which should be stored as part of each node.
    /// This type is used in augmented red-black trees.
    AdditionalNodeData: type = void,
};

const NodeTag = opaque {};

/// Returns `true` if the given type is a Node of a red-black tree.
///
/// Note that if the type is a node, then you can obtain the arguments which
/// were passed to the `Node` function as `N.args`.
pub fn isNode(comptime N: type) bool {
    switch (@typeInfo(N)) {
        .Struct => |_| {
            if (@hasDecl(N, "tag")) {
                switch (@typeInfo(@TypeOf(N.tag))) {
                    .Type => return (N.tag == NodeTag),
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

/// A node which can be inserted into a red-black tree.
///
/// Arguments:
///  * `K`: the type used for keys in the red-black tree
///  * `V`: the type used for values in the red-black tree
///  * `options`: additional options which change how the red-black tree operates
pub fn Node(
    comptime K: type,
    comptime V: type,
    comptime options: Options,
) type {
    return struct {
        const Self = @This();

        comptime {
            if (options.store_color_in_parent_pointer) {
                if (@alignOf(Self) <= 1) {
                    @compileError(
                        \\Alignment must be at least 2 for this optimisation.
                        \\  To fix this, we recomend that you turn off the
                        \\   `store_color_in_parent_pointer` optimisation.
                    );
                }
            }
        }

        const tag = NodeTag;
        /// The arguments which were used to construct the node
        pub const args = .{
            .K = K,
            .V = V,
            .options = options,
        };

        impl_parent: if (options.store_color_in_parent_pointer) void else ?*Self,
        impl_color: if (options.store_color_in_parent_pointer) void else NodeColor,
        impl_parent_and_color: if (options.store_color_in_parent_pointer) usize else void,

        subtree_size: if (options.store_subtree_sizes) usize else void,

        left: ?*Self,
        right: ?*Self,
        key: K,
        value: V,

        additional_data: options.AdditionalNodeData,

        pub const InitArgs = struct {
            parent: ?*Self = null,
            color: NodeColor = .black,
            subtree_size: if (options.store_subtree_sizes) usize else void = if (options.store_subtree_sizes) 1 else void{},
            left: ?*Self = null,
            right: ?*Self = null,
            key: K = undefined,
            value: V = undefined,
            additional_data: options.AdditionalNodeData = undefined,
        };

        pub fn init(init_args: InitArgs) Self {
            var result: Self = undefined;

            result.setParent(init_args.parent);
            result.setColor(init_args.color);
            result.subtree_size = init_args.subtree_size;
            result.left = init_args.left;
            result.right = init_args.right;
            result.key = init_args.key;
            result.value = init_args.value;
            result.additional_data = init_args.additional_data;

            return result;
        }

        pub fn getParent(self: Self) ?*Self {
            if (options.store_color_in_parent_pointer) {
                const parent_address = self.impl_parent_and_color & ~@as(usize, 1);
                if (parent_address == 0) {
                    return null;
                } else {
                    return @ptrFromInt(parent_address);
                }
            } else {
                return self.impl_parent;
            }
        }

        pub fn setParent(self: *Self, new_parent: ?*Self) void {
            if (options.store_color_in_parent_pointer) {
                if (new_parent) |p| {
                    self.impl_parent_and_color = (self.impl_parent_and_color & 1) | @intFromPtr(p);
                } else {
                    self.impl_parent_and_color &= 1;
                }
            } else {
                self.impl_parent = new_parent;
            }
        }

        pub fn getColor(self: Self) NodeColor {
            if (options.store_color_in_parent_pointer) {
                return @enumFromInt(self.impl_parent_and_color & 1);
            } else {
                return self.impl_color;
            }
        }

        pub fn setColor(self: *Self, new_color: NodeColor) void {
            if (options.store_color_in_parent_pointer) {
                self.impl_parent_and_color = (self.impl_parent_and_color & ~@as(usize, 1)) | @intFromEnum(new_color);
            } else {
                self.impl_color = new_color;
            }
        }

        /// Checks if the node is the left of right child of its parent.
        /// For the root node, this funciton returns `null`.
        pub fn getDirection(self: *const Self) ?Direction {
            if (self.getParent()) |parent| {
                if (parent.left == self) {
                    return .left;
                } else {
                    return .right;
                }
            } else {
                return null;
            }
        }

        pub fn getChild(self: Self, direction: Direction) ?*Self {
            switch (direction) {
                .left => return self.left,
                .right => return self.right,
            }
        }

        pub fn setChild(self: *Self, direction: Direction, new_child: ?*Self) void {
            switch (direction) {
                .left => self.left = new_child,
                .right => self.right = new_child,
            }
        }

        /// Gets a pointer to the leftmost node in the subtree at the given root.
        pub fn getLeftmostInSubtree(root: *Self) *Self {
            var current = root;
            while (current.left) |n| {
                current = n;
            }
            return current;
        }

        /// Gets a pointer to the rightmost node in the subtree at the given root.
        pub fn getRightmostInSubtree(root: *Self) *Self {
            var current = root;
            while (current.right) |n| {
                current = n;
            }
            return current;
        }

        /// Obtains the next node in an in-order traversal.
        /// Alternatively, returns null if there is no such node.
        pub fn next(self: *const Self) ?*Self {
            if (self.right) |r| {
                // the next largest is in the subtree
                return r.getLeftmostInSubtree();
            }

            // if the next node is not in the subtree, then we
            //  need to move up the tree
            var parent: *Self = self.getParent() orelse return null;
            var current: ?*const Self = self;

            while (parent.right == current) {
                const grandparent: *Self = parent.getParent() orelse return null;

                current = parent;
                parent = grandparent;
            }

            return parent;
        }

        /// Obtains the previous node in an in-order traversal.
        /// Alternatively, returns null if there is no such node.
        pub fn prev(self: *const Self) ?*Self {
            if (self.left) |l| {
                return l.getRightmostInSubtree();
            }

            // if the next node is not in the subtree, then we
            //  need to move up the tree
            var parent: *Self = self.getParent() orelse return null;
            var current: ?*const Self = self;

            while (parent.left == current) {
                const grandparent: *Self = parent.getParent() orelse return null;

                current = parent;
                parent = grandparent;
            }

            return parent;
        }
    };
}
