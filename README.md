# Zig Red-Black Trees

An extensible implementation of augmented red-black trees in the Zig programming language.

**Note:** This package is written for zig version 0.14.0.

For full documentation see https://alexbishop.github.io/zig-rbtree

**Quickstart:** For instructions on how to use this package in your code, see the [Releases page](https://github.com/alexbishop/zig-rbtree/releases).

This library is released under the MIT license (you should have a copy of the LICENSE file with this source code).

TODO before version 1.0.0:

 - [ ] add more tests including some new doctests as example usage
 - [ ] allow subtree size to be of any integer type (not just `usize`)
 - [ ] add an option to cache the first and last element of a red-black tree so that they can be retrieved in O(1) time

## New in this version

All functions of the form `*Context` in types created by `RBTreeUnmanaged` have been renamed as `*WithContext`.
This is to reduce ambiguity when calling functions like `getContext`.

Added some new functions `moveNodeByCopy` and `swapNodeStorage` to `RBTreeImplementation`.
These function enable some more advanced usage.

Updated the implementation of `initFromSortedKVIterator` in `RBTreeUnmanaged` so that it no longer uses recursion.
Moreover, this function now issues a compile error if the input iterator does not match the desired iterator interface.

Added function `isIterator` to `rbtree.meta` in order to check if a given value is an iterator.

Updates the default sort in `rbtree.meta.order` so that it now supports pointer dereferences with a comptime limit on
the number of nested pointer dereferences.
There is also a new function `rbtree.defaultOrderGeneric` which also takes in a pointer depth.

## Alternatives

If you don't like this implementation, here are some alternatives which either solve the same problem or a similar problem:

  - [Haeryu/rbtree](https://github.com/Haeryu/rbtree):
        stores a red-black tree in a array
  - [Zig compiler implementation](https://github.com/ziglang/std-lib-orphanage/blob/master/std/rb.zig):
        the now orphaned implementation which appeared in the Zig compiler
  - [pmkap/zig-btreemap](https://github.com/pmkap/zig-btreemap):
        an implementation of B-trees which is another balanced tree data structure
  - [judofyr/rgb-tree](https://github.com/judofyr/rgb-tree):
        an implementation of rgb trees with arbitrarily many colours
  - [Linux Kernel](https://github.com/torvalds/linux/blob/master/lib/rbtree.c):
        since you can use C code in Zig, you could use the red-black tree implementation in the Linux kernel
  - [C++ std::map](https://cplusplus.com/reference/map/map/):
       You could write a C wrapper around the C++ library and use it in Zig 

The above list is non-exhaustive. There are likely many other alternatives out there.

## Tests

The base implementation has some tests which are given in `tests/tests.zig`.

We note here that these tests are a translation of the tests in [stanislavkozlovski/Red-Black-Tree](https://github.com/stanislavkozlovski/Red-Black-Tree/tree/cb3cefb420bfa6c1d1fc703cefad54e209c7438c).

This translation was performed using the awk script given in `scripts/tests.gawk` in this repository, followed by a small amount of manual editing. (We note here that the tests in [stanislavkozlovski/Red-Black-Tree](https://github.com/stanislavkozlovski/Red-Black-Tree/tree/cb3cefb420bfa6c1d1fc703cefad54e209c7438c) contained a few typos which were found after the translation.)
As the name suggests this script was written to be run with [gawk](https://www.gnu.org/software/gawk/manual/gawk.html).
(At this point, there are still 6 small tests left to be translated.)

## 1. Examples

```zig
const std = @import("std");
const rbtreelib = @import("rbtree");

pub const DefaultRBTree = rbtreelib.DefaultRBTree;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const Tree = DefaultRBTree(i32, f32);

    var tree = Tree.init(allocator, void{});
    defer tree.deinit();

    // insert some stuff into the tree
    var index: i32 = -19;
    while (index < 20) : (index += 1) {
        const value = std.math.pow(
            f32,
            0.5,
            @floatFromInt(index),
        );
        try tree.put(index, value);
    }

    // print the contents of the tree
    {
        std.debug.print("First print\n", .{});
        var current: ?*Tree.Node = tree.findMin();
        while (current) |c| : (current = c.next()) {
            std.debug.print("Node {} -> {}\n", .{ c.key, c.value });
        }
    }

    // remove some entries from the tree
    _ = tree.remove(7);
    _ = tree.remove(3);
    _ = tree.remove(5);

    // print it again
    {
        std.debug.print("\nSecond print\n", .{});
        var current: ?*Tree.Node = tree.findMin();
        while (current) |c| : (current = c.next()) {
            std.debug.print("Node {} -> {}\n", .{ c.key, c.value });
        }
    }
}

```

## 2. Layers of abstraction

The red-black trees in this library come in 3 layers of abstraction as decribed in the follows subsections.

We note here that we also provide the following helper functions for accessing these abstractions.

```zig
pub fn DefaultRBTreeImplementation(comptime K: type, comptime V: type) type {
    return RBTreeImplementation(K, V, void, defaultOrder(K), .{}, .{});
}

pub fn DefaultRBTreeUnmanaged(comptime K: type, comptime V: type) type {
    return RBTreeUnmanaged(K, V, void, defaultOrder(K), .{}, .{});
}

pub fn DefaultRBTree(comptime K: type, comptime V: type) type {
    return RBTree(K, V, void, defaultOrder(K), .{}, .{});
}
```

### 2.1. Layer 1: RBTreeImplementation

You can construct an object of this type using the following function.

```zig
pub fn RBTreeImplementation(
    // the type of the key
    comptime K: type,
    // the type of the value being stored
    comptime V: type,
    // the type of the conext which can be passed to the comparison function
    // and to any augmented callbacks
    comptime Context: type,
    // the function used to compare keys in the tree
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    // some additional options,
    // see the "Augmentation and options" section of this readme
    comptime options: Options,
    // functions used to augment the functionality of the tree,
    // see the "Augmentation and options" section of this readme
    comptime augmented_callbacks: Callbacks(
        K,
        V,
        Context,
        options,
    ),
) type
```

This layer of abstraction, the supports the following functionality.

#### 2.1.1. Search

```zig
pub const Location = struct {
    parent: *Node,
    direction: Direction,
};
pub const NodeOrLocationResultTag = enum {
    node,
    location,
};
pub const FindNodeOrLocationResult = union(NodeOrLocationResultTag) {
    node: *Node,
    location: Location,
};
/// Either finds the given key in the tree, or finds the location where the
/// given key should be inserted for order to be preserved
pub fn findNodeOrLocation(
    root: *Node,
    ctx: Context,
    key: K,
) FindNodeOrLocationResult {
```

#### 2.1.2 Insert as root

```zig
/// Makes the given node the root of the tree
/// It is assumed that `root_ref.* == null` before calling this function
pub fn makeRoot(
    root_ref: *?*Node,
    ctx: Context,
    new_node: *Node,
) void {
```

#### 2.1.3 Insert as an internal node

Insert into a non-empty tree.

```zig
pub fn insertNode(
    root_ref: **Node,
    ctx: Context,
    new_node: *Node,
    location: Location,
) void {
```

Notice here that `root_ref` must be of type `**Node` and not `*?*Node`. Example of its usage is as follows.

```zig
// suppose
//      `root` is of type `?*Node`
//      `node` is of type `*Node`
//      `implementation` is of a type created by `RBTreeImplementation`
//      `location` is of type `Location`
if (root) |*root_ref| {
    // the tree node is not null
    // here `root_ref` is of type `**Node`
    implementation.insertNode(root_ref, ctx, new_node, location);
}
```

#### 2.1.4. Deleting a node

```zig
pub fn removeNode(
    root_ref_opt: *?*Node,
    ctx: Context,
    node: *Node,
) void {
```

### 2.2. Layer 2: RBTreeUnmanaged

This layer adds on some functions to make inserting and deleting from the tree easier.
Moreover, this layer also keeps track of the size of the tree.

```zig
pub fn RBTreeUnmanaged(
    // the type of the key
    comptime K: type,
    // the type of the value being stored
    comptime V: type,
    // the type of the conext which can be passed to the comparison function
    // and to any augmented callbacks
    comptime Context: type,
    // the function used to compare keys in the tree
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    // some additional options,
    // see the "Augmentation and options" section of this readme
    comptime options: Options,
    // functions used to augment the functionality of the tree,
    // see the "Augmentation and options" section of this readme
    comptime augmented_callbacks: Callbacks(
        K,
        V,
        Context,
        options,
    ),
) type {
```

### 2.3. Layer 3: RBTree

This is an abstraction on top of `RBTreeUnmanaged` which holds a copy of the allocator and context.

```zig
pub fn RBTree(
    // the type of the key
    comptime K: type,
    // the type of the value being stored
    comptime V: type,
    // the type of the conext which can be passed to the comparison function
    // and to any augmented callbacks
    comptime Context: type,
    // the function used to compare keys in the tree
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    // some additional options,
    // see the "Augmentation and options" section of this readme
    comptime options: Options,
    // functions used to augment the functionality of the tree,
    // see the "Augmentation and options" section of this readme
    comptime augmented_callbacks: Callbacks(
        K,
        V,
        Context,
        options,
    ),
) type {
```

## 3. Helper functions

Notice that all of the comparison functions used here are three parameter with the first agument beng of type `Context`.
We provide the following helper function which adds a void context to any two parameter comparison function.

```zig
pub fn addVoidContextToOrder(
    comptime K: type,
    comptime order: fn (lhs: K, rhs: K) std.math.Order,
) fn (_: void, lhs: K, rhs: K) std.math.Order {
    const tmp = struct {
        pub fn do(_: void, lhs: K, rhs: K) std.math.Order {
            return order(lhs, rhs);
        }
    };
    return tmp.do;
}
```

Moreover, if you wish for a default comparison operator, then try the following.

```zig
pub fn defaultOrder(comptime K: type) fn (_: void, lhs: K, rhs: K) std.math.Order {
    const tmp = struct {
        pub fn do(_: void, lhs: K, rhs: K) std.math.Order {
            switch (@typeInfo(K)) {
                .Int, .Float, .Pointer, .ComptimeInt, .ComptimeFloat => return std.math.order(lhs, rhs),
                .Array, .Vector => return std.mem.order(K, lhs, rhs),
                else => @compileError("Unsupported type"),
            }
        }
    };
    return tmp.do;
}
```

## 4. Augmentation and options

Notice that each of our layers of abstraction allow for options which augment the node.

```zig
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
```

Moreover, you can also specify some callbacks whihc can be run at relevant times during the update of the tree.

For an example of this see `./example/augmented_example.zig`.

```zig
pub fn Callbacks(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime options: Options,
) type {
    return struct {
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
        ///
        ///     `deep_unordered_node`
        ///         will be the node farther away from the root.
        ///         Note that this node may not be in its correct order
        ///
        ///     `shallow_node`
        ///         will be the node closer to the root.
        ///         This node is always in its correct order
        ///
        afterSwap: ?fn (
            ctx: Context,
            deep_unordered_node: *Node,
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
```

