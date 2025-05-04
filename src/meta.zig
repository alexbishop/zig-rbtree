//! Provides a default comparison function
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const rbtree = @import("./rbtree.zig");

/// Checks if a `Ptr` is a pointer to `Item`.
/// Note that the pointer is allowed to have the `const`, `volatile` or `allowzero` keyword.
pub fn isSizeOnePoiner(
    comptime Item: type,
    comptime Ptr: type,
) bool {
    return switch (@typeInfo(Ptr)) {
        .pointer => |p| p.size == .one and p.child == Item,
        else => false,
    };
}

test isSizeOnePoiner {
    try std.testing.expect(isSizeOnePoiner(usize, *usize));
    try std.testing.expect(isSizeOnePoiner(usize, *const usize));
    try std.testing.expect(isSizeOnePoiner(usize, *allowzero const volatile usize));

    try std.testing.expect(!isSizeOnePoiner(usize, usize));
    try std.testing.expect(!isSizeOnePoiner(usize, *isize));
    try std.testing.expect(!isSizeOnePoiner(usize, **usize));
    try std.testing.expect(!isSizeOnePoiner(usize, []usize));
    try std.testing.expect(!isSizeOnePoiner(usize, [*]usize));
}

/// Checks if a given type is an iterator over a particular type
///
/// In particular, this function returns true if `Iterator` has
/// the function `next` in its implementation as follows:
///
/// ```zig
/// const Iterator = struct {
///     // ...
///     pub fn next(self: *Iterator) ?Item {
///         // ...
///     }
/// };
/// ```
///
/// Note that the first parameter of `next` can also have the `const`,
/// `volatile` or `allowzero` keyword.
pub fn isIterator(
    comptime Item: type,
    comptime Iterator: type,
) bool {
    switch (@typeInfo(Iterator)) {
        .@"struct" => {
            if (@hasDecl(Iterator, "next")) {
                switch (@typeInfo(@TypeOf(Iterator.next))) {
                    .@"fn" => |func| {
                        return //
                        func.params.len == 1 //
                        and func.params[0].type != null //
                        and (isSizeOnePoiner(Iterator, func.params[0].type.?) or (Iterator == func.params[0].type.?)) //
                        and func.return_type == ?Item;
                    },
                    else => return false,
                }
            } else {
                return false;
            }
        },
        else => return false,
    }
}

fn subtractOneFromDepth(depth: ?usize) ?usize {
    if (depth) |l| {
        if (l > 0) return l - 1;
        return l;
    } else {
        return null;
    }
}

/// Compares two elements of the same type.
///
/// Recursively compares the two variables.
///
/// Note this function
///   * cannot compare variables of type
///     - untagged unions,
///     - opaques,
///     - functions,
///     - frames,
///     - anytype, or
///     - anyframe;
///   * does not follow pointers with the exception of slices; and
///   * will use `@typeName`, `@errorName` and `@tagName` where appropriate,
///     and thus will require these pieces fo information to be stored in the
///     compiled program if used.
pub fn order(
    a: anytype,
    b: @TypeOf(a),
    /// How deep should we follow pointers
    ///
    /// If this is `null`, then there is no limit
    comptime depth: ?usize,
) Order {
    const T = @TypeOf(a);

    switch (@typeInfo(T)) {
        .type => return order(@typeName(a), @typeName(b), 1),
        .void, .noreturn, .undefined, .null => return .eq,
        .bool => {
            if (a == b) {
                return .eq;
            } else if (a) {
                return .gt;
            } else {
                return .lt;
            }
        },
        .array => {
            if (a.len > b.len) return order(b, a, depth).invert();
            for (a, 0..) |_, i| {
                const tmp = order(a[i], b[i], depth);
                if (tmp != .eq) {
                    return tmp;
                }
            }
            if (a.len < b.len) return .lt;
            return .eq;
        },
        .vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                const tmp = order(a[i], b[i], depth);
                if (tmp != .eq) {
                    return tmp;
                }
            }
            return .eq;
        },
        .@"struct" => |info| {
            inline for (info.fields) |field_info| {
                const field_order = order(
                    @field(a, field_info.name),
                    @field(b, field_info.name),
                    depth,
                );
                if (field_order != .eq) {
                    return field_order;
                }
            }
            return .eq;
        },
        .optional => {
            // null < not_null
            if (a == null and b == null) {
                return .eq;
            } else if (a == null) {
                return .lt;
            } else if (b == null) {
                return .gt;
            } else {
                return order(a.?, b.?, depth);
            }
        },
        .error_union => {
            // we choose `error < value`
            if (a) |a_p| {
                if (b) |b_p| {
                    return order(a_p, b_p, depth);
                } else |_| {
                    return .gt;
                }
            } else |a_e| {
                if (b) |_| {
                    return .lt;
                } else |b_e| {
                    return order(a_e, b_e, depth);
                }
            }
        },
        .error_set => {
            return order(@errorName(a), @errorName(b), 1);
        },
        .@"enum", .enum_literal => {
            return order(@tagName(a), @tagName(b), 1);
        },
        .@"union" => |info| {
            if (info.tag_type) |UnionTag| {
                const tag_a: UnionTag = a;
                const tag_b: UnionTag = b;

                {
                    const tmp = order(tag_a, tag_b, depth);
                    if (tmp != .eq) {
                        return tmp;
                    }
                }

                return switch (a) {
                    inline else => |val, tag| return order(val, @field(b, @tagName(tag)), depth),
                };
            } else {
                @compileError("cannot compare untagged union type " ++ @typeName(T));
            }
        },
        .pointer => |info| {
            comptime {
                if (depth == 0) {
                    @compileError("Too many pointer dereferences required to compare types.");
                }
            }
            switch (info.size) {
                .one => {
                    return order(
                        a.*,
                        b.*,
                        subtractOneFromDepth(depth),
                    );
                },
                .many, .c => {
                    return order(
                        std.mem.span(a),
                        std.mem.span(b),
                        depth,
                    );
                },
                .slice => {
                    if (a.len > b.len) return order(b, a, depth).invert();
                    for (a, 0..) |_, i| {
                        const tmp = order(
                            a[i],
                            b[i],
                            subtractOneFromDepth(depth),
                        );
                        if (tmp != .eq) {
                            return tmp;
                        }
                    }
                    if (a.len < b.len) return .lt;
                    return .eq;
                },
            }
        },
        .int, .float, .comptime_int, .comptime_float => return std.math.order(a, b),
        else => @compileError("cannot compare variables of type " ++ @typeName(T)),
    }
}

test isIterator {
    const TestIterator = struct {
        fn next(self: *@This()) ?usize {
            _ = &self;
            return null;
        }
    };

    std.debug.assert(isIterator(usize, TestIterator));

    const TestIterator2 = struct {
        // we allow this case if the iterator is just a non-mutable handle
        fn next(self: @This()) ?usize {
            _ = &self;
            return null;
        }
    };

    std.debug.assert(isIterator(usize, TestIterator2));

    const Tree = rbtree.DefaultRBTree(usize, void);

    std.debug.assert(isIterator(Tree.KV, Tree.KVIterator));
    std.debug.assert(isIterator(Tree.Entry, Tree.EntryIterator));
}
