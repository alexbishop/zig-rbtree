//! This file contains an implementation of an unmanaged red-black tree.
//! That is, a red-black tree which does not have a copy of its allocator.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const Impl = @import("./rb_implementation.zig");

pub const Options = Impl.Options;
pub const Callbacks = Impl.Callbacks;

/// A unique type which is used to tag types which were created using
/// the `RBTreeUnmanaged` function.
const RBTreeUnmanagedTag = opaque {};

/// Returns `true` if the given type was obtained from the function `RBTreeUnmanaged`.
///
/// Notice that if it is a rb-tree, then the arguments which were passed to
/// `RBTreeUnmanaged` can be ontained as `T.args`.
pub fn isRBTreeUnmanaged(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |_| {
            if (@hasDecl(T, "tag")) {
                switch (@typeInfo(@TypeOf(T.tag))) {
                    .type => return (T.tag == RBTreeUnmanagedTag),
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

/// A red-black tree which manages its root and size.
///
/// Note that the allocator and context are not managed, that is, they must be passed
/// to the relevant method calls every time.
///
/// The relevant functions provided by this abstraction are `insert`, `remove`, `clone`,
/// and `deinit`. All other modifying functions in this type call one of these.
pub fn RBTreeUnmanaged(
    /// the type used for keys in the red-black tree
    comptime K: type,
    /// The type used for values in the red-black tree
    comptime V: type,
    /// The type of the context which can be passed to the
    /// comparison function of the red-black tree
    comptime Context: type,
    /// The comparison function to use for the red-black tree
    ///
    /// Note that if your desired order function does not support a context,
    /// then you can fix this with the `addVoidContextToOrder` function.
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    /// Some additional options used to construct the tree
    comptime options: Options,
    /// Any callbacks which are used to provide any augmentation
    comptime augmented_callbacks: Callbacks(
        K,
        V,
        Context,
        options,
    ),
) type {
    return struct {
        const Self = @This();

        /// We tag the struct so that we can later identify it as an unmanaged tree.
        /// This is important for metaprogramming.
        const tag = RBTreeUnmanagedTag;
        /// The arguments which were passed when creating this struct
        pub const args = .{
            .K = K,
            .V = V,
            .Context = Context,
            .order = order,
            .options = options,
            .augmented_callbacks = augmented_callbacks,
        };

        /// Provides the basic functionality of a red-black tree
        pub const implementation = Impl.RBTreeImplementation(
            K,
            V,
            Context,
            order,
            options,
            augmented_callbacks,
        );
        pub const NodeColor = implementation.NodeColor;
        pub const Direction = implementation.Direction;
        pub const Node = implementation.Node;

        pub const KV = struct {
            key: K,
            value: V,
        };

        /// A pointer to the root of the red-black tree
        root: ?*Node,
        /// To get the size of the tree, call the function `count` instead
        size: if (options.store_subtree_sizes) void else usize,

        /// Initialises an empty red-black tree.
        pub fn init() Self {
            if (options.store_subtree_sizes) {
                return .{
                    .root = null,
                    .size = void{},
                };
            } else {
                return .{
                    .root = null,
                    .size = 0,
                };
            }
        }

        /// The error union used by `initFromSortedKVIterator`
        pub const InitFromSortedError = Allocator.Error || error{
            /// This error is returned by `initFromSortedKVIterator` if the provided
            /// iterator does not have the specified amount of entries
            ReachedEndOfIterator,
        };

        fn clearLinkedList(head_node: *Node) void {
            var current: ?*Node = head_node;
            while (current) |cur| {
                const next: ?*Node = cur.right;
                cur.right = null;
                current = next;
            }
        }

        fn invertColor(color: NodeColor) NodeColor {
            return switch (color) {
                .red => .black,
                .black => .red,
            };
        }

        fn fillSubtreeCounts(root: *Node) void {
            var current: ?*Node = root;
            while (current) |cur| {
                var total: usize = 1;

                if (cur.left) |left| {
                    if (left.subtree_size == 0) {
                        current = left;
                        continue;
                    }
                    total += left.subtree_size;
                }

                if (cur.right) |right| {
                    if (right.subtree_size == 0) {
                        current = right;
                        continue;
                    }
                    total += right.subtree_size;
                }

                cur.subtree_size = total;
                current = cur.getParent();
            }
        }

        /// Constructs a red-black tree from a sorted list
        ///
        /// The purpose of this method is to provide a way of initialising a
        /// red-black tree from a sorted list without the need for swaps, or
        /// recolours.
        ///
        /// Note that this function returns an error
        /// `InitSubtreeFromSortedError.ReachedEndOfIterator` if the provided
        /// iterator does not have the specified number of entries.
        pub fn initFromSortedKVIterator(
            /// The type of the iterator from which to ontain the sorted values
            ///
            /// This can either be the type of a `KV` iterator, or the type of a pointer
            /// to such an iterator.
            ///
            /// For example, suppose we have the following code.
            ///
            /// ```zig
            /// const KVSliceIterator = struct {
            ///     data: []const KV,
            ///     index: usize = 0,
            ///
            ///     pub fn next(self: *KVSliceIterator) ?KV {
            ///         if (self.index == self.data.len) {
            ///             return null;
            ///         } else {
            ///             const kv = self.data[self.index];
            ///             self.index += 1;
            ///             return kv;
            ///         }
            ///     }
            /// };
            /// ```
            ///
            /// Then, `KVSliceIterator` and `*KVSliceIterator` are both valid values for
            /// the parameter `SortedKVIterator`.
            SortedKVIterator: type,
            /// The allocator to use to construct nodes in the red-black tree
            allocator: Allocator,
            /// The number of items to read from the iterator.
            ///
            /// This function constructs a sorted binary tree from the first `size` items
            /// which are obtained by calling `next()` on variable `iterator` as provideed to
            /// this function
            size: usize,
            /// An iterator over values of type `KV`
            ///
            /// Note that this function assumes that the items are returned from `iterator` in
            /// sorted order, and that `iterator` contains at least `size` many items.
            ///
            /// If the end of the iterator is seen before `size` many items are read, then
            /// an error of type `InitSubtreeFromSortedError.ReachedEndOfIterator` will
            /// be returned. Note that cleanup is done before returning an error,
            /// so you don't have to worry about memory leaks.
            iterator: SortedKVIterator,
        ) InitFromSortedError!Self {
            comptime {
                switch (@typeInfo(SortedKVIterator)) {
                    .@"struct" => {},
                    .pointer => |p| {
                        switch (@typeInfo(p)) {
                            .@"struct" => {},
                            else => {
                                @compileError(
                                    \\  Invalid value for type `SortedKVIterator`
                                    \\      must either be the type of an iterator which returns value
                                    \\      of type `KV` or the type of a pointer to such an object
                                );
                            },
                        }
                    },
                    else => {
                        @compileError(
                            \\  Invalid value for type `SortedKVIterator`
                            \\      must either be the type of an iterator which returns value
                            \\      of type `KV` or the type of a pointer to such an object
                        );
                    },
                }
            }
            if (size == 0) return init();

            var current_level_color: NodeColor = brk: {
                // the depth of the tree
                const depth: usize = @typeInfo(usize).int.bits - @clz(size);
                // we want the leaves to be red, so we set the color as follows
                break :brk switch (depth % 2) {
                    0 => .black,
                    1 => .red,
                    else => unreachable,
                };
            };

            const root: *Node = try allocator.create(Node);
            root.* = Node.init(.{
                .color = current_level_color,
                .subtree_size = if (options.store_subtree_sizes) 0 else void{},
            });
            var head_of_list: *Node = root;

            errdefer {
                clearLinkedList(head_of_list);
                deinitSubtree(allocator, root);
            }

            // construct the levels of the tree one by one
            {
                var remaining_size = size - 1;

                outer: while (remaining_size > 0) {
                    current_level_color = invertColor(current_level_color);

                    var previous_list_pos: ?*Node = null;
                    var current_list_pos: ?*Node = head_of_list;

                    var is_first_of_level: bool = true;

                    while (current_list_pos) |cur| {
                        const next_list_pos = cur.right;

                        if (remaining_size == 0) {
                            break :outer;
                        }

                        if (remaining_size == 1) {
                            const new_node: *Node = try allocator.create(Node);
                            if (is_first_of_level) head_of_list = new_node;
                            new_node.* = Node.init(.{
                                .parent = cur,
                                .color = current_level_color,
                                .subtree_size = if (options.store_subtree_sizes) 0 else void{},
                            });
                            // add this node to its new position
                            if (previous_list_pos) |prev| {
                                prev.right = new_node;
                            }
                            new_node.right = next_list_pos;
                            cur.left = new_node;
                            cur.right = null;
                            break :outer;
                        }

                        // add the left node
                        {
                            const new_left_node: *Node = try allocator.create(Node);
                            if (is_first_of_level) head_of_list = new_left_node;
                            new_left_node.* = Node.init(.{
                                .parent = cur,
                                .color = current_level_color,
                                .subtree_size = if (options.store_subtree_sizes) 0 else void{},
                            });
                            if (previous_list_pos) |prev| {
                                prev.right = new_left_node;
                            }
                            new_left_node.right = next_list_pos;
                            cur.left = new_left_node;
                            cur.right = null;
                            previous_list_pos = new_left_node;
                        }

                        // add the right node
                        {
                            const new_right_node: *Node = try allocator.create(Node);
                            new_right_node.* = Node.init(.{
                                .parent = cur,
                                .color = current_level_color,
                                .subtree_size = if (options.store_subtree_sizes) 0 else void{},
                            });
                            if (previous_list_pos) |prev| {
                                prev.right = new_right_node;
                            }
                            new_right_node.right = next_list_pos;
                            cur.right = new_right_node;
                            previous_list_pos = new_right_node;
                        }

                        remaining_size -= 2;
                        is_first_of_level = false;
                        current_list_pos = next_list_pos;
                    }
                }
            }

            // remove the linked list
            clearLinkedList(head_of_list);

            // fill in the tree
            {
                // we need to take a copy of iterator as we need for it to
                // be non-const.
                var iterator_var = iterator;
                var current_tree_pos: ?*Node = head_of_list;
                while (current_tree_pos) |node| {
                    if (iterator_var.next()) |kv| {
                        node.key = kv.key;
                        node.value = kv.value;
                        current_tree_pos = node.next();
                    } else {
                        return InitFromSortedError.ReachedEndOfIterator;
                    }
                }
            }

            if (options.store_subtree_sizes) {
                fillSubtreeCounts(root);
                return .{
                    .root = root,
                    .size = void{},
                };
            } else {
                return .{
                    .root = root,
                    .size = size,
                };
            }
        }

        const KVSliceIterator = struct {
            data: []const KV,
            index: usize = 0,

            pub fn next(self: *KVSliceIterator) ?KV {
                if (self.index == self.data.len) {
                    return null;
                } else {
                    const kv = self.data[self.index];
                    self.index += 1;
                    return kv;
                }
            }
        };
        /// Initialises a red-black tree from a slice of sorted `KV` pairs.
        ///
        /// Note that the slice given as input must be sorted with respect to
        /// the relevant order.
        pub fn initFromSortedKVSlice(
            allocator: Allocator,
            slice: []const KV,
        ) Allocator.Error!Self {
            return initFromSortedKVIterator(
                KVSliceIterator,
                allocator,
                slice.len,
                KVSliceIterator{
                    .data = slice,
                },
            ) catch |err| if (err == InitFromSortedError.ReachedEndOfIterator) {
                // we should never have this type of error as out iterator was created
                // such that this cannot happen
                unreachable;
            } else {
                return @errorCast(err);
            };
        }

        const SliceIterator = struct {
            data: []const K,
            index: usize = 0,

            pub fn next(self: *SliceIterator) ?KV {
                if (self.index == self.data.len) {
                    return null;
                } else {
                    const key = self.data[self.index];
                    self.index += 1;
                    return .{
                        .key = key,
                        .value = undefined,
                    };
                }
            }
        };
        /// Initialises a red-black tree from a slice of sorted keys.
        ///
        /// Note that values associated to each node in the returned tree
        /// will be initialised from `undefined`. This function is perfect
        /// if the value type of your tree is `void`. For example, if your
        /// tree was constructed from the type
        ///
        /// ```zig
        /// const Tree = DefaultRBTreeUnmanaged(usize, void);
        /// ```
        ///
        /// Thus, this function is well-suited for the cases where your
        /// red-black tree represents a set.
        pub fn initFromSortedSlice(
            allocator: Allocator,
            slice: []const K,
        ) Allocator.Error!Self {
            return initFromSortedKVIterator(
                SliceIterator,
                allocator,
                slice.len,
                SliceIterator{
                    .data = slice,
                },
            ) catch |err| if (err == InitFromSortedError.ReachedEndOfIterator) {
                // we should never have this type of error as out iterator was created
                // such that this cannot happen
                unreachable;
            } else {
                return @errorCast(err);
            };
        }

        /// Specifies what to do when you try to insert a key that already exists in the
        /// tree.
        pub const ClobberOptions = enum {
            /// Leave the current key and value in the node alone, i.e., we don't overwrite anything
            no_clobber,
            /// Overwrite the value of the node, but leave the key unchanged
            clobber_value_only,
            /// Overwrite both the key and the value in the node
            clobber_key_and_value,
        };

        /// The return type of `insertWithContext`
        pub const InsertResult = struct {
            /// If the value already existed in the tree, then this variable
            /// will contain the key/value pair before it was clobbered
            found_existing: ?KV,
            /// Indicates if the value was clobbered
            clobbered: bool,
            /// The node corresponding to the inserted key
            node: *Node,
        };

        /// Inserts a key/value pair into the tree.
        ///
        /// This is the most general function for insertion provided by this interface,
        /// all other insersion functions are based off this function.
        pub fn insertWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
            /// Specifies what to do if the key already exists in the tree
            clobber_option: ClobberOptions,
        ) Allocator.Error!InsertResult {
            // see if our tree has a root
            if (self.root) |*root_ref| {
                const result = implementation.findNodeOrLocation(
                    self.root.?,
                    ctx,
                    key,
                );

                switch (result) {
                    .node => |node| {
                        // we have already found the node in the tree
                        // what we do here depends on our clobber settings
                        switch (clobber_option) {
                            .no_clobber => {
                                return InsertResult{
                                    .found_existing = KV{
                                        .key = node.key,
                                        .value = node.value,
                                    },
                                    .clobbered = false,
                                    .node = node,
                                };
                            },
                            .clobber_value_only => {
                                const found = KV{
                                    .key = node.key,
                                    .value = node.value,
                                };
                                // overrride the value
                                node.value = value;
                                // return
                                return InsertResult{
                                    .found_existing = found,
                                    .clobbered = true,
                                    .node = node,
                                };
                            },
                            .clobber_key_and_value => {
                                const found = KV{
                                    .key = node.key,
                                    .value = node.value,
                                };
                                // override the old values
                                node.key = key;
                                node.value = value;
                                //
                                return InsertResult{
                                    .found_existing = found,
                                    .clobbered = true,
                                    .node = node,
                                };
                            },
                        }
                    },
                    .location => |location| {
                        // we need to add the node into the given location
                        var new_node = try allocator.create(Node);
                        new_node.key = key;
                        new_node.value = value;

                        implementation.insertNode(
                            root_ref,
                            ctx,
                            new_node,
                            location,
                        );

                        if (!options.store_subtree_sizes) {
                            self.size += 1;
                        }

                        return InsertResult{
                            .found_existing = null,
                            .clobbered = false,
                            .node = new_node,
                        };
                    },
                }
            } else {
                // this is the first node which we will add
                var node = try allocator.create(Node);
                node.key = key;
                node.value = value;

                implementation.makeRoot(
                    &self.root,
                    ctx,
                    node,
                );

                if (!options.store_subtree_sizes) {
                    self.size = 1;
                }
                //
                return InsertResult{
                    .found_existing = null,
                    .clobbered = false,
                    .node = node,
                };
            }
        }

        /// Inserts a key/value pair into the tree.
        ///
        /// This function requires that `Context` is a zero size type like `void` for example.
        pub fn insert(
            self: *Self,
            allocator: Allocator,
            key: K,
            value: V,
            /// Specifies what to do if the key already exists in the tree
            clobber_option: ClobberOptions,
        ) Allocator.Error!InsertResult {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.insertWithContext(
                allocator,
                undefined,
                key,
                value,
                clobber_option,
            );
        }

        /// Removes a node from the tree.
        ///
        /// This function assumes that the node is in the red-black tree, i.e., it does not
        /// verify if this is the case before removing.
        pub fn removeNodeWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            node: *Node,
        ) void {
            implementation.removeNode(
                &self.root,
                ctx,
                node,
            );
            if (!options.store_subtree_sizes) {
                self.size -= 1;
            }
            allocator.destroy(node);
        }

        // Removes a node from the tree when `Context` is a zero size type, e.g., `void`.
        pub fn removeNode(
            self: *Self,
            allocator: Allocator,
            node: *Node,
        ) Allocator.Error!InsertResult {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.removeNodeWithContext(allocator, undefined, node);
        }

        /// Returns true if the tree does not contain any nodes.
        pub fn empty(self: Self) bool {
            return self.root != null;
        }

        /// Gets the size of the tree.
        ///
        /// Note this function should be preferred over reading the size directly.
        pub fn count(self: Self) usize {
            if (options.store_subtree_sizes) {
                if (self.root) |r| {
                    return r.subtree_size;
                } else {
                    return 0;
                }
            } else {
                return self.size;
            }
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Search functions
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        /// Returns the node corresponding to the smallest key stored in the tree.
        ///
        /// Call this function if you want an forward iterator over all the entries
        /// in the red-black tree.
        pub fn findMin(self: Self) ?*Node {
            if (self.root) |r| {
                return r.getLeftmostInSubtree();
            } else {
                return null;
            }
        }

        /// Returns the node corresponding to the largest key stored in the tree.
        pub fn findMax(self: Self) ?*Node {
            if (self.root) |r| {
                return r.getRightmostInSubtree();
            } else {
                return null;
            }
        }

        /// Finds the node which corresponds to the largest entry which compares less than or equal to the given key.
        pub fn findLowerBoundWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*Node {
            var current: ?*Node = self.root;

            while (current) |c| {
                const cmp = order(ctx, key, c.key);

                switch (cmp) {
                    Order.eq => return c,
                    Order.lt => {
                        if (c.left) |left| {
                            current = left;
                        } else {
                            return c.prev();
                        }
                    },
                    Order.gt => {
                        if (c.right) |right| {
                            current = right;
                        } else {
                            return c;
                        }
                    },
                }
            }

            return null;
        }

        /// A specialisation of `findLowerBoundWithContext` when `Context` is a zero size type.
        pub fn findLowerBound(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findLowerBound(undefined, key);
        }

        /// Finds the node which corresponds to the smallest entry which compares greater than or equal to the given key.
        pub fn findUpperBoundWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*Node {
            var current: ?*Node = self.root;

            while (current) |c| {
                const cmp = order(ctx, key, c.key);

                switch (cmp) {
                    Order.eq => return c,
                    Order.lt => {
                        if (c.left) |left| {
                            current = left;
                        } else {
                            return c;
                        }
                    },
                    Order.gt => {
                        if (c.right) |right| {
                            current = right;
                        } else {
                            return c.next();
                        }
                    },
                }
            }

            return null;
        }

        /// A specialisation of `findUpperBoundWithContext` when `Context` is a zero size type.
        pub fn findUpperBound(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findUpperBound(undefined, key);
        }

        /// Attempts to find a given key in the tree.
        ///
        /// Returns `null` if the given key was not found
        pub fn findWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*Node {
            var current: ?*Node = self.root;

            while (current) |c| {
                const cmp = order(ctx, key, c.key);

                switch (cmp) {
                    Order.eq => return c,
                    Order.lt => current = c.left,
                    Order.gt => current = c.right,
                }
            }

            return null;
        }

        /// A specialisation of `findWithContext` when `Context` is a zero size type.
        pub fn find(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findWithContext(undefined, key);
        }

        /// Similar to `KV` except stored references to the key and value
        pub const Entry = struct {
            key_ptr: *K,
            value_ptr: *V,
        };

        /// Attempts to find an entry in the tree
        ///
        /// Returns `null` if the entry could not be found
        pub fn getEntryWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?Entry {
            if (self.findWithContext(ctx, key)) |node| {
                return Entry{
                    .key_ptr = &(node.key),
                    .value_ptr = &(node.value),
                };
            } else {
                return null;
            }
        }

        /// A specialisation of `getEntryWithContext` when `Context` is a zero size type.
        pub fn getEntry(self: Self, key: K) ?Entry {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getEntryWithContext(undefined, key);
        }

        /// Gets a copy of the key-value pair associated to the given key
        pub fn fetchWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?KV {
            const result = self.findWithContext(ctx, key) orelse return null;
            return KV{
                .key = result.key,
                .value = result.value,
            };
        }

        /// A specialisation of `fetchWithContext` when `Context` is a zero size type.
        pub fn fetch(self: Self, key: K) ?KV {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.fetch(undefined, key);
        }

        /// Obtains a copy of the value associated to given key
        pub fn getWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?V {
            const result = self.findWithContext(ctx, key) orelse return null;
            return result.value;
        }

        /// A specialisation of `getWithContext` when `Context` is a zero size type.
        pub fn get(self: Self, key: K) ?V {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getWithContext(undefined, key);
        }

        /// Obtains a pointer to the value associated to the given key
        pub fn getPtrWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*V {
            var result = self.findWithContext(ctx, key) orelse return null;
            return &(result.value);
        }

        /// A specialisation of `getPtrWithContext` when `Context` is a zero size type.
        pub fn getPtr(self: Self, key: K) ?*V {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getPtrWithContext(undefined, key);
        }

        /// Obtaines a copy of the key as stored in the red-black tree
        ///
        /// This may be useful when multiple keys can compare equal.
        pub fn getKeyWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?K {
            const result = self.findWithContext(ctx, key) orelse return null;
            return result.key;
        }

        /// A specialisation of `getKeyWithContext` when `Context` is a zero size type.
        pub fn getKey(self: Self, key: K) ?K {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getKeyWithContext(undefined, key);
        }

        /// Gets a pointer to the key as stored in the red-black tree
        ///
        /// This function may be useful when multiple keys compare equal.
        pub fn getKeyPtrWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*K {
            var result = self.findWithContext(ctx, key) orelse return null;
            return &(result.key);
        }

        /// A specialisation of `getKeyPtrWithContext` when `Context` is a zero size type.
        pub fn getKeyPtr(self: Self, key: K) ?*K {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getKeyPtrWithContext(undefined, key);
        }

        /// Returns true if the red-black tree contains the given key
        pub fn containsWithContext(
            self: Self,
            ctx: Context,
            key: K,
        ) bool {
            if (self.find(ctx, key)) |_| {
                return true;
            } else {
                return false;
            }
        }

        /// A specialisation of `containsWithContext` when `Context` is a zero size type.
        pub fn contains(self: Self, key: K) bool {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.containsWithContext(undefined, key);
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Insert functions
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        pub const GetOrPutResult = struct {
            key_ptr: *K,
            value_ptr: *V,
            found_existing: bool,
        };

        /// Inserts an entry without clobbering the old entry
        ///
        /// If the key already exists in the red-black tree, then the corresponding entry is returned.
        /// Otherwise, a new entry is inserted.
        pub fn getOrPutValueWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) GetOrPutResult {
            const result: InsertResult = self.insertWithContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.no_clobber,
            );
            return GetOrPutResult{
                .key_ptr = &(result.node.key),
                .value_ptr = &(result.node.value),
                .found_existing = (result.found_existing != null),
            };
        }

        /// A specialisation of `getOrPutValueWithContext` when `Context` is a zero size type.
        pub fn getOrPutValue(
            self: *Self,
            allocator: Allocator,
            key: K,
            value: V,
        ) GetOrPutResult {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getOrPutValueWithContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        /// A specialisation of `getOrPutValueWithContext` when `Value` is a zero size type.
        ///
        /// This calls `getOrPutValueWithContext` with the `value` set to `undefined`.
        /// This function is helful for the case where the type of value if `void`.
        pub fn getOrPutWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) GetOrPutResult {
            return self.getOrPutValueWithContext(
                allocator,
                ctx,
                key,
                undefined,
            );
        }

        /// A specialisation of `getOrPutWithContext` when `Context` is a zero size type.
        pub fn getOrPut(
            self: *Self,
            allocator: Allocator,
            key: K,
        ) GetOrPutResult {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getOrPutWithContext(
                allocator,
                undefined,
                key,
            );
        }

        /// Either inserts a new entry or clobbers the key of an old entry.
        ///
        /// That is, if the key already exists, then the od value if clobbered and the entry is returned.
        /// Otherwise, a new entry is inserted into the tree.
        pub fn fetchPutWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!?KV {
            const result = try self.insertWithContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.clobber_value_only,
            );
            return result.found_existing;
        }

        /// A specialisation of `fetchPutWithContext` when `Context` is a zero size type.
        pub fn fetchPut(
            self: *Self,
            allocator: Allocator,
            key: K,
            value: V,
        ) Allocator.Error!?KV {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.fetchPutWithContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        /// Either inserts a new entry or clobbers the value, or clobbers the value of
        /// an entry with a matching key.
        pub fn putWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!void {
            _ = try self.insertWithContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.clobber_value_only,
            );
        }

        /// A specialisation of `putWithContext` when `Context` is a zero size type.
        pub fn put(
            self: *Self,
            allocator: Allocator,
            key: K,
            value: V,
        ) Allocator.Error!void {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.putWithContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        /// Either adds the given key to the red-black tree, or does nothing if
        /// the key is already present.
        pub fn addWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) Allocator.Error!void {
            _ = try self.insertWithContext(
                allocator,
                ctx,
                key,
                undefined,
                ClobberOptions.no_clobber,
            );
        }

        /// A specialisation of `addWithContext` when `Context` is a zero size type.
        pub fn add(
            self: *Self,
            allocator: Allocator,
            key: K,
        ) Allocator.Error!void {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.addWithContext(
                allocator,
                undefined,
                key,
            );
        }

        /// Either add a new entry to the red-black tree, or makes no changes if the
        /// key alreasy exists. That is, this function will not clobber any entries.
        pub fn putNoClobberWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!void {
            _ = try self.insertWithContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.no_clobber,
            );
        }

        /// A specialisation of `putNoClobberWithContext` when `Context` is a zero size type.
        pub fn putNoClobber(
            self: *Self,
            allocator: Allocator,
            key: K,
            value: V,
        ) Allocator.Error!void {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.putNoClobberWithContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Remove functions
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        /// Finds and removes an entry from the red-black tree
        ///
        /// A copy of the removed entry is returned. If `null` is returned,
        /// then the key was not found.
        pub fn fetchRemoveWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) ?KV {
            const node: *Node = self.findWithContext(ctx, key) orelse return null;
            const result = KV{
                .key = node.key,
                .value = node.value,
            };
            self.removeNodeWithContext(
                allocator,
                ctx,
                node,
            );
            return result;
        }

        /// A specialisation of `fetchRemoveWithContext` when `Context` is a zero size type.
        pub fn fetchRemove(
            self: *Self,
            allocator: Allocator,
            key: K,
        ) ?KV {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.fetchRemoveWithContext(
                allocator,
                undefined,
                key,
            );
        }

        //~~~~~~~~~~~~~~~~~~~~~

        /// Finds and removes an entry from the tree. Returns false, if and only if the given
        /// key could not be found in the tree.
        pub fn removeWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) bool {
            const node: *Node = self.findWithContext(ctx, key) orelse return false;
            self.removeNodeWithContext(
                allocator,
                ctx,
                node,
            );
            return true;
        }

        /// A specialisation of `removeWithContext` when `Context` is a zero size type.
        pub fn remove(
            self: *Self,
            allocator: Allocator,
            key: K,
        ) bool {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.removeWithContext(
                allocator,
                undefined,
                key,
            );
        }

        //~~~~~~~~~~~~~~~~~~~~~

        /// Removes the given node from the red-black tree and returns the smallest node that compares
        /// as greater than the removed node.
        pub fn removeNodeGetNextWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            node: *Node,
        ) ?*Node {
            const next: ?*Node = node.next();
            self.removeNodecontext(allocator, ctx, node);
            return next;
        }

        /// A specialisation of `removeNodeGetNextWithContext` when `Context` is a zero size type.
        pub fn removeNodeGetNext(
            self: *Self,
            allocator: Allocator,
            node: *Node,
        ) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.removeNodeGetNextWithContext(
                allocator,
                undefined,
                node,
            );
        }

        /// Removes the given node from the red-black tree and returns the largest node that compares
        /// as less than the removed node.
        pub fn removeNodeGetPrevWithContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            node: *Node,
        ) ?*Node {
            const prev: ?*Node = node.prev();
            self.removeNodeWithContext(allocator, ctx, node);
            return prev;
        }

        /// A specialisation of `removeNodeGetPrevWithContext` when `Context` is a zero size type.
        pub fn removeNodeGetPrev(
            self: *Self,
            allocator: Allocator,
            node: *Node,
        ) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.removeNodeGetPrevWithContext(
                allocator,
                undefined,
                node,
            );
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Move and copy
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        pub fn move(self: *Self) Self {
            const result: Self = self.*;
            self.* = Self.init();
            return result;
        }

        fn deinitSubtree(allocator: Allocator, subtree_root: ?*Node) void {
            // this removes all nodes in in-order succession
            var current_node = subtree_root;
            while (current_node) |node| {
                // check if this node has any subtrees which we should remove
                if (node.left) |left| {
                    current_node = left.getLeftmostInSubtree();
                } else if (node.right) |right| {
                    current_node = right.getLeftmostInSubtree();
                } else {
                    // this node has no children, we can remove it
                    if (node.getParent()) |parent| {
                        parent.setChild(node.getDirection().?, null);
                    }

                    // we will delete the parent next
                    current_node = node.getParent();
                    // delete this node
                    allocator.destroy(node);
                }
            }
        }

        pub fn deinit(self: *Self, allocator: Allocator) void {
            deinitSubtree(allocator, self.root);
            self.* = Self.init();
        }

        /// Clones the tree with a given Context.
        ///
        /// If the context if the same as the context used to create this red-black tree,
        /// then you should instead use the function `clone`
        pub fn cloneWithNewContext(
            self: Self,
            allocator: Allocator,
            ctx: Context,
        ) Allocator.Error!Self {
            var result = Self.init();
            errdefer result.deinit(allocator);

            var cur: ?*Node = self.findMin();
            while (cur) |c| : (cur = c.next()) {
                try result.putWithContext(
                    allocator,
                    ctx,
                    c.key,
                    c.value,
                );
            }

            return result;
        }

        /// Clones the red-black tree such that the new tree has exactly the same
        /// layout. No context is needed for this operation.
        pub fn clone(self: Self, allocator: Allocator) Allocator.Error!Self {
            var result = Self.init();
            errdefer result.deinit(allocator);

            // this is the current node being copied
            var node: *Node = self.root orelse return result;

            // this is the copy of the node
            var copy: *Node = try allocator.create(Node);
            copy.setColor(node.getColor());
            copy.setParent(null);
            copy.left = null;
            copy.right = null;
            copy.key = node.key;
            copy.value = node.value;
            if (options.store_subtree_sizes) {
                copy.subtree_size = node.subtree_size;
            }
            if (options.AdditionalNodeData) |_| {
                copy.additional_data = node.additional_data;
            }

            // start by setting the root
            result.root = copy;
            if (!options.store_subtree_sizes) {
                result.size = self.size;
            }

            // in the following, we copy the tree in preorder
            // that is, in the order, node, left, right
            outer: while (true) {
                // at this point, we assume that we have copied
                //  `node` and that the new copy is stored in
                //  the variable named `copy`

                if (node.left) |l| {
                    // we have a left subtree we should copy
                    //
                    var left_copy: *Node = try allocator.create(Node);
                    left_copy.setColor(l.getColor());
                    left_copy.setParent(copy);
                    left_copy.left = null;
                    left_copy.right = null;
                    left_copy.key = l.key;
                    left_copy.value = l.value;
                    if (options.store_subtree_sizes) {
                        left_copy.subtree_size = l.subtree_size;
                    }
                    if (options.AdditionalNodeData) |_| {
                        left_copy.additional_data = l.additional_data;
                    }

                    // add the node to the tree
                    copy.left = left_copy;

                    // move onto copying this subtree
                    node = l;
                    copy = left_copy;
                } else if (node.right) |r| {
                    // we have a left subtree we should copy
                    //
                    var right_copy: *Node = try allocator.create(Node);
                    right_copy.setColor(r.getColor());
                    right_copy.setParent(copy);
                    right_copy.left = null;
                    right_copy.right = null;
                    right_copy.key = r.key;
                    right_copy.value = r.value;
                    if (options.store_subtree_sizes) {
                        right_copy.subtree_size = r.subtree_size;
                    }
                    if (options.AdditionalNodeData) |_| {
                        right_copy.additional_data = r.additional_data;
                    }

                    copy.right = right_copy;

                    // move onto copying this subtree
                    node = r;
                    copy = right_copy;
                } else if (node.getParent()) |parent| {
                    // we have no more nodes to copy in this subtree, thus
                    // we must move on to the next one in preorder

                    // the following direction is defined since we have
                    // a parent
                    var direction: Direction = node.getDirection().?;

                    // the following is defines since copy has a parent
                    // if and only if node has a parent
                    node = parent;
                    copy = copy.getParent().?;

                    while (direction == .right or node.right == null) {
                        // we need to iterate until we find the next thing in preoorder.
                        //
                        // if this while loop does not hold, then we are still
                        // looking for our next in preorder, which will be a
                        // child of one of our ancestors, thus we need to have
                        // a parent for such a successor to exist.
                        if (node.getDirection()) |new_direction| {
                            // we have a parent, let's look there
                            direction = new_direction;
                            node = node.getParent().?;
                            copy = copy.getParent().?;
                        } else {
                            // we have no parent, thus we must have no successor
                            break :outer;
                        }
                    }

                    // at this point the succssor is our right child

                    const r = node.right.?;

                    var right_copy: *Node = try allocator.create(Node);
                    right_copy.setColor(r.getColor());
                    right_copy.setParent(copy);
                    right_copy.left = null;
                    right_copy.right = null;
                    right_copy.key = r.key;
                    right_copy.value = r.value;
                    if (options.store_subtree_sizes) {
                        right_copy.subtree_size = r.subtree_size;
                    }
                    if (options.AdditionalNodeData) |_| {
                        right_copy.additional_data = r.additional_data;
                    }

                    copy.right = right_copy;

                    // move onto copying this subtree
                    node = r;
                    copy = right_copy;
                } else {
                    // we have completly finished
                    break;
                }
            }

            return result;
        }
    };
}
