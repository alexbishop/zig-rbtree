//! ## Zig Red-Black Trees
//!
//! This library contains an implementation of augmented red-black tree
//! with 3 layers of abstraction.
//!
//! This is the documentation for version 1.0.0 of the library.
//! See the [repo on GitHub](https://github.com/alexbishop/zig-rbtree) for
//! the code.
//!
//! **Note:** This version of the library is written for Zig version 0.14.0.
//!
//! ### Quickstart
//!
//! For install instructions, see the
//! [GitHub release](https://github.com/alexbishop/zig-rbtree/releases/tag/v1.0.0).
//!
//! For beginners and general use, we recommend using the function `DefaultRBTree` or
//! `DefaultRBTreeUnmanaged` to construct your red-black trees.
//!
//! An example of the usage of `DefaultRBTree` is given in the
//! [GitHub release](https://github.com/alexbishop/zig-rbtree/releases/tag/v1.0.0).
//!
//! For an example of an augmented red-black tree, see `example/augmented_example.zig`
//! in the source for this library which you can find
//! [here](https://github.com/alexbishop/zig-rbtree/blob/main/example/augmented_example.zig).
//!
//! ### Features
//!
//!   1. Multiple layers of abstraction for different use cases
//!   2. Non-recursive implementation of search, insert and delete *(so we don't blow up your stack)*
//!   3. Create a red-black tree from a sorted list in `O(1)` time without the need for rotates, recolours or swaps
//!      *(note that this feature is implemented using recursion)*
//!   4. Takes order functions which take a context argumanet so you can change order behaviour at runtime
//!      *(this feature is useful if your order depends on some user input)*
//!   5. Possibility to make an augmented red-black tree with arbitrary additional data
//!      in nodes
//!   6. Optional: maintain subtree sizes
//!      *(turned off by default but easy to enable in the `Options` passed
//!      to `RBTreeImplementation`, `RBTreeUnmanaged` or `RBTree`)*
//!   7. Optional: save space by keeping the colour of the nodes in the lowest order bit of the parent pointer
//!      *(turned on by default but easy to disable in the `Options` passed
//!      to `RBTreeImplementation`, `RBTreeUnmanaged` or `RBTree`)*
//!
//! ### Structure
//!
//! The implementation is based off the description given in the
//! [Wikipedia article](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree).
//! The style of comments used in the implementation of `RBTreeImplementation`
//! is inspired by the comments in `rbtree.c` from the Linux kernel, however,
//! no code, comments, or design was copied from the Linux kernel.
//!
//! The implementation of red-black trees is broken into 3 layers:
//!
//!  1. `RBTreeImplementation`:
//!
//!     Provides a minimum implementation of the basic methods required
//!     for a red-black tree, and does not allocate any memory.
//!     Using this interface requires some boilerplate code.
//!
//!     This interface is provided to allow the programmer to have complete control
//!     over when memory is allocated/reused/deallocated and to enable optimisations that
//!     would otherwise not be possible. (For example, if you want to move nodes
//!     between two red-black trees, this interface would allow you to do so
//!     without the need to reallocate.)
//!
//!     You can still use these methods to modify trees in higher abstractions, as listed
//!     below.
//!
//!  2. `RBTreeUnmanaged`:
//!
//!     An abtraction on top of `RBTreeImplementation` which provides an implementation of
//!     the boilerplate code that you would otherwise be required to write.
//!
//!     This type also stores the size of the tree. All modifying methods ensure that this
//!     value is kept up-to-date.
//!
//!     As the name suggests, this type does not store an allocator, or context (which is
//!     passed to the order function). Thus, if you call any method that requires such data,
//!     then you must pass it in the method parameters.
//!
//!  3. `RBTree`:
//!
//!     This is a thin abstraction on top of `RBTreeUnmanaged` that stores an allocator
//!     and context for the tree. Thus, you do not have to provide the allocator and
//!     context every time you wish to perform a modification.
//!
//!     The only disadvantage of using this type over `RBTreeUnmanaged` is that it requires
//!     slightly more memory (i.e. memory to store the allocator and context).
//!
//! This implementation also allows the programmer to design augmented red-back trees.
//! For example, this would allow the programmer to write a variant of a red-black tree
//! where each node contains a copy of the largest value in its corresponding subtree.
const std = @import("std");

const managed = @import("./rb_managed.zig");
const unmanaged = @import("./rb_unmanaged.zig");
const implementation = @import("./rb_implementation.zig");
const node = @import("./rb_node.zig");

pub const meta = @import("./meta.zig");

pub const Options = unmanaged.Options;
pub const Node = node.Node;
pub const RBTree = managed.RBTree;
pub const RBTreeUnmanaged = unmanaged.RBTreeUnmanaged;
pub const RBTreeImplementation = implementation.RBTreeImplementation;
pub const Callbacks = implementation.Callbacks;

