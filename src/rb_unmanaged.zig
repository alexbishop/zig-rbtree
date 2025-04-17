//! This file contains an implementation of an unmanaged red-black tree.
//! That is, a red-black tree which does not have a copy of its allocator.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const Impl = @import("./rb_implementation.zig");

pub const Options = Impl.Options;
pub const Callbacks = Impl.Callbacks;

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
/// Arguments:
///  * `K`: the type used for keys in the red-black tree
///  * `V`: the type used for values in the red-black tree
///  * `Context`: the type of the context which can be passed to the comparison function of the red-black tree
///  * `order`: the comparison function to use for the red-black tree
///  * `options`: additional options which change how the red-black tree operates
///  * `augmented_callbacks`: callbacks to use for the augmented red-black tree
pub fn RBTreeUnmanaged(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    comptime options: Options,
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

        fn calculateLeftSubtreeSize(subtree_size: usize) usize {
            if (subtree_size <= 1) return 0;

            // notice that we need to truncate in the following
            // for example, on a 64-bit system, this would be a truncation from u7 to u6.
            // This is valid as we only ever need the extra bit when `subtree_size` is all zeros which is
            // covered by the above base cases
            const maximum_tree_size: usize = @as(usize, std.math.maxInt(usize)) >> @truncate(@clz(subtree_size));
            // for the next two numbers to make sense, we need for subtree_size to have at least 3 bits.
            // This is the case when `subtree_size > 2` which is covered in out previous cases.
            const left_subtree_max_size: usize = maximum_tree_size >> 1;
            const right_subtree_min_size: usize = maximum_tree_size >> 2;

            if (subtree_size >= left_subtree_max_size + right_subtree_min_size + 1) {
                return left_subtree_max_size;
            } else {
                return subtree_size - 1 - right_subtree_min_size;
            }
        }

        fn initSubtreeRec(
            SortedKVIterator_Ptr: type,
            allocator: Allocator,
            subtree_size: usize,
            iterator_ref: SortedKVIterator_Ptr,
            subtree_root_color: NodeColor,
        ) !?*Node {
            if (subtree_size == 0) return null;

            const next_subtree_root_color: NodeColor = switch (subtree_root_color) {
                .red => .black,
                .black => .red,
            };

            const midpoint = calculateLeftSubtreeSize(subtree_size);

            // read the left subtree

            const left_subtree: ?*Node = try initSubtreeRec(
                SortedKVIterator_Ptr,
                allocator,
                midpoint,
                iterator_ref,
                next_subtree_root_color,
            );
            errdefer deinitSubtree(allocator, left_subtree);

            // read the subtree root

            const node: *Node = try allocator.create(Node);
            errdefer allocator.destroy(node);

            const kv: KV = iterator_ref.next().?;

            node.* = Node.init(.{
                .subtree_size = if (options.store_subtree_sizes) subtree_size else void{},
                .key = kv.key,
                .value = kv.value,
                .color = subtree_root_color,
            });

            // read the right subtree

            const right_subtree: ?*Node = try initSubtreeRec(
                SortedKVIterator_Ptr,
                allocator,
                subtree_size - midpoint - 1,
                iterator_ref,
                next_subtree_root_color,
            );

            node.setChild(.left, left_subtree);
            if (left_subtree) |ls| ls.setParent(node);

            node.setChild(.right, right_subtree);
            if (right_subtree) |rs| rs.setParent(node);

            return node;
        }

        /// Constructs a red-black tree from a sorted list
        ///
        /// Arguments:
        ///  * `SortedKVIterator`
        ///      must either be the type of an iterator which returns value
        ///      of type `KV` or the type of a pointer to such an object
        ///  * `allocator`
        ///      the allocator to use when constructing the element
        ///  * `size`
        ///      the number of elements to read from `iterator`
        ///  * `iterator`
        ///      an iterator to key-value pairs which are in sorted order.
        ///
        ///  The purpose of this method is to provide a way of initialising a
        ///  red-black tree from a sorted list without the need for swaps, or
        ///  recolours.
        ///
        ///  **Note:**
        ///  unlike most other methods in this library, this initialisation
        ///  method is implemented using recursion. (As one would expect, the
        ///  total required length of the stack is proportial to the log of `size`.)
        pub fn initFromSortedKVIterator(
            SortedKVIterator: type,
            allocator: Allocator,
            size: usize,
            iterator: SortedKVIterator,
        ) !Self {
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
            const tree_depth: usize = @typeInfo(usize).int.bits - @clz(size);
            // we want to make sure that the deepest nodes are colored red,
            // we color our nodes by alternating between black and red
            // Thus if tree_depth is even, we start with black, and if
            // tree_depth is odd, we start with red.
            //
            const RefType: type = switch (@typeInfo(SortedKVIterator)) {
                .@"struct" => *SortedKVIterator,
                else => SortedKVIterator,
            };
            // we make a copy in case SortedKVIterator is not a pointer.
            // We need to make a copy so that we can modify it in this case
            var iter_cpy = iterator;

            const tree_root: ?*Node = try initSubtreeRec(
                RefType,
                allocator,
                size,
                switch (@typeInfo(SortedKVIterator)) {
                    .@"struct" => &iter_cpy,
                    else => iter_cpy,
                },
                switch (tree_depth % 2) {
                    0 => .black,
                    1 => .red,
                    else => unreachable,
                },
            );

            return .{
                .root = tree_root,
                .size = size,
            };
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
        pub fn initFromSortedKVSlice(
            allocator: Allocator,
            slice: []const KV,
        ) !Self {
            return initFromSortedKVIterator(
                KVSliceIterator,
                allocator,
                slice.len,
                KVSliceIterator{
                    .data = slice,
                },
            );
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
        pub fn initFromSortedSlice(
            allocator: Allocator,
            slice: []const K,
        ) !Self {
            return initFromSortedKVIterator(
                SliceIterator,
                allocator,
                slice.len,
                SliceIterator{
                    .data = slice,
                },
            );
        }

        pub const ClobberOptions = enum {
            no_clobber,
            clobber_value_only,
            clobber_key_and_value,
        };

        /// Describes the result of an attempted insertion
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
        pub fn insertContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
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
            clobber_option: ClobberOptions,
        ) Allocator.Error!InsertResult {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.insertContext(
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
        pub fn removeNodeContext(
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
            return self.removeNodeContext(allocator, undefined, node);
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

        /// Finds the node which corresponds to the largest value which compares less than or equal to the given key.
        pub fn findLowerBoundContext(
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

        /// A specialisation of `findLowerBoundContext` when `Context` is a zero size type.
        pub fn findLowerBound(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findLowerBound(undefined, key);
        }

        /// Finds the node which corresponds to the smalles value which compares greater than or equal to the given key.
        pub fn findUpperBoundContext(
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

        /// A specialisation of `findUpperBoundContext` when `Context` is a zero size type.
        pub fn findUpperBound(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findUpperBound(undefined, key);
        }

        /// Attempts to find a given key in the tree.
        pub fn findContext(
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

        /// A specialisation of `findContext` when `Context` is a zero size type.
        pub fn find(self: Self, key: K) ?*Node {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.findContext(undefined, key);
        }

        pub const Entry = struct {
            key_ptr: *K,
            value_ptr: *V,
        };

        pub fn getEntryContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?Entry {
            if (self.findContext(ctx, key)) |node| {
                return Entry{
                    .key_ptr = &(node.key),
                    .value_ptr = &(node.value),
                };
            } else {
                return null;
            }
        }

        pub fn getEntry(self: Self, key: K) ?Entry {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getEntryContext(undefined, key);
        }

        pub fn fetchContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?KV {
            const result = self.findContext(ctx, key) orelse return null;
            return KV{
                .key = result.key,
                .value = result.value,
            };
        }

        pub fn fetch(self: Self, key: K) ?KV {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.fetch(undefined, key);
        }

        pub fn getContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?V {
            const result = self.findContext(ctx, key) orelse return null;
            return result.value;
        }

        pub fn get(self: Self, key: K) ?V {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getContext(undefined, key);
        }

        pub fn getPtrContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*V {
            var result = self.findContext(ctx, key) orelse return null;
            return &(result.value);
        }

        pub fn getPtr(self: Self, key: K) ?*V {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getPtrContext(undefined, key);
        }

        pub fn getKeyContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?K {
            const result = self.findContext(ctx, key) orelse return null;
            return result.key;
        }

        pub fn getKey(self: Self, key: K) ?K {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getKeyContext(undefined, key);
        }

        pub fn getKeyPtrContext(
            self: Self,
            ctx: Context,
            key: K,
        ) ?*K {
            var result = self.findContext(ctx, key) orelse return null;
            return &(result.key);
        }

        pub fn getKeyPtr(self: Self, key: K) ?*K {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.getKeyPtrContext(undefined, key);
        }

        pub fn containsContext(
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

        pub fn contains(self: Self, key: K) bool {
            comptime {
                if (@sizeOf(Context) != 0) {
                    @compileError("this function is only defined when 'Context' is a zero size type");
                }
            }
            return self.containsContext(undefined, key);
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Insert functions
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        pub const GetOrPutResult = struct {
            key_ptr: *K,
            value_ptr: *V,
            found_existing: bool,
        };

        pub fn getOrPutValueContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) GetOrPutResult {
            const result: InsertResult = self.insertContext(
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
            return self.getOrPutValueContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        pub fn getOrPutContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) GetOrPutResult {
            return self.getOrPutValueContext(
                allocator,
                ctx,
                key,
                undefined,
            );
        }

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
            return self.getOrPutContext(
                allocator,
                undefined,
                key,
            );
        }

        pub fn fetchPutContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!?KV {
            const result = try self.insertContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.clobber_value_only,
            );
            return result.found_existing;
        }

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
            return self.fetchPutContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        pub fn putContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!void {
            _ = try self.insertContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.clobber_value_only,
            );
        }

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
            return self.putContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        pub fn addContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) Allocator.Error!void {
            _ = try self.insertContext(
                allocator,
                ctx,
                key,
                undefined,
                ClobberOptions.no_clobber,
            );
        }

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
            return self.addContext(
                allocator,
                undefined,
                key,
            );
        }

        pub fn putNoClobberContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
            value: V,
        ) Allocator.Error!void {
            _ = try self.insertContext(
                allocator,
                ctx,
                key,
                value,
                ClobberOptions.no_clobber,
            );
        }

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
            return self.putNoClobberContext(
                allocator,
                undefined,
                key,
                value,
            );
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // Remove functions
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

        pub fn fetchRemoveContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) ?KV {
            const node: *Node = self.findContext(ctx, key) orelse return null;
            const result = KV{
                .key = node.key,
                .value = node.value,
            };
            self.removeNodeContext(
                allocator,
                ctx,
                node,
            );
            return result;
        }

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
            return self.fetchRemoveContext(
                allocator,
                undefined,
                key,
            );
        }

        //~~~~~~~~~~~~~~~~~~~~~

        pub fn removeContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            key: K,
        ) bool {
            const node: *Node = self.findContext(ctx, key) orelse return false;
            self.removeNodeContext(
                allocator,
                ctx,
                node,
            );
            return true;
        }

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
            return self.removeContext(
                allocator,
                undefined,
                key,
            );
        }

        //~~~~~~~~~~~~~~~~~~~~~

        pub fn removeNodeGetNextContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            node: *Node,
        ) ?*Node {
            const next: ?*Node = node.next();
            self.removeNodecontext(allocator, ctx, node);
            return next;
        }

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
            return self.removeNodeGetNextContext(
                allocator,
                undefined,
                node,
            );
        }

        pub fn removeNodeGetPrevContext(
            self: *Self,
            allocator: Allocator,
            ctx: Context,
            node: *Node,
        ) ?*Node {
            const prev: ?*Node = node.prev();
            self.removeNodeContext(allocator, ctx, node);
            return prev;
        }

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
            return self.removeNodeGetPrevContext(
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

        pub fn cloneContext(
            self: Self,
            allocator: Allocator,
            ctx: Context,
        ) Allocator.Error!Self {
            var result = Self.init();
            errdefer result.deinit(allocator);

            var cur: ?*Node = self.findMin();
            while (cur) |c| : (cur = c.next()) {
                try result.putContext(
                    allocator,
                    ctx,
                    c.key,
                    c.value,
                );
            }

            return result;
        }

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
