//! This file contains the basic functionality of a red-black tree.
//!
//! The intention here is to allow for optimisations which would
//! not be possible with a `RBTreeUnmanaged` object.
const std = @import("std");
const Order = std.math.Order;

const rbtree = @import("./rbtree.zig");

const RBNode = @import("./rb_node.zig");

/// Options used to construct a red-black tree
pub const Options = struct {
    /// Indicates if each node of the tree should maintain a count of the
    /// number of elements in its associated subtree
    ///
    /// This type should either be:
    ///
    ///   1. `void`:
    ///      which indicates that the subtree sizes should not maintained; or
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

    /// Indicates if the implemenation should cache the first and/or last node
    /// in the tree.
    ///
    /// Note that if this is set, then `findMax` and `findMin` in `RBTreeUnmanaged`
    /// and `RBTree` will run in time `O(1)`.
    ///
    /// Note that if thie is set, the you must use the `WithCache` versions of the
    /// methods provided in `RBTreeImplementation`.
    cache_nodes: ?struct {
        /// cache the first node of the tree
        first: bool = false,
        /// cache the last node of the tree
        last: bool = false,
    } = null,

    // This type is meant to be a superset of the Options type provided in `RBNode.Node`.
    // The following compile-time checks ensure that this remains true if new
    // values are added to the Options used by `RBNode.Node`.
    comptime {
        for (@typeInfo(RBNode.NodeOptions).@"struct".fields) |field| {
            if (std.meta.fieldIndex(Options, field.name)) |field_index| {
                if (@typeInfo(Options).@"struct".fields[field_index].type != field.type) {
                    @compileError("Option field '" ++ field.name ++ "' has the wrong type");
                }
            } else {
                @compileError("Option does not have field '" ++ field.name ++ "'");
            }
        }
    }

    /// Produce an options type that can be used by the `Node` type function
    pub fn getNodeOptions(options: Options) RBNode.NodeOptions {
        var node_options: RBNode.NodeOptions = undefined;
        inline for (std.meta.fieldNames(RBNode.NodeOptions)) |field_name| {
            @field(node_options, field_name) = @field(options, field_name);
        }
        return node_options;
    }
};

/// Callbacks which can be used to implement an augmented red-black tree.
///
/// For an example of these callbacks, see `example/augmented_example.zig`
/// in the source for this library which you can find
/// [here](https://github.com/alexbishop/zig-rbtree/blob/main/example/augmented_example.zig).
pub fn Callbacks(
    /// The type of keys used in this red-black tree
    comptime K: type,
    /// The type of values used in this re-black tree
    comptime V: type,
    /// The type of the context which is passed to the sort function
    comptime Context: type,
    /// The options that were used to construct the red-black tree node
    comptime options: RBNode.NodeOptions,
) type {
    return struct {
        /// The type of a node in the red-black tree associated to the callbacks
        const Node = RBNode.Node(
            K,
            V,
            options,
        );
        /// This function will be run after every rotation of any subtree
        afterRotate: ?fn (
            ctx: Context,
            old_subtree_root: *Node,
            new_subtree_root: *Node,
            dir: RBNode.Direction,
        ) void = null,
        /// This function will be run after the positions of two
        /// nodes are swapped in the tree
        ///
        /// Note that swaps will only take place when one node
        /// is an ancestor of another. After the swap,
        afterSwap: ?fn (
            ctx: Context,
            /// The node that is farther away from the root after thw swap
            deep_unordered_node: *Node,
            /// The node that is closer to the root after the swap
            shallow_node: *Node,
        ) void = null,
        /// This function will be run after a new node has been
        /// added as a leaf of the tree. Note that the tree may not be
        /// correctly balanced at this point
        afterLink: ?fn (
            ctx: Context,
            new_node: *Node,
        ) void = null,
        /// called after the color of a node is overwritten.
        /// Node this is NOT called the affected node
        /// is already covered by a call to `afterLink`
        afterRecolor: ?fn (
            ctx: Context,
            nodes: []*Node,
        ) void = null,
        /// This function is called immediatly before a node is removed from the tree
        beforeUnlink: ?fn (
            ctx: Context,
            node: *Node,
        ) void = null,
        /// This function is called after a node is removed from the tree
        afterUnlink: ?fn (
            ctx: Context,
            node: *Node,
        ) void = null,
    };
}

/// A unique type which is used to tag types which were created using
/// the `RBTreeImplementation` function.
const RBTreeImplementationTag = opaque {};

