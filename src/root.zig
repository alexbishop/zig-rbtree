//! This is the documentation for [zig rbtree](https://github.com/alexbishop/zig-rbtree) version 0.0.2.
//!
//! For the documentation of any other version, please checkout the corresponding
//! version of the code from the [Github repo](https://github.com/alexbishop/zig-rbtree) and run the following
//!
//! ```
//! rm -rf ~/.cache/zig
//! zig build docs
//! ```
//!
//! Notice that we remove the global zig cache since it interferes with the generation of the documentation.
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

pub fn DefaultRBTree(comptime K: type, comptime V: type) type {
    return RBTree(K, V, void, defaultOrder(K), .{}, .{});
}

pub fn DefaultRBTreeUnmanaged(comptime K: type, comptime V: type) type {
    return RBTreeUnmanaged(K, V, void, defaultOrder(K), .{}, .{});
}

pub fn DefaultRBTreeImplementation(comptime K: type, comptime V: type) type {
    return RBTreeImplementation(K, V, void, defaultOrder(K), .{}, .{});
}

pub const isNode = node.isNode;
pub const isRBTree = managed.isRBTree;
pub const isRBTreeUnmanaged = unmanaged.isRBTreeUnmanaged;

pub const TreeTag = enum {
    managed,
    unmanaged,
};
pub fn getTreeType(comptime Tree: type) ?TreeTag {
    if (comptime isRBTree(Tree)) return .managed;
    if (comptime isRBTreeUnmanaged(Tree)) return .unmanaged;
    return null;
}

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

pub fn defaultOrder(comptime K: type) fn (_: void, lhs: K, rhs: K) std.math.Order {
    const tmp = struct {
        pub fn do(_: void, lhs: K, rhs: K) std.math.Order {
            return meta.order(lhs, rhs);
        }
    };
    return tmp.do;
}
