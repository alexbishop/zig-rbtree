//! This file defines red-black tree nodes.
const std = @import("std");

/// Used to represent the colour of a node in the red-black tree.
///
/// This type is backed by a `u1` as, by default, our implementation stores
/// the colour of a node as the lowest order bit of the parent pointer.
pub const NodeColor = enum(u1) {
    red = 0,
    black = 1,
    pub fn invert(node_color: NodeColor) NodeColor {
        return switch (node_color) {
            .red => .black,
            .black => .red,
        };
    }
};

/// Corresponds to the left/right subtree of a node.
///
/// This type is provided to simplify our implementation of red-black trees.
pub const Direction = enum {
    left,
    right,
    pub fn invert(direction: Direction) Direction {
        return switch (direction) {
            .left => .right,
            .right => .left,
        };
    }
};

/// Some additional options which can be applied to a node
pub const NodeOptions = struct {
    /// Indicates if each node of the tree should maintain a count of the
    /// number of elements in its associated subtree
    ///
    /// This type should either be:
    ///
    ///   1. `void`:
    ///      which indicates that the subtree sizes should not be maintained; or
    ///
    ///   2. An unsigned integer type with
    ///
    ///        - at least 8 bits; and
    ///        - at most as many bits as `usize`.
    ///
    ///     This type is then used to store the sizes of subtrees.
    ///
    /// If you need to store the subtree sizes, then we suggest to set this
    /// variable to `usize`.
    SubtreeSize: type = void,
    /// Indicates if the colour of a red-black tree node should be stored
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
    /// This feature is provided as it is usually required in order to implement
    /// augmented red-black trees. In partiuclar, such a field would be used to
    /// store the additional data of the augmented tree.
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
    /// if you do not need to store any values
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
    comptime options: NodeOptions,
) type {
    return struct {
        const Self = @This();

        // check that the options provided to the type function make sense.
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

            switch (@typeInfo(options.SubtreeSize)) {
                .void => {},
                .int => |i| {
                    if (i.signedness == .signed or i.bits < 8 or i.bits > @typeInfo(usize).int.bits) {
                        @compileError(
                            \\If options.SubtreeSize is an integer, then it must
                            \\ be an unsigned integer with at least 8 bits and at most as
                            \\ many bits as usize.
                            \\If you're unsure, then use `usize` instead
                        );
                    }
                },
                else => {
                    @compileError(
                        \\options.SubtreeSize must either be `void` or an
                        \\ unsigned integer with at least 8 bits.
                        \\If you're unsure, then use `usize` or `void` instead
                    );
                },
            }
        }

        /// A hidden tag used to indicate that this type was created using the `Node` function.
        const tag = NodeTag;
        /// The arguments which were passed to the `Node` function to create this type.
        ///
        /// These values are provided in order to enable metaprogramming.
        /// For example:
        ///
        /// ```zig
        /// fn extractUsize(node: anytype) ?usize {
        ///     if (rbtree.isNode(node)) {
        ///         if (@TypeOf(node).args.K == usize) {
        ///             return node.key;
        ///         } else {
        ///             return null;
        ///         }
        ///     } else {
        ///         return null;
        ///     }
        /// }
        /// ```
        ///
        /// The above code will extract a key of type `usize`, or will return `null` if the
        /// key of the node is not of type usize.
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

        /// If the `SubtreeSize` option is set, then this stores the size of the subtree
        /// rooted at this node.
        subtree_size: options.SubtreeSize,

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
            subtree_size: options.SubtreeSize = if (options.SubtreeSize == void) void{} else 1,
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

        /// Gets the colour of the node.
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

        /// Sets the colour of the node.
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

        /// Checks if the node is the left or right child of its parent.
        ///
        /// If this node does not have a parent, then this function returns `null`.
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
            /// Specified which child to get, i.e., the left or the right child
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
            /// The child to set, i.e., the left or the right child
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

        /// Obtains the node which would occur after this one in a postfix order
        /// (otherwise known as reverse polish order).
        ///
        /// This function is given as it is required in some other parts of the
        /// code, in particular, it is used in the implementation of the function
        /// `initFromSortedKVIterator` in the type `RBTreeUnmanaged`.
        ///
        /// For those who are unfamiliar with postfix order, it corresponds to
        /// the order in which one would print nodes of a binary tree in
        /// the following pseudocode
        ///
        /// ```zig
        /// fn printInPostfixOrder(node: *const Node) void {
        ///     // print the left subtree if we have one
        ///     if (node.left) |left| printInPostfixOrder(left);
        ///
        ///     // print the right subtree if we have one
        ///     if (node.right) |right| printInPostfixOrder(right);
        ///
        ///     // print this node
        ///     printNode(node);
        /// }
        /// ```
        ///
        /// Note that even though the above is pseudocode, you could actually
        /// get it to run in Zig if you define the function `printNode`.
        pub fn postfixNext(self: *const Self) ?*Self {
            if (self.getParent()) |parent| {
                if (parent.right == self) {
                    return parent;
                } else if (parent.right) |right| {
                    const leftmost = right.getLeftmostInSubtree();
                    if (leftmost.right) |right_of_leftmost| {
                        return right_of_leftmost;
                    } else {
                        return leftmost;
                    }
                } else {
                    return parent;
                }
            } else {
                return null;
            }
        }

        /// Obtains the node which would occur after this one in a postfix order
        /// (otherwise known as reverse polish order).
        ///
        /// This function is provided as a companion to the function `postfixNext`
        ///
        /// If the programmer is unfamiliar with postfix notation, then they should
        /// look at the documentation of `postfixNext`
        pub fn postfixPrev(self: *const Self) ?*Self {
            if (self.right) |right| {
                return right;
            } else if (self.left) |left| {
                return left;
            } else {
                var current: *const Node = self;
                while (current.getDirection()) |dir| {
                    if (dir == .right and current.getParent().?.left != null) {
                        return current.getParent().?.left.?;
                    } else {
                        current = current.getParent().?;
                    }
                }
                return null;
            }
        }

        /// Obtains the node which would occur after this one in a prefix order
        /// (otherwise known as polish order).
        ///
        /// For those who are unfamiliar with postfix order, it corresponds to
        /// the order in which one would print nodes of a binary tree in
        /// the following pseudocode
        ///
        /// ```zig
        /// fn printInPrefixOrder(node: *const Node) void {
        ///     // print this node
        ///     printNode(node);
        ///
        ///     // print the left subtree if we have one
        ///     if (node.left) |left| printInPostfixOrder(left);
        ///
        ///     // print the right subtree if we have one
        ///     if (node.right) |right| printInPostfixOrder(right);
        /// }
        /// ```
        ///
        /// Note that even though the above is pseudocode, you could actually
        /// get it to run in Zig if you define the function `printNode`.
        pub fn prefixNext(self: *const Self) ?*Self {
            if (self.left) |left| return left;
            if (self.right) |right| return right;

            var current: ?*const Node = self;
            while (current.getDirection()) |direction| {
                const parent = current.getParent().?;
                if (direction == .left and parent.right != null) {
                    return parent.right;
                }
                current = parent;
            }
            return null;
        }

        /// Obtains the node which would occur after this one in a prefix order
        /// (otherwise known as polish order).
        ///
        /// This function is provided as a companion to the function `prefixNext`
        ///
        /// If the programmer is unfamiliar with postfix notation, then they should
        /// look at the documentation of `prefixNext`
        pub fn prefixPrev(self: *const Self) ?*Self {
            if (self.getParent()) |parent| {
                const direction = self.getDirection().?;
                if (direction == .left) return parent;
                if (parent.left != null) return parent.left;
                return parent;
            } else {
                return null;
            }
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
