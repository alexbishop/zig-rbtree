//! This file defines red-black tree nodes.
const std = @import("std");

/// Used to represent the colour of a node in the red-black tree structure.
///
/// This type is backed by a `u1` as, by default, our implementation stores
/// the colour of a node as the lowest order bit of the parent pointer.
pub const NodeColor = enum(u1) {
    red = 0,
    black = 1,
};

/// Corresponds to the left/right subtree of a node.
///
/// This type is provided to simplify our implementation.
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

/// Options which can be passed when creating a red-black tree implementation.
pub const Options = struct {
    /// Indicates if each node of the tree should maintain a count of the
    /// number of elements in its associated subtree
    store_subtree_sizes: bool = false,
    /// Indicates if the color of a red-black tree node should be stored
    /// as the least-significant bit of the parent pointer
    ///
    /// We allow for this feature to be disabled as it may cause issues on
    /// some compiler targets.
    store_color_in_parent_pointer: bool = true,
    /// Every node of the tree will have an additional field of this type.
    ///
    /// In particular, each node has a field of the following name and type:
    ///
    /// ```zig
    /// additional_data: options.AdditionalNodeData
    /// ```
    ///
    /// This feature is provided as it is usually required to implement augmented
    /// red-black trees. In partiuclar, such a field would be used to store the
    /// additional data of the augmented tree.
    AdditionalNodeData: type = void,
};

/// Used to tag types which were created using the `Node` type function.
///
/// It is intended that the programmer should not be able to use this type outside
/// of this file. Thus, it is not declared as public.
const NodeTag = opaque {};

