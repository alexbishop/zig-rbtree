//! This file contains an implementation of a managed red-black tree
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const unmanaged = @import("./rb_unmanaged.zig");

/// A unique type which is used to tag types which were created using
/// the `RBTree` function.
const RBTreeTag = opaque {};

/// Returns `true` if the given type was obtained from the function `RBTree`.
///
/// Notice that if it is a red-black tree, then the arguments which were passed to
/// `RBTree` can be ontained as `T.args`.
pub fn isRBTree(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |_| {
            if (@hasDecl(T, "tag")) {
                switch (@typeInfo(@TypeOf(T.tag))) {
                    .type => return (T.tag == RBTreeTag),
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

/// A red-black tree which manages its own allocator and context.
pub fn RBTree(
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
    comptime options: unmanaged.Options,
    /// Any callbacks which are used to provide any augmentation
    comptime augmented_callbacks: unmanaged.Callbacks(
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
        const tag = RBTreeTag;
        /// The arguments which were passed when creating this struct
        pub const args = .{
            .K = K,
            .V = V,
            .Context = Context,
            .order = order,
            .options = options,
            .augmented_callbacks = augmented_callbacks,
        };

        /// The Unamanged type that we are wrapping
        pub const UnmanagedType = unmanaged.RBTreeUnmanaged(
            K,
            V,
            Context,
            order,
            options,
            augmented_callbacks,
        );

        pub const ClobberOptions = UnmanagedType.ClobberOptions;
        pub const InsertResult = UnmanagedType.InsertResult;
        pub const KV = UnmanagedType.KV;
        pub const Node = UnmanagedType.Node;
        pub const NodeColor = UnmanagedType.NodeColor;
        pub const Direction = UnmanagedType.Direction;
        pub const Entry = UnmanagedType.Entry;
        pub const GetOrPutResult = UnmanagedType.GetOrPutResult;

        /// An instance of an unmanaged red-black tree which we are
        /// now managing in this type
        managed: UnmanagedType,
        /// The context that will be passed to the `order` function
        ctx: Context,
        /// The allocator that is used to create and distory nodes
        allocator: Allocator,

        /// initialises an empty red-black tree
        pub fn init(
            allocator: Allocator,
            ctx: Context,
        ) Self {
            return Self{
                .managed = UnmanagedType.init(),
                .ctx = ctx,
                .allocator = allocator,
            };
        }

        /// The error union used for `initFromSortedKVIterator`
        pub const InitFromSortedError = UnmanagedType.InitFromSortedError;

        /// Constructs a red-black tree from a sorted list
        ///
        /// The purpose of this method is to provide a way of initialising a
        /// red-black tree from a sorted list without the need for swaps, or
        /// recolours.
        ///
        /// Note that this function returns an error
        /// `InitSubtreeFromSortedError.ReachedEndOfIterator` if the provided
        /// iterator does not have the specified number of entries.
        ///
        /// **Note:**
        /// unlike most other methods in this library, this initialisation
        /// method is implemented using recursion. (As one would expect, the
        /// total required length of the stack is proportial to the log of `size`.)
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
            /// The context to pass to the `order` function in subsequent modifications
            ctx: Context,
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
            return Self{
                .managed = try UnmanagedType.initFromSortedKVIterator(
                    SortedKVIterator,
                    allocator,
                    size,
                    iterator,
                ),
                .ctx = ctx,
                .allocator = allocator,
            };
        }

        /// Initialises a red-black tree from a slice of sorted `KV` pairs.
        ///
        /// Note that the slice given as input must be sorted with respect to
        /// the relevant order.
        pub fn initFromSortedKVSlice(
            allocator: Allocator,
            ctx: Context,
            slice: []const KV,
        ) Allocator.Error!Self {
            return Self{
                .managed = try UnmanagedType.initFromSortedKVSlice(
                    allocator,
                    slice,
                ),
                .ctx = ctx,
                .allocator = allocator,
            };
        }

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
            ctx: Context,
            slice: []const K,
        ) Allocator.Error!Self {
            return Self{
                .managed = try UnmanagedType.initFromSortedSlice(
                    allocator,
                    slice,
                ),
                .ctx = ctx,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.managed.deinit(self.allocator);
        }

        /// Gets the size of the red-black tree, that is, the number
        /// of entries in the tree.
        pub fn count(self: Self) usize {
            return self.managed.count();
        }

        pub fn move(self: *Self) Self {
            return Self{
                .managed = self.managed.move(),
                .ctx = self.ctx,
                .allocator = self.allocator,
            };
        }

        pub fn clone(self: Self) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.clone(self.allocator),
                .ctx = self.ctx,
                .allocator = self.allocator,
            };
        }

        /// Clones the red-black tree using the same allocator and Context
        pub fn cloneWithAllocator(
            self: Self,
            new_allocator: Allocator,
        ) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.clone(new_allocator),
                .ctx = self.ctx,
                .allocator = new_allocator,
            };
        }

        /// Clones the red-black tree using the given context.
        pub fn cloneWithContext(
            self: Self,
            new_ctx: Context,
        ) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.cloneWithNewContext(
                    self.allocator,
                    new_ctx,
                ),
                .ctx = new_ctx,
                .allocator = self.allocator,
            };
        }

        /// Clons the red-black tree with the given context and allocator.
        pub fn cloneWithAllocatorAndContext(
            self: Self,
            new_allocator: Allocator,
            new_ctx: Context,
        ) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.cloneWithNewContext(
                    new_allocator,
                    new_ctx,
                ),
                .ctx = new_ctx,
                .allocator = new_allocator,
            };
        }

        /// Removes a node from the tree.
        ///
        /// This function assumes that the given node belongs to the tree
        pub fn removeNode(self: *Self, node: *Node) void {
            self.managed.removeNodeWithContext(
                self.allocator,
                node,
            );
        }

        /// Returns the smallest entry in the tree
        ///
        /// This function can also be seen the ocnstructor for a forward iterator
        /// over the tree.
        pub fn findMin(self: Self) ?*Node {
            return self.managed.findMin();
        }

        /// Returns the largest entry in the list
        pub fn findMax(self: Self) ?*Node {
            return self.managed.findMax();
        }

        pub fn removeNodeGetNext(
            self: *Self,
            node: *Node,
        ) ?*Node {
            return self.managed.removeNodeGetNextWithContext(
                self.allocator,
                self.ctx,
                node,
            );
        }

        pub fn removeNodeGetPrev(
            self: *Self,
            node: *Node,
        ) ?*Node {
            return self.managed.removeNodeGetPrevWithContext(
                self.allocator,
                self.ctx,
                node,
            );
        }

        // the following functions were automatically generated

        pub fn insert(
            self: *Self,
            key: K,
            value: V,
            clobber_option: ClobberOptions,
        ) Allocator.Error!InsertResult {
            return self.managed.insertWithContext(
                self.allocator,
                self.ctx,
                key,
                value,
                clobber_option,
            );
        }

        pub fn findLowerBound(
            self: Self,
            key: K,
        ) ?*Node {
            return self.managed.findLowerBoundWithContext(
                self.ctx,
                key,
            );
        }

        pub fn findUpperBound(
            self: Self,
            key: K,
        ) ?*Node {
            return self.managed.findUpperBoundWithContext(
                self.ctx,
                key,
            );
        }

        pub fn find(
            self: Self,
            key: K,
        ) ?*Node {
            return self.managed.findWithContext(
                self.ctx,
                key,
            );
        }

        pub fn getEntry(
            self: Self,
            key: K,
        ) ?Entry {
            return self.managed.getEntryWithContext(
                self.ctx,
                key,
            );
        }

        pub fn fetch(
            self: Self,
            key: K,
        ) ?KV {
            return self.managed.fetchWithContext(
                self.ctx,
                key,
            );
        }

        pub fn get(
            self: Self,
            key: K,
        ) ?V {
            return self.managed.getWithContext(
                self.ctx,
                key,
            );
        }

        pub fn getPtr(
            self: Self,
            key: K,
        ) ?*V {
            return self.managed.getPtrWithContext(
                self.ctx,
                key,
            );
        }

        pub fn getKey(
            self: Self,
            key: K,
        ) ?K {
            return self.managed.getKeyWithContext(
                self.ctx,
                key,
            );
        }

        pub fn getKeyPtr(
            self: Self,
            key: K,
        ) ?*K {
            return self.managed.getKeyPtrWithContext(
                self.ctx,
                key,
            );
        }

        pub fn contains(
            self: Self,
            key: K,
        ) bool {
            return self.managed.containsWithContext(
                self.ctx,
                key,
            );
        }

        pub fn getOrPutValue(
            self: *Self,
            key: K,
            value: V,
        ) GetOrPutResult {
            return self.managed.getOrPutValueWithContext(
                self.allocator,
                self.ctx,
                key,
                value,
            );
        }

        pub fn getOrPut(
            self: *Self,
            key: K,
        ) GetOrPutResult {
            return self.managed.getOrPutWithContext(
                self.allocator,
                self.ctx,
                key,
            );
        }

        pub fn fetchPut(
            self: *Self,
            key: K,
            value: V,
        ) Allocator.Error!?KV {
            return self.managed.fetchPutWithContext(
                self.allocator,
                self.ctx,
                key,
                value,
            );
        }

        pub fn put(
            self: *Self,
            key: K,
            value: V,
        ) Allocator.Error!void {
            return self.managed.putWithContext(
                self.allocator,
                self.ctx,
                key,
                value,
            );
        }

        pub fn add(
            self: *Self,
            key: K,
        ) Allocator.Error!void {
            return self.managed.addWithContext(
                self.allocator,
                self.ctx,
                key,
            );
        }

        pub fn putNoClobber(
            self: *Self,
            key: K,
            value: V,
        ) Allocator.Error!void {
            return self.managed.putNoClobberWithContext(
                self.allocator,
                self.ctx,
                key,
                value,
            );
        }

        pub fn fetchRemove(
            self: *Self,
            key: K,
        ) ?KV {
            return self.managed.fetchRemoveWithContext(
                self.allocator,
                self.ctx,
                key,
            );
        }

        pub fn remove(
            self: *Self,
            key: K,
        ) bool {
            return self.managed.removeWithContext(
                self.allocator,
                self.ctx,
                key,
            );
        }
    };
}