/// Returns `true` if the given type was obtained from the function `RBTreeImplementation`.
///
/// Notice that if it is a rb-tree, then the arguments which were passed to
/// `RBTreeImplementation` can be obtained as `T.args`.
pub fn isRBTreeImplementation(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => {
            if (@hasDecl(T, "tag")) {
                switch (@typeInfo(@TypeOf(T.tag))) {
                    .type => return (T.tag == RBTreeImplementationTag),
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

/// Basic functions for the implementation of a red-black tree.
pub fn RBTreeImplementation(
    /// The type used for the keys of the red-black tree
    comptime K: type,
    /// The type used for the values of the red-black tree
    comptime V: type,
    /// The type used for the context which is passed to the order function
    comptime Context: type,
    /// The order by which to sort the keys
    ///
    /// Note that if your desired order function does not support a context,
    /// then you can fix this with the `addVoidContextToOrder` function.
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    /// Additional options used to construct the tree
    comptime options: Options,
    /// The callback functions which implement any augmentation
    comptime augmented_callbacks: Callbacks(
        K,
        V,
        Context,
        options.getNodeOptions(),
    ),
) type {
    return struct {
        /// We tag the struct so that we can later identify it as the implementation
        /// of a red-black tree
        const tag = RBTreeImplementationTag;
        /// The arguments which were passed when creating this struct
        pub const args = .{
            .K = K,
            .V = V,
            .Context = Context,
            .order = order,
            .options = options,
            .augmented_callbacks = augmented_callbacks,
        };

        /// Used to represent the colour of a node in the tree
        pub const NodeColor = RBNode.NodeColor;
        /// Used to represent left or right, in reference to the left and right subtrees
        pub const Direction = RBNode.Direction;
        /// The type of the nodes in the tree
        ///
        /// This is provided to enable metaprogramming
        pub const Node = RBNode.Node(
            K,
            V,
            options.getNodeOptions(),
        );

        /// A type used to cache the first and/or last node in the tree
        ///
        /// This type depends on the type `options.cache_nodes`
        pub const NodeCache =
            if (options.cache_nodes) |cache_nodes|
                if (cache_nodes.first or cache_nodes.last)
                    struct {
                        pub const blank: @This() = .{
                            .first = if (cache_nodes.first) null else void{},
                            .last = if (cache_nodes.last) null else void{},
                        };
                        first: if (cache_nodes.first) ?*Node else void,
                        last: if (cache_nodes.last) ?*Node else void,
                    }
                else
                    void
            else
                void;

        /// A container for a reference to the key and value of a node
        pub const Entry = struct {
            key_ptr: *K,
            value_ptr: *V,
        };
        /// A forward iterator over the entries in a red-black tree
        ///
        /// For more advanced iteration over red-black trees, we
        /// suggest that the programmer just use the `next` and
        /// `prev` functions provided by the `Node` type.
        pub const EntryIterator = struct {
            node: ?*Node,

            pub fn next(self: *EntryIterator) ?Entry {
                if (self.node) |cur| {
                    const result = Entry{
                        .key_ptr = &(cur.key),
                        .value_ptr = &(cur.value),
                    };
                    self.node = self.node.next();
                    return result;
                }
                return null;
            }

            pub fn peek(self: EntryIterator) ?Entry {
                if (self.node) |n| {
                    return Entry{
                        .key_ptr = &(n.key),
                        .value_ptr = &(n.value),
                    };
                } else {
                    return null;
                }
            }
        };

        /// A container for a copy of the key and value of a red-black tree.
        pub const KV = struct {
            key: K,
            value: V,
        };
        /// A forward iterator over the key-value pairs in a red-black tree
        ///
        /// For more advanced iteration over red-black trees, we
        /// suggest that the programmer just use the `next` and
        /// `prev` functions provided by the `Node` type.
        pub const KVIterator = struct {
            node: ?*Node,

            pub fn next(self: *KVIterator) ?KV {
                if (self.node) |cur| {
                    const result: KV = .{
                        .key = cur.key,
                        .value = cur.value,
                    };
                    self.node = self.node.next();
                    return result;
                }
                return null;
            }

            pub fn peek(self: KVIterator) ?KV {
                if (self.node) |n| {
                    return .{
                        .key = n.key,
                        .value = n.value,
                    };
                } else {
                    return null;
                }
            }
        };

        /// Used to specify the location of an empty space in the tree.
        ///
        /// That is, this type represent an empty location in the tree where a new
        /// value can be inserted.
        pub const Location = struct {
            parent: *Node,
            direction: Direction,
        };
        /// Represents either a node in the tree, or a space where a node can be
        /// inserted
        pub const FindNodeOrLocationResultTag = enum {
            node,
            location,
        };
        /// The return type of `findNodeOrLocation`
        pub const FindNodeOrLocationResult = union(FindNodeOrLocationResultTag) {
            node: *Node,
            location: Location,
        };

        /// Either finds a value in the tree or an insertion location in the tree.
        ///
        /// If the given key lies in the tree with the given root, then the corresponding node
        /// is returned, otherwise, the location where the key should be inserted is returned.
        pub fn findNodeOrLocation(
            /// The root of the tree
            ///
            /// Note that this root cannot be null as it would make no sense to call this function
            /// for an empty function. That is, there would be no possible return type for such an
            /// empty tree.
            root: *Node,
            /// The context to pass to the order function when performing comparisons
            ctx: Context,
            /// The key to search for in the tree
            key: K,
        ) FindNodeOrLocationResult {
            var node = root;

            while (true) {
                const cmp = order(ctx, key, node.key);
                switch (cmp) {
                    .eq => {
                        return FindNodeOrLocationResult{
                            .node = node,
                        };
                    },
                    .lt => {
                        // so the new node should be to the left
                        if (node.left) |l| {
                            node = l;
                        } else {
                            return FindNodeOrLocationResult{
                                .location = .{
                                    .parent = node,
                                    .direction = .left,
                                },
                            };
                        }
                    },
                    .gt => {
                        // so the new node should be to the right
                        if (node.right) |r| {
                            node = r;
                        } else {
                            return FindNodeOrLocationResult{
                                .location = .{
                                    .parent = node,
                                    .direction = .right,
                                },
                            };
                        }
                    },
                }
            }
        }

        /// Makes the given node the root of the tree.
        ///
        /// This function assumes that `root_ref.* == null` before calling.
        ///
        /// Notice that we require the context as it is passed to any callbacks.
        pub fn makeRoot(
            /// The place to store the new root.
            ///
            /// This should be `null` before calling this function
            root_ref: *?*Node,
            /// The context that would be provided to the sort function
            ///
            /// This value is required as it is passed to the `afterLink` callback function
            /// if it is provided. Thus, if you have not provided any augmentation functions
            /// for this tree, then this can be set to `undefined`.
            ctx: Context,
            new_node: *Node,
        ) void {
            if (NodeCache != void) {
                @compileError("You cannot call this function is you are caching nodes");
            }
            makeRootWithCache(undefined, root_ref, ctx, new_node);
        }

        pub fn makeRootWithCache(
            cache: *NodeCache,
            /// The place to store the new root.
            ///
            /// This should be `null` before calling this function
            root_ref: *?*Node,
            /// The context that would be provided to the sort function
            ///
            /// This value is required as it is passed to the `afterLink` callback function
            /// if it is provided. Thus, if you have not provided any augmentation functions
            /// for this tree, then this can be set to `undefined`.
            ctx: Context,
            new_node: *Node,
        ) void {
            // set all the relevant fields of the node and its parent
            new_node.setParent(null);
            new_node.setColor(.black);
            new_node.left = null;
            new_node.right = null;

            root_ref.* = new_node;

            // update any counts if we are counting in subtrees
            if (options.SubtreeSize != void) {
                new_node.subtree_size = 1;
            }

            // we need to check if we need to update the node
            if (augmented_callbacks.afterLink) |afterLink| {
                afterLink(ctx, new_node);
            }

            if (options.cache_nodes) |cache_nodes| {
                if (cache_nodes.first) cache.first = new_node;
                if (cache_nodes.last) cache.last = new_node;
            }
        }

        /// Inserts a given node into a non-empty tree and rebalances.
        ///
        /// Notice that the tree remains sorted if and only if adding `new_node`
        /// to the tree in the given location keeps the tree in sorted order.
        ///
        /// This function assumes that `location` described a `null` child of a node
        /// in the tree with the given root.
        ///
        /// Notice that `root_ref` is of type `**Node` and not `*?*Node` like in
        /// `makeRoot` or `removeNode`. Thus, in order to insert into a tree, one
        /// must perform the following.
        ///
        /// ```zig
        /// // assume that
        /// //  `root` is of type `*?*Node`
        /// //  `node` is of type `*Node`
        /// //  `Implemnetation` was created with `RBImplementation`
        /// //  `ctx` is of type `Context`
        /// //  `location` is of type `Location`
        /// // then we may insert `node` as follows
        /// if (root) |*root_ref| {
        ///     // `root_ref` is of type `**Node`
        ///     Implementation.insertNode(root_ref, ctx, node, location);
        /// }
        /// ```
        ///
        /// The intention with this design is to ensure that the programmer
        /// does not call the wrong function.
        pub fn insertNode(
            /// A reference to the root of the tree
            ///
            /// Note that the root cannot be `null`. If the root is `null`, then you should
            /// instead call the function `makeRoot`.
            root_ref: **Node,
            /// The context to pass to the order function
            ///
            /// Note that this value if only required as it is passed to the callback functions.
            /// Thus, if you are not using any augmentation, then you can set this value to
            /// be `undefined`.
            ctx: Context,
            /// The new node to insert into the red-black tree
            new_node: *Node,
            /// The location to insert the new node into the tree which maintains the
            /// sorted order of the tree.
            ///
            /// Such a location can be obtained from the function `findNodeOrLocation`
            location: Location,
        ) void {
            if (NodeCache != void) {
                @compileError("You cannot call this function is you are caching nodes");
            }
            insertNodeWithCache(undefined, root_ref, ctx, new_node, location);
        }
        pub fn insertNodeWithCache(
            cache: *NodeCache,
            /// A reference to the root of the tree
            ///
            /// Note that the root cannot be `null`. If the root is `null`, then you should
            /// instead call the function `makeRoot`.
            root_ref: **Node,
            /// The context to pass to the order function
            ///
            /// Note that this value if only required as it is passed to the callback functions.
            /// Thus, if you are not using any augmentation, then you can set this value to
            /// be `undefined`.
            ctx: Context,
            /// The new node to insert into the red-black tree
            new_node: *Node,
            /// The location to insert the new node into the tree which maintains the
            /// sorted order of the tree.
            ///
            /// Such a location can be obtained from the function `findNodeOrLocation`
            location: Location,
        ) void {
            if (options.cache_nodes) |cache_nodes| {
                if (cache_nodes.first) {
                    if (location.direction == .left and cache.first == location.parent) {
                        cache.first = new_node;
                    }
                }
                if (cache_nodes.last) {
                    if (location.direction == .right and cache.last == location.parent) {
                        cache.last = new_node;
                    }
                }
            }
            // set all the relevant fields of the node and its parent
            // the new node will start out as red
            location.parent.setChild(location.direction, new_node);
            new_node.setParent(location.parent);
            new_node.setColor(.red);
            new_node.left = null;
            new_node.right = null;

            // update any counts if we are storing subtrees counts
            if (options.SubtreeSize != void) {
                new_node.subtree_size = 1;

                var current_node = new_node.getParent();
                while (current_node) |cur| : (current_node = cur.getParent()) {
                    cur.subtree_size += 1;
                }
            }

            // we need to check if we need to update the node
            if (augmented_callbacks.afterLink) |afterLink| {
                afterLink(ctx, new_node);
            }

            var node = new_node;

            // Inserting this node may have created a new red violation
            // In fact, we might have a red violation if `node` has a parent.
            //  Thus, we fix any potential red violation in the following loop
            while (node.getParent()) |parent| {
                // We have a parent with whom we might have a red violation

                if (parent.getColor() == .black) {
                    // The parent is black, so no red violation here.
                    // We can thus exit our loop
                    return;
                }

                // At this point, we know the following:
                //
                //  1. `node`, `parent` form the only red violation
                //
                // Our next action depends on whether `parent` is the root. We
                //  check this by equivalently seeing if we have a grandparent
                //
                if (parent.getParent()) |grandparent| {
                    // At this point, we know we have a grandparent.
                    //
                    // Our next action depends entirely on the the existance
                    //  and color of our uncle which we obtain as follows.
                    //
                    const possible_uncle = grandparent.getChild(parent.getDirection().?.invert());

                    const uncle_is_red = brk: {
                        if (possible_uncle) |uncle| {
                            break :brk (uncle.getColor() == .red);
                        } else {
                            break :brk false;
                        }
                    };

                    if (uncle_is_red) {
                        // At this point, we know the following:
                        //
                        //  1. `node`, `parent` form the only red violation
                        //  2. `grandparent` exists and is black
                        //  3. `uncle` exist and is red
                        //
                        // We may then fix the red-violation as follows.
                        //
                        //         [g]                  ~g~
                        //        /   \                /   \
                        //      ~u~   ~p~     ==>    [u]   [p]
                        //               \                    \
                        //               ~n~                  ~n~
                        //
                        // Notice that after this change, we turned grandparent
                        //  red. This may introduce another red violation which
                        //  we need to check for in the next iteration.
                        //
                        parent.setColor(.black);
                        possible_uncle.?.setColor(.black);
                        grandparent.setColor(.red);
                        node = grandparent;

                        if (augmented_callbacks.afterRecolor) |afterRecolor| {
                            afterRecolor(
                                ctx,
                                .{
                                    parent,
                                    possible_uncle.?,
                                    grandparent,
                                },
                            );
                        }
                        continue;
                    } else {
                        // At this point, we know the following:
                        //
                        //  1. `node`, `parent` form the only red violation
                        //  2. `grandparent` exists and is black
                        //  3. `uncle` is either null or black
                        //
                        // We fix this issue with some rotations. Although, we
                        //  first need to be able to assume that `node` is on
                        //  the side as `parent`, i.e., `node` is a left
                        //  child if and only if `parent` is a left child.
                        // If this is not the case, we fix things with a
                        //  rotation as follows
                        //
                        //          ROTATE(parent, parent_dir)
                        //
                        //         [g]                 [g]
                        //        /   \               /   \
                        //      {u}   ~p~    ==>    {u}   ~n~
                        //           /   \               /   \
                        //         ~n~    X             Y    ~p~
                        //
                        // Notice that after such a rotation, we see that
                        //  node and parent have now swapped roles, thus, we
                        //  swap their variable names accordingly.
                        //
                        const parent_dir: Direction = parent.getDirection().?;
                        var current_parent = parent;
                        {
                            const node_dir: Direction = node.getDirection().?;
                            if (node_dir != parent_dir) {
                                _ = rotateNode(root_ref, parent, parent_dir);
                                current_parent = node;
                                node = parent;

                                if (augmented_callbacks.afterRotate) |afterRotate| {
                                    afterRotate(
                                        ctx,
                                        node,
                                        current_parent,
                                        node_dir,
                                    );
                                }
                            }
                        }
                        // Now, at this point we know the following
                        //
                        //  1. `node`, `current_parent` form the only red violation
                        //  2. `grandparent` exists and is black
                        //  3. `uncle` is either null of black
                        //  4. `node` is on the same side as `parent`
                        //    4.1. this side is given by `parent_dir`
                        //
                        // We can fix this with the following rotation and
                        //  recoloring of nodes.
                        //
                        //          ROTATE(grandparent, ~parent_dir)
                        //
                        //         [g]                    ~p~
                        //        /   \                  /   \
                        //      {u}   ~p~     ==>      [g]   ~n~
                        //           /   \            /   \
                        //          X    ~n~        {u}   X
                        //
                        //                 RECOLOR
                        //
                        //           ~p~                [p]
                        //          /   \              /   \
                        //        [g]   ~n~   ==>    ~g~   ~n~
                        //       /   \              /  \
                        //     {u}    X           {u}   X
                        //
                        // Notice that we now removed the red violation and
                        //  have not introduced any new violations. Thus,
                        //  we're done with our loop
                        //
                        _ = rotateNode(root_ref, grandparent, parent_dir.invert());
                        current_parent.setColor(.black);
                        grandparent.setColor(.red);

                        if (augmented_callbacks.afterRotate) |afterRotate| {
                            afterRotate(
                                ctx,
                                grandparent,
                                current_parent,
                                parent_dir.invert(),
                            );
                        }
                        if (augmented_callbacks.afterRecolor) |afterRecolor| {
                            afterRecolor(ctx, .{
                                current_parent,
                                grandparent,
                            });
                        }
                        return;
                    }
                } else {
                    // At this point, we know the following:
                    //
                    //  1. `node`, `parent` form the only red violation
                    //  2. `parent` is the root
                    //
                    // We can thus fix this violation by making the `parent`
                    //  black. This does not introduce any black violations
                    //  since, as mentioned, `parent` is the root.
                    //
                    // After performing this action, we're done fixing things
                    parent.setColor(.black);

                    if (augmented_callbacks.afterRecolor) |afterRecolor| {
                        afterRecolor(ctx, .{parent});
                    }
                    return;
                }
            }
        }

        /// Moves the contents of a node to a new location.
        ///
        /// **Note:** calling this function will invalidate any iterator which has a
        /// reference to the node `source`.
        ///
        /// This function is provided in order to enable a particular kind of
        /// memory management optimisation. In particular, suppose that the
        /// programmer had an arena of preallocated nodes. If the programmer
        /// then wanted to reduce the size of the arena, then they would have
        /// to ensure that at least one chunk of the arena does not have any
        /// nodes in it. This function allows the programmer to move any nodes
        /// out of such chunk so that it can be freed.
        ///
        /// Moreover, this function would also allow the programmer to move the
        /// storage of all nodes to a minimal number of pages of memory, thus
        /// providing potential performance advantages with memory cacheing.
        ///
        /// That is, this function can be used to defragment the used memory.
        pub fn moveNodeByCopy(
            root_ref: **Node,
            destination: *Node,
            source: *const Node,
        ) void {
            if (NodeCache != void) {
                @compileError("You cannot call this function is you are caching nodes");
            }
            moveNodeByCopyWithCache(undefined, root_ref, destination, source);
        }

        pub fn moveNodeByCopyWithCache(
            cache: *NodeCache,
            root_ref: **Node,
            destination: *Node,
            source: *const Node,
        ) void {
            if (source == destination) return;
            if (options.cache_nodes) |cache_nodes| {
                if (cache_nodes.first) {
                    if (cache.first == source) {
                        cache.first = destination;
                    }
                }
                if (cache_nodes.last) {
                    if (cache.last == source) {
                        cache.last = destination;
                    }
                }
            }

            if (source.getDirection()) |dir| {
                source.getParent().?.setChild(dir, destination);
            } else {
                root_ref.* = destination;
            }

            if (source.left) |left| {
                left.setParent(destination);
            }

            if (source.right) |right| {
                right.setParent(destination);
            }

            destination.* = source.*;
        }

        test moveNodeByCopyWithCache {
            var array: [12]u16 = undefined;
            for (&array, 1..) |*a, i| {
                a.* = @intCast(i * 2);
            }
            // at this point items = {2,4,6,8,...,24}
            //

            const Tree = rbtree.RBTree(u16, void, void, rbtree.defaultOrder(u16), .{
                .cache_nodes = .{
                    .first = true,
                    .last = true,
                },
            }, .{});

            var tree = try Tree.initFromSortedSlice(
                std.testing.allocator,
                undefined,
                &array,
            );
            defer tree.deinit();

            // at this point tree looks like the following
            //
            //             _____ 16 _______          <- black
            //            /                 \
            //           8 ____             22       <- both red
            //         /       \           /  \
            //        4        12         20   24    <- all black
            //      /  \      /  \       /
            //     2    6   10   14     18           <- all red
            //
            // Let's make this a bit more interesting by adding
            // the value 25 to the tree

            // let's create a new node to move into
            const new_node = try std.testing.allocator.create(Tree.Node);
            const old_node = tree.find(18).?;

            if (tree.unmanaged.root) |*root| {
                Tree.UnmanagedType.implementation.moveNodeByCopyWithCache(
                    &tree.unmanaged.cache,
                    root,
                    new_node,
                    old_node,
                );
            } else {
                try std.testing.expect(false);
            }
            defer std.testing.allocator.destroy(old_node);
            old_node.key = 0; // clear it so we can recognise if something went wrong

            // check if 18 still exists in the tree
            try std.testing.expect(tree.find(18) != null);
        }

        /// This function swaps the storage of two nodes
        ///
        /// **Note:** calling this function will invalidate any iterator which has a
        /// reference to the node `source`.
        ///
        /// Similar to the funciton `moveNodeByCopy`, this function is provided to
        /// enable potential optimisations. In particular, Suppose that the programmer is
        /// moving nodes from one tree to another (in order to avoid unecesary
        /// deallocations and allocations). For example, the programmer might want to do this
        /// if they have one tree of 'sleeping' tasks, and another tree of 'running' tasks.
        /// This function would enable the programmer to ensure that nodes of the same tree
        /// are stored alongside each other.
        pub fn swapNodeStorage(
            /// The root of the tree to which `node1` belongs
            root_ref1: **Node,
            node1: *Node,
            /// The root of the tree to which `node2` belongs
            root_ref2: **Node,
            node2: *Node,
        ) void {
            if (NodeCache != void) {
                @compileError("You cannot call this function is you are caching nodes");
            }
            swapNodeStorageWithCache(
                undefined,
                root_ref1,
                node1,
                undefined,
                root_ref2,
                node2,
            );
        }
        pub fn swapNodeStorageWithCache(
            /// The root of the tree to which `node1` belongs
            cache1: *NodeCache,
            root_ref1: **Node,
            node1: *Node,
            /// The root of the tree to which `node2` belongs
            cache2: *NodeCache,
            root_ref2: **Node,
            node2: *Node,
        ) void {
            if (node1 == node2) return;

            var tmp1: Node = undefined;
            var tmp2: Node = undefined;

            moveNodeByCopyWithCache(cache1, root_ref1, &tmp1, node1);
            moveNodeByCopyWithCache(cache2, root_ref2, &tmp2, node2);

            moveNodeByCopyWithCache(cache1, root_ref1, node2, &tmp1);
            moveNodeByCopyWithCache(cache2, root_ref2, node1, &tmp2);
        }

        /// Swaps the position of two nodes in the tree.
        ///
        /// This function only modifies the parents, children and potentially the root.
        /// This function does not copy or modify the key, value or additional data of any
        /// node in the tree.
        ///
        /// This function assumes that `node1 != node2` and that both of these nodes belong
        /// to the tree with the given root.
        ///
        /// Note: this function does not call any of the callbacks.
        pub fn swapNodePosition(
            root_ref: **Node,
            node1: *Node,
            node2: *Node,
        ) void {
            if (node1 == node2) {
                return;
            }
            // swap all their values
            const node1_dir_before = node1.getDirection();
            const node2_dir_before = node2.getDirection();
            {
                const tmp = .{
                    .parent = node1.getParent(),
                    .color = node1.getColor(),
                    .left = node1.left,
                    .right = node1.right,
                    .subtree_size = node1.subtree_size,
                };
                //
                node1.setParent(node2.getParent());
                node1.setColor(node2.getColor());
                node1.left = node2.left;
                node1.right = node2.right;
                node1.subtree_size = node2.subtree_size;
                //
                node2.setParent(tmp.parent);
                node2.setColor(tmp.color);
                node2.left = tmp.left;
                node2.right = tmp.right;
                node2.subtree_size = tmp.subtree_size;

                // Note that if `node1` and `node2` were adjacent,
                //  then one of the parent pointers will now be invalid.
                // In particular, we consider the following.
                //
                if (node1.getParent() == node1) {
                    // At the beginning of this function `node1` was the parent of `node2`
                    node1.setParent(node2);
                } else if (node2.getParent() == node2) {
                    // At the beginning of this function `node2` was the parent of `node1`
                    node2.setParent(node1);
                }
            }
            //
            //
            if (node1.left) |l| {
                l.setParent(node1);
            }
            if (node1.right) |r| {
                r.setParent(node1);
            }
            //
            if (node2_dir_before) |d| {
                node1.getParent().?.setChild(d, node1);
            } else {
                root_ref.* = node1;
            }
            //
            //
            if (node2.left) |l| {
                l.setParent(node2);
            }
            if (node2.right) |r| {
                r.setParent(node2);
            }
            //
            if (node1_dir_before) |d| {
                node2.getParent().?.setChild(d, node2);
            } else {
                root_ref.* = node2;
            }
        }

        /// Performs a tree rotation and returns the new root.
        ///
        /// **Example:**
        ///
        /// ```txt
        ///              ROTATE n LEFT
        ///
        ///          n                      r
        ///        /   \                  /   \
        ///       X     r    ==>         n     Y
        ///           /   \            /   \
        ///          s     Y          X     s
        ///
        /// In the above
        ///   n = node
        ///   r = new_subtree_root
        ///   s = swapped subtree
        /// ```
        ///
        /// Note that this function does not call any callbacks.
        pub fn rotateNode(
            root_ref: **Node,
            node: *Node,
            direction: Direction,
        ) *Node {
            //  Example:
            //
            //              ROTATE n LEFT
            //
            //          n                      r
            //        /   \                  /   \
            //       X     r    ==>         n     Y
            //           /   \            /   \
            //          s     Y          X     s
            //
            // In the above
            //   n = node
            //   r = new_subtree_root
            //   s = swapped subtree
            //
            var new_subtree_root: *Node = node.getChild(direction.invert()).?;
            const swapped_subtree: ?*Node = new_subtree_root.getChild(direction);

            // update the parent pointers for
            //   `node` and `new_subtree_root`
            // and the child pointer for the parent of `node`
            //
            {
                const previous_node_parent = node.getParent();

                if (previous_node_parent) |p| {
                    // node is not the root
                    p.setChild(node.getDirection().?, new_subtree_root);
                } else {
                    root_ref.* = new_subtree_root;
                }

                node.setParent(new_subtree_root);
                new_subtree_root.setParent(previous_node_parent);
            }

            // update the child pointers for
            //   `node` and `new_subtree_root`
            //
            node.setChild(direction.invert(), swapped_subtree);
            new_subtree_root.setChild(direction, node);

            // Update the parent pointer for the swapped subtree
            if (swapped_subtree) |swapped| {
                swapped.setParent(node);
            }

            // if we are maintaining the subtree sizes in each node,
            //   `node` and `new_subtree_root`
            //  then we need to now update the counts for
            if (options.SubtreeSize != void) {
                node.subtree_size = 1;
                if (node.left) |l| {
                    node.subtree_size += l.subtree_size;
                }
                if (node.right) |r| {
                    node.subtree_size += r.subtree_size;
                }

                new_subtree_root.subtree_size = 1;
                if (new_subtree_root.left) |l| {
                    new_subtree_root.subtree_size += l.subtree_size;
                }
                if (new_subtree_root.right) |r| {
                    new_subtree_root.subtree_size += r.subtree_size;
                }
            }

            // return the new root of this subtree
            return new_subtree_root;
        }

        /// Removes a node and rebalances the red-black tree.
        ///
        /// This function assumes that node belongs to the tree given by `root_ref_opt`.
        pub fn removeNode(
            root_ref_opt: *?*Node,
            /// The context that would be provided to the order function.
            ///
            /// Note that this value is only required as it is provided to the callback functions.
            /// Thus, for a tree without any augmentation, this value can be set to `undefined`.
            ctx: Context,
            node: *Node,
        ) void {
            if (NodeCache != void) {
                @compileError("You cannot call this function is you are caching nodes");
            }
            removeNodeWithCache(undefined, root_ref_opt, ctx, node);
        }
        pub fn removeNodeWithCache(
            cache: *NodeCache,
            root_ref_opt: *?*Node,
            /// The context that would be provided to the order function.
            ///
            /// Note that this value is only required as it is provided to the callback functions.
            /// Thus, for a tree without any augmentation, this value can be set to `undefined`.
            ctx: Context,
            node: *Node,
        ) void {
            if (options.cache_nodes) |cache_nodes| {
                if (cache_nodes.first) {
                    if (cache.first == node) {
                        cache.first = node.next();
                    }
                }
                if (cache_nodes.last) {
                    if (cache.last == node) {
                        cache.last = node.prev();
                    }
                }
            }
            // the tree must have a root if it has at least one node
            const root_ref: **Node = if (root_ref_opt.*) |*r| r else unreachable;

            // the last thing this function should do is allert the caller
            // that the node has been successfully deleted
            defer {
                if (augmented_callbacks.afterUnlink) |afterUnlink| {
                    afterUnlink(ctx, node);
                }
            }

            // We first want to make sure that the node is at the leaf
            // of the tree. We ensure this by performing a few swaps
            // as follows.
            //
            if (node.right) |r| {
                // We are not a leaf since we have a right child.
                // We fix this by swapping with our in-order successor.
                //
                // Note: although this operation breaks the binary search tree
                //  structure, this property is restored after the node is
                //  successfully removed from the tree.
                const successor = r.getLeftmostInSubtree();
                swapNodePosition(root_ref, node, successor);

                if (augmented_callbacks.afterSwap) |afterSwap| {
                    afterSwap(ctx, node, successor);
                }

                // Note that after swapping with out in-sucessor, we may
                // still have a right child, but no left child.
                //
                // Thus, our right subtree must contain only red nodes, as
                // otherwise our tree would have had a red/black violation.
                // In particular, this means that our right subtree is a leaf
                // since it
                //   * cannot have any black children as this would be a
                //      black violation
                //   * cannot have any red children as this would be a red
                //       violation
                //
                // Thus, we simply swap our node with its right child.
                if (node.right) |r2| {
                    swapNodePosition(root_ref, node, r2);

                    if (augmented_callbacks.afterSwap) |afterSwap| {
                        afterSwap(ctx, node, r2);
                    }
                }
            } else if (node.left) |l| {
                // In this case, we have only one child, on our left.
                // Thus, this child must be a red leaf, since if it
                //   * is black, then this would be a black violation
                //   * has a red child, then this would be a red violation
                //   * has a black child, then this would be a black violation
                //
                swapNodePosition(root_ref, node, l);

                if (augmented_callbacks.afterSwap) |afterSwap| {
                    afterSwap(ctx, node, l);
                }
            }

            if (augmented_callbacks.beforeUnlink) |beforeUnlink| {
                beforeUnlink(ctx, node);
            }

            // At this point, we know that the node is a leaf of our tree,
            // and that our tree has no red or black violations
            //
            // We begin with the easy cases as follows

            // If at this point, we know that the node is the root, then it
            // is the only node in the tree. We can thus remove the node by
            // simply setting the root to null as follows
            //
            if (node.getParent() == null) {
                root_ref_opt.* = null;
                return;
            }

            // If our node is red, then we can remove it without causing any
            // red or black violations
            if (node.getColor() == .red) {
                // At this point, we know that the node has a parent since it
                // is not the root, thus we need to remove the parent's reference
                // to this node as follows.
                //
                node.getParent().?.setChild(node.getDirection().?, null);

                // We also need to fix the subtree counts if we're keeping them
                //
                if (options.SubtreeSize != void) {
                    var current: ?*Node = node.getParent();
                    while (current) |c| : (current = c.getParent()) {
                        c.subtree_size -= 1;
                    }
                }
                return;
            }

            // At this point, we know that node is
            //   * a leaf of the tree
            //   * black, and
            //   * not the root,
            //
            // Thus, after removing the node as follows, we will introduce
            // a black violation which we will fix in the remainder of this
            // function.
            //

            // we need some information on the node before we begin
            const node_direction: Direction = node.getDirection().?;
            const node_parent: *Node = node.getParent().?;

            // we remove the node from the tree
            node_parent.setChild(node_direction, null);
            // If we're keeping subtree counts, then we now need to correct them
            if (options.SubtreeSize != void) {
                var current: ?*Node = node_parent;
                while (current) |c| : (current = c.getParent()) {
                    c.subtree_size -= 1;
                }
            }

            //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            // Fixing black violations
            //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            //
            // We begin by introducing some variables as follows

            var current_parent: ?*Node = node_parent;
            var current_direction: ?Direction = node_direction;

            // At this point of the function, we know that there is
            // a black violation in the tree. In particular, the
            // subtree given by `current_direction` has black depth one
            // less than the opposite subtree of `current_parent`.
            // Moreover, `current_parent` is the deepest node for which
            // we can say that we have such a property.
            //
            // At each step of this function, this property will be
            // maintained. In each step, we will either be able to
            // immediatly fix the black violaion, or we will be able
            // to move the black violation one node higher in the tree.
            // (Note, if we manage to move the black violation to the
            // root of the tree, then we can immediatly fix it. Thus,
            // this process will eventually terminate.)
            //

            // We loop for as long as we have a black violation at `current_parent`
            while (current_parent) |parent| {
                // This is the direction of the subtree which has smaller
                // black depth. In particular, this subtree has one less black
                // depth than the opposite subtree
                const direction = current_direction.?;

                // Since we know that the opposite subtree to node has one greater
                // black depth, then there must be a subtree there. In particular,
                // this means that node has a sibling as follows
                var sibling: *Node = parent.getChild(direction.invert()).?;

                // The sibling might have some children, which we obtain as follows
                // We call these children the nephews of node.
                //

                // the following is 'close' because they're on the same side as node
                var close_nephew: ?*Node = sibling.getChild(direction);
                // the following is 'distant' because they're on a different side as node
                var distant_nephew: ?*Node = sibling.getChild(direction.invert());

                // We want to reduce to the case where the sibling is NOT red
                //  we do so using the following technique
                //
                // In the following cases, we want to be able to assume that `sibling`
                // is not red. We do this by performing the following modification.
                if (sibling.getColor() == .red) {
                    // Now, at this point we know the following
                    //
                    //   1. `sibling` is red
                    //
                    // Since we have no red violations, we conclude that:
                    //
                    //   2. `parent` must be black
                    //
                    // Since we have a black violation where the `sibling`
                    //  subtree has greater black height, we then conclude
                    //  that both of our nephews must exist, and since
                    //  `sibling` is red, they must both be black, i.e.,
                    //
                    //   3. `nephew_*` are both black
                    //
                    // We can then ensure that the sibling is black
                    //  by performing a rotation and recoloring as follows
                    //
                    //          ROTATE(parent, node_dir)
                    //
                    //         [p]                    ~s~
                    //        /   \                  /   \
                    //       n    ~s~     ==>      [p]   [d]
                    //           /   \            /   \
                    //         [c]   [d]         n    [c]
                    //
                    //                 RECOLOR
                    //
                    //            ~s~              [s]
                    //           /   \            /   \
                    //         [p]   [d]  ==>   ~p~   [d]
                    //        /   \            /   \
                    //       n    [c]         n    [c]
                    //
                    // After this, we our new sibling is our closes nephew
                    // and `parent` is still the deepest point which we
                    //  see a black violation.
                    //

                    // we rotate the parent into the node's position
                    // and recolor to avoid any red violations
                    _ = rotateNode(root_ref, parent, direction);
                    parent.setColor(.red);
                    sibling.setColor(.black);

                    if (augmented_callbacks.afterRotate) |afterRotate| {
                        afterRotate(
                            ctx,
                            parent,
                            sibling,
                            direction,
                        );
                    }
                    if (augmented_callbacks.afterRecolor) |afterRecolor| {
                        afterRecolor(
                            ctx,
                            .{
                                parent,
                                sibling,
                            },
                        );
                    }

                    // at this point, there is still a black violation at `parent`
                    // where the `direction` subtree has one less height
                    // Although, after the rotation `close_nephew` is the new sibling
                    //  and we need to redefine the nephews
                    sibling = close_nephew.?;
                    close_nephew = sibling.getChild(direction);
                    distant_nephew = sibling.getChild(direction.invert());

                    // Notice that we have moved one step lower in the tree,
                    //  although, this is not a problem as we will correct this in
                    //  in following steps.
                }

                // At this point, we may assume that `sibling` is black
                //
                // Our next move will be based on which of our newphews are red
                // Notice in the following that if we have `null` nephews, then they
                //  are considered to be colored black.
                //
                const close_nephew_color: NodeColor = if (close_nephew) |c| c.getColor() else .black;
                const distant_nephew_color: NodeColor = if (distant_nephew) |d| d.getColor() else .black;

                if (close_nephew_color == .black and distant_nephew_color == .black) {
                    // Now, at this point we know the following
                    //
                    //   1. `sibling` is black
                    //   2. both `nephew`s are black
                    //   3. our `parent` and `node` can be either red or black
                    //
                    // We fix the black violation as follows
                    //
                    //                 RECOLOR
                    //
                    //             p               [p]
                    //           /   \            /   \
                    //         [s]   {n}  ==>   ~s~   {n}
                    //        /   \            /   \
                    //      [d]   [c]        [d]   [c]
                    //
                    //
                    // Notice that this procedure simply reduces the black height
                    //  of the subtree rooted at `sibling`, so that it matches the
                    //  black depth pof the subtree rooted at `node`.
                    //
                    // Moreover, notice that if the parent was red before, then we're
                    // done after this procesure. Otherwise, we have moved the violation
                    // one step higher, in particular, parent will have black height
                    // one less then its sibling.
                    //

                    // we have two cases depending on the color of the parent
                    //
                    if (parent.getColor() == .red) {
                        sibling.setColor(.red);
                        parent.setColor(.black);

                        if (augmented_callbacks.afterRecolor) |afterRecolor| {
                            afterRecolor(
                                ctx,
                                .{
                                    sibling,
                                    parent,
                                },
                            );
                        }

                        // we're done
                        return;
                    }

                    // in this case, we know that the parent was black to begin with
                    sibling.setColor(.red);
                    if (augmented_callbacks.afterRecolor) |afterRecolor| {
                        afterRecolor(ctx, .{sibling});
                    }

                    // We have now reduced the maximum black depth of `parent` by one, thus,
                    // we have now pushed the black violation one step higher in the tree
                    // We fix this in the next loop as follows
                    current_parent = parent.getParent();
                    current_direction = parent.getDirection();
                    continue;
                }

                // At this point, we know that
                //
                //  * at least one of our nephews are red
                //  * thus `sibling` is black
                //
                // We want to now be able to assume that `distant_nephew` is red
                // We ensure this is true as follows
                //
                if (distant_nephew_color == .black) {
                    // Now, at this point we know the following
                    //
                    //   1. `sibling` is black
                    //   2. `distanct_nephew` is black
                    //   3. `close_nephew` is red
                    //
                    // Note: `parent` and `node` can be either red or black
                    //
                    // We can ensure that our distanct nephew is red as follows:
                    //
                    //          ROTATE(sibling, node_dir.invert())
                    //
                    //         {p}                    {p}
                    //        /   \                  /   \
                    //       n    [s]     ==>       n   ~c~
                    //           /   \                 /   \
                    //         ~c~   [d]              X    [s]
                    //        /   \                       /   \
                    //       X     Y                     Y    [d]
                    //
                    //                 RECOLOR
                    //
                    //        {p}                     {p}
                    //       /   \                   /   \
                    //      n   ~c~        ==>      n   [c]
                    //         /   \                   /   \
                    //        X    [s]                X    ~s~
                    //            /   \                   /   \
                    //           Y    [d]                Y    [d]
                    //
                    // Thus, after this modification
                    //   * `distant_nephew` (which is our old sibling) is now red
                    //   * we still have a black violation
                    //
                    _ = rotateNode(root_ref, sibling, direction.invert());
                    sibling.setColor(.red);
                    close_nephew.?.setColor(.black);

                    if (augmented_callbacks.afterRotate) |afterRotate| {
                        afterRotate(
                            ctx,
                            sibling,
                            close_nephew.?,
                            direction.invert(),
                        );
                    }
                    if (augmented_callbacks.afterRecolor) |afterRecolor| {
                        afterRecolor(
                            ctx,
                            .{
                                sibling,
                                close_nephew.?,
                            },
                        );
                    }

                    // we need to adjust some pointers before we can now continue
                    distant_nephew = sibling;
                    sibling = close_nephew.?;
                    close_nephew = sibling.getChild(direction);
                }

                // NOTICE: After the above step, the variables `close_nephew_color`
                //  and `distant_nephew_color` can no longer be trusted. Thus, we
                //  should not use them any longer.

                // At this point, we know that
                //
                //  * `sibling` is black
                //  * `distant_nephew` is red
                //
                // Note: we don't know the color of `parent`, `node` or `close_nephew`
                //
                // Suppose `parent` is color a
                //
                // We can thus fix our black violation with a rotate and recolor:
                //
                //          ROTATE(parent, node_direction)
                //
                //                apa              [s]
                //               /   \            /   \
                //             [s]   {n}  ==>   ~d~   apa
                //            /   \                  /   \
                //          ~d~   {c}              {c}   {n}
                //
                //                      RECOLOR
                //
                //               [s]               asa
                //              /   \             /   \
                //            ~d~   apa   ==>   [d]   [p]
                //                 /  \              /   \
                //               {c}  {n}          {c}   {n}
                //
                // Notice that after this modification, we have completely
                //  removed the back violation from the tree, and we can finish
                //

                const previous_parent_color = parent.getColor();

                _ = rotateNode(root_ref, parent, direction);
                sibling.setColor(previous_parent_color);
                parent.setColor(.black);
                distant_nephew.?.setColor(.black);

                if (augmented_callbacks.afterRotate) |afterRotate| {
                    afterRotate(ctx, parent, sibling, direction);
                }
                if (augmented_callbacks.afterRecolor) |afterRecolor| {
                    if (previous_parent_color == .black) {
                        afterRecolor(ctx, .{distant_nephew});
                    } else {
                        afterRecolor(
                            ctx,
                            .{
                                parent,
                                sibling,
                                distant_nephew.?,
                            },
                        );
                    }
                }

                // and this completely fixes the coloring, no need for another loop
                return;
            }
        }
    };
}