/// A red-black tree with the default order, and no augmentation.
pub fn DefaultRBTree(
    /// The type of the keys used to store items in the tree.
    /// This type must be comparable using `defaultOrder`.
    comptime K: type,
    /// The type of values stored alongside each key.
    /// This type can be `void` if you just want to store keys, that is, if
    /// you want your red-black tree to implement a set.
    comptime V: type,
) type {
    return RBTree(K, V, void, defaultOrder(K, 1), .{}, .{});
}

/// An unmanaged red-black tree with the default order, and no augmentation.
pub fn DefaultRBTreeUnmanaged(
    /// The type of the keys used to store items in the tree.
    /// This type must be comparable using `defaultOrder`.
    comptime K: type,
    /// The type of values stored alongside each key.
    /// This type can be `void` if you just want to store keys, that is, if
    /// you want your red-black tree to implement a set.
    comptime V: type,
) type {
    return RBTreeUnmanaged(K, V, void, defaultOrder(K, 1), .{}, .{});
}

/// The basic methods to implement a red-black tree with the default order
/// and no augmentation.
pub fn DefaultRBTreeImplementation(
    /// The type of the keys used to store items in the tree.
    /// This type must be comparable using `defaultOrder`.
    comptime K: type,
    /// The type of values stored alongside each key.
    /// This type can be `void` if you just want to store keys, that is, if
    /// you want your red-black tree to implement a set.
    comptime V: type,
) type {
    return RBTreeImplementation(K, V, void, defaultOrder(K, 1), .{}, .{});
}

pub const isNode = node.isNode;
pub const isRBTree = managed.isRBTree;
pub const isRBTreeUnmanaged = unmanaged.isRBTreeUnmanaged;

/// The return type of `getTreeType`.
pub const TreeTag = enum {
    /// The type provided to `getTreeType` was constructed using `RBTree`.
    managed,
    /// The type provided to `getTreeType` was constructed using `RBTreeUnmanaged`.
    unmanaged,
};
/// Checks if a given type was created with `RBTree` or `RBTreeUnmanaged`.
///
/// This function will return `null` if and only if the given type was not
/// constructed from one of the afforementioned type functions.
///
/// See also `isRBTree`, `isRBTreeUnmanaged` and `isNode`.
///
/// This function allows for generic programming.
/// For example, you could implement the following function.
///
/// ```zig
/// fn addOneToTree(comptime Tree: type, tree: *Tree) !void {
///     // check the type of tree
///     comptime {
///         // check if the given type is an RBTree
///         const type =
///             rbtree.getTreeType(Tree)
///             orelse
///               @compileError("Tree must have been constructed with RBTree.");
///
///         switch(type) {
///             .managed => {
///                 if (Tree.args.K === usize) {
///                     // we're okay
///                 } else {
///                     @compileError("The key type of the tree must be usize");
///                 }
///             },
///             .unmanaged => {
///                 @compileError("Tree must be created using RBTree not RBTreeUnmanaged");
///             },
///         }
///     }
///     // perform the actions
///     try tree.add(1);
/// }
/// ```
pub fn getTreeType(comptime Tree: type) ?TreeTag {
    if (comptime isRBTree(Tree)) return .managed;
    if (comptime isRBTreeUnmanaged(Tree)) return .unmanaged;
    return null;
}

/// Modifies a given order function such that it takes in a context.
///
/// The implementation of red-black trees used in this library
/// requires that every order function takes a context. The reasoning for this is that
/// it allows the behaviour of the order function to be modified at runtime. For example,
/// if you are writting a tool which needs to sort polynomial terms based on arbitrary
/// term orderings (which may be required in certain scientific programming situations).
///
/// It is not always the case that order functions are written with this consideration in mind.
/// In fact, it is often the case that an order function does not need a context at all.
/// This is a helper function to assist in this situation.
pub fn addVoidContextToOrder(
    /// The key type which is being compared
    comptime K: type,
    /// The function which is used to compute the relative order of two keys.
    comptime order: fn (lhs: K, rhs: K) std.math.Order,
) fn (_: void, lhs: K, rhs: K) std.math.Order {
    const tmp = struct {
        pub fn do(_: void, lhs: K, rhs: K) std.math.Order {
            return order(lhs, rhs);
        }
    };
    return tmp.do;
}

/// The default ordering of two key which can be used by the library.
pub fn defaultOrder(
    /// The type of key which is beign compared `meta.order`
    /// for more information on valid values of `K`.
    comptime K: type,
    comptime level: ?usize,
) fn (_: void, lhs: K, rhs: K) std.math.Order {
    const tmp = struct {
        pub fn do(_: void, lhs: K, rhs: K) std.math.Order {
            return meta.order(lhs, rhs, level);
        }
    };
    return tmp.do;
}
