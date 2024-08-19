//! This file contains an implementation of a managed red-black tree
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const unmanaged = @import("./rb_unmanaged.zig");

const RBTreeTag = opaque {};

pub fn isRBTree(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Struct => |_| {
            if (@hasDecl(T, "tag")) {
                switch (@typeInfo(@TypeOf(T.tag))) {
                    .Type => return (T.tag == RBTreeTag),
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
///
/// Arguments:
///  * `K`: the type used for keys in the red-black tree
///  * `V`: the type used for values in the red-black tree
///  * `Context`: the type of the context which can be passed to the comparison function of the red-black tree
///  * `order`: the comparison function to use for the red-black tree
///  * `options`: additional options which change how the red-black tree operates
///  * `augmented_callbacks`: callbacks to use for the augmented red-black tree
pub fn RBTree(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
    comptime order: fn (ctx: Context, lhs: K, rhs: K) Order,
    comptime options: unmanaged.Options,
    comptime augmented_callbacks: unmanaged.Callbacks(
        K,
        V,
        Context,
        options,
    ),
) type {
    return struct {
        const Self = @This();

        const tag = RBTreeTag;
        pub const args = .{
            .K = K,
            .V = V,
            .Context = Context,
            .order = order,
            .options = options,
            .augmented_callbacks = augmented_callbacks,
        };

        pub const ManagedType = unmanaged.RBTreeUnmanaged(
            K,
            V,
            Context,
            order,
            options,
            augmented_callbacks,
        );

        pub const ClobberOptions = ManagedType.ClobberOptions;
        pub const InsertResult = ManagedType.InsertResult;
        pub const KV = ManagedType.KV;
        pub const Node = ManagedType.Node;
        pub const NodeColor = ManagedType.NodeColor;
        pub const Direction = ManagedType.Direction;
        pub const Entry = ManagedType.Entry;
        pub const GetOrPutResult = ManagedType.GetOrPutResult;

        managed: ManagedType,
        ctx: Context,
        allocator: Allocator,

        pub fn init(
            allocator: Allocator,
            ctx: Context,
        ) Self {
            return Self{
                .managed = ManagedType.init(),
                .ctx = ctx,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.managed.deinit(self.allocator);
        }

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

        pub fn cloneWithContext(
            self: Self,
            new_ctx: Context,
        ) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.cloneWithContext(
                    self.allocator,
                    new_ctx,
                ),
                .ctx = new_ctx,
                .allocator = self.allocator,
            };
        }

        pub fn cloneWithAllocatorAndContext(
            self: Self,
            new_allocator: Allocator,
            new_ctx: Context,
        ) Allocator.Error!Self {
            return Self{
                .managed = try self.managed.cloneWithContext(
                    new_allocator,
                    new_ctx,
                ),
                .ctx = new_ctx,
                .allocator = new_allocator,
            };
        }

        pub fn removeNode(self: *Self, node: *Node) void {
            self.managed.removeNodeContext(
                self.allocator,
                node,
            );
        }

        pub fn findMin(self: Self) ?*Node {
            return self.managed.findMin();
        }

        pub fn findMax(self: Self) ?*Node {
            return self.managed.findMax();
        }

        pub fn removeNodeGetNext(
            self: *Self,
            node: *Node,
        ) ?*Node {
            return self.managed.removeNodeGetNextContext(
                self.allocator,
                self.ctx,
                node,
            );
        }

        pub fn removeNodeGetPrev(
            self: *Self,
            node: *Node,
        ) ?*Node {
            return self.managed.removeNodeGetPrevContext(
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
            return self.managed.insertContext(
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
            return self.managed.findLowerBoundContext(
                self.ctx,
                key,
            );
        }

        pub fn findUpperBound(
            self: Self,
            key: K,
        ) ?*Node {
            return self.managed.findUpperBoundContext(
                self.ctx,
                key,
            );
        }

        pub fn find(
            self: Self,
            key: K,
        ) ?*Node {
            return self.managed.findContext(
                self.ctx,
                key,
            );
        }

        pub fn getEntry(
            self: Self,
            key: K,
        ) ?Entry {
            return self.managed.getEntryContext(
                self.ctx,
                key,
            );
        }

        pub fn fetch(
            self: Self,
            key: K,
        ) ?KV {
            return self.managed.fetchContext(
                self.ctx,
                key,
            );
        }

        pub fn get(
            self: Self,
            key: K,
        ) ?V {
            return self.managed.getContext(
                self.ctx,
                key,
            );
        }

        pub fn getPtr(
            self: Self,
            key: K,
        ) ?*V {
            return self.managed.getPtrContext(
                self.ctx,
                key,
            );
        }

        pub fn getKey(
            self: Self,
            key: K,
        ) ?K {
            return self.managed.getKeyContext(
                self.ctx,
                key,
            );
        }

        pub fn getKeyPtr(
            self: Self,
            key: K,
        ) ?*K {
            return self.managed.getKeyPtrContext(
                self.ctx,
                key,
            );
        }

        pub fn contains(
            self: Self,
            key: K,
        ) bool {
            return self.managed.containsContext(
                self.ctx,
                key,
            );
        }

        pub fn getOrPutValue(
            self: *Self,
            key: K,
            value: V,
        ) GetOrPutResult {
            return self.managed.getOrPutValueContext(
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
            return self.managed.getOrPutContext(
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
            return self.managed.fetchPutContext(
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
            return self.managed.putContext(
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
            return self.managed.addContext(
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
            return self.managed.putNoClobberContext(
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
            return self.managed.fetchRemoveContext(
                self.allocator,
                self.ctx,
                key,
            );
        }

        pub fn remove(
            self: *Self,
            key: K,
        ) bool {
            return self.managed.removeContext(
                self.allocator,
                self.ctx,
                key,
            );
        }
    };
}