/// Returns `true` if the given type is a Node of a red-black tree.
///
/// Note that if the type is a node, then you can obtain the arguments which
/// were passed to the `Node` function as `N.args`.
pub fn isNode(comptime N: type) bool {
    switch (@typeInfo(N)) {
        .@"struct" => |_| {
            if (@hasDecl(N, "tag")) {
                switch (@typeInfo(@TypeOf(N.tag))) {
                    .type => return (N.tag == NodeTag),
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
pub fn Node(
    /// The type of keys stored in the node
    comptime K: type,
    /// The type of the values stored in the node, this can be `void`
    comptime V: type,
    /// Some options used to customise the node.
    ///
    /// Note that `.{}` can be used for the default options.
    /// For example:
    ///
    /// ```zig
    /// const N = Node(usize, void, .{});
    /// ```
    ///
    /// The above code will construct a node type with key type `usize`, value
    /// type `void`, and the default options.
    comptime options: Options,
) type {
    return struct {
        const Self = @This();

        comptime {
            if (options.store_color_in_parent_pointer) {
                if (@alignOf(Self) <= 1) {
                    @compileError(
                        \\You have enabled the feature `store_color_in_parent_pointer`.
                        \\ This feature requires the alignment of a pointer to Node to be
                        \\ at least 2. This then allows one bit of the parent pointer to
                        \\ be free to be used to store the node colour.
                        \\
                        \\ You can disable this feature by changing the options when creating
                        \\  a RBTree, RBTreeUnmanaged, RBTreeImplementation or Node
                    );
                }
            }
        }

        /// A hidden tag used to indicate that this type was created using the  `Node` function.
        const tag = NodeTag;
        /// The arguments which were passed to the `Node` function to create this type.
        pub const args = .{
            .K = K,
            .V = V,
            .options = options,
        };

        /// **Don't** use this field directly.
        ///
        /// If you want to read or manipulate the parent of the node, then use the
        /// `getParent` or `setParent` methods.
        impl_parent: if (options.store_color_in_parent_pointer) void else ?*Self,
        /// **Don't** use this field directly.
        ///
        /// If you want to read or manipulate the colour of the node, then use the
        /// `getColor` or `setColor` methods.
        impl_color: if (options.store_color_in_parent_pointer) void else NodeColor,
        /// **Don't** use this field directly.
        ///
        /// If you want to read or manipulate the parent or colour of a node, then
        /// you should use the `getParent`, `setParent`, `getColor`, or `getParent`
        /// function.
        impl_parent_and_color: if (options.store_color_in_parent_pointer) usize else void,

        /// If the `store_subtree_sizes` option is set, then this stores the size of the subtree
        /// rooted at this node.
        subtree_size: if (options.store_subtree_sizes) usize else void,

        /// The root of the left subtree of this node.
        left: ?*Self,
        /// The root of the right subtree of this node.
        right: ?*Self,
        /// The key stored in this node.
        key: K,
        /// The value associated to the key.
        value: V,

        /// Additional data which is store to implement augmented tree.
        /// The type of this value defaults to `void`.
        additional_data: options.AdditionalNodeData,

        /// The type passed to `init`.
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
        /// Initialises a node with the given values.
        ///
        /// This method is provides so as to avoid the need for calling
        /// `setColor` and `setParent`.
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

        /// Gets a pointer to the parent of the current node.
        ///
        /// You should always use this method instead of reading the
        /// variables `impl_parent_and_color` or `impl_parent` directly.
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

        /// Sets the parent of the node.
        ///
        /// You should always use this method instead of manipulating the
        /// variables `impl_parent_and_color` or `impl_parent` directly.
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

        /// Gets the color of the node.
        ///
        /// You should always use this method instead of reading the
        /// `impl_parent_and_color` or `impl_color` fields directly.
        pub fn getColor(self: Self) NodeColor {
            if (options.store_color_in_parent_pointer) {
                return @enumFromInt(self.impl_parent_and_color & 1);
            } else {
                return self.impl_color;
            }
        }

        /// Sets the color of the node.
        ///
        /// You should always use this method instead of modifying the
        /// `impl_parent_and_color` or `impl_color` fields directly.
        pub fn setColor(self: *Self, new_color: NodeColor) void {
            if (options.store_color_in_parent_pointer) {
                self.impl_parent_and_color = (self.impl_parent_and_color & ~@as(usize, 1)) | @intFromEnum(new_color);
            } else {
                self.impl_color = new_color;
            }
        }

        /// Checks if the node is the left of right child of its parent.
        ///
        /// For the root node, this function returns `null`.
        /// Note that this function assumes that the node is a part of a valid binary tree.
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

        /// A helper function to get the children of a node
        pub fn getChild(
            self: Self,
            /// Specified which child to get, i.e., the left or the right
            direction: Direction,
        ) ?*Self {
            switch (direction) {
                .left => return self.left,
                .right => return self.right,
            }
        }

        /// A helper function to set the value of a particular child of the node.
        pub fn setChild(
            self: *Self,
            /// The child to set, i.e., the left or the right child.
            direction: Direction,
            /// The new value of the child
            new_child: ?*Self,
        ) void {
            switch (direction) {
                .left => self.left = new_child,
                .right => self.right = new_child,
            }
        }

        /// Gets a pointer to the leftmost node in the subtree at the given root.
        ///
        /// Note that in a sorted tree, this node would correspond to the smallest
        /// item in the subtree.
        pub fn getLeftmostInSubtree(root: *Self) *Self {
            var current = root;
            while (current.left) |n| {
                current = n;
            }
            return current;
        }

        /// Gets a pointer to the rightmost node in the subtree at the given root.
        ///
        /// Note that in a sorted tree, this node would correspond to the largest
        /// item in the subtree.
        pub fn getRightmostInSubtree(root: *Self) *Self {
            var current = root;
            while (current.right) |n| {
                current = n;
            }
            return current;
        }

        /// Obtains the next node in an in-order traversal,
        /// or returns `null` if there is no next item.
        ///
        /// In a sorted tree, the next node is the next in the order associated to
        /// the red-black tree.
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

        /// Obtains the previous node in an in-order traversal,
        /// or returns `null` if there is no previous item.
        ///
        /// In a sorted tree, the next node is the previous in the order associated to
        /// the red-black tree.
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
