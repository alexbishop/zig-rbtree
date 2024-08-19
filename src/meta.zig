//! This file contains helper methods
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

/// Compares two elements of the same type.
///
/// This function is intended as a generalisation of `std.meta.eql`.
///
/// This function recursively compares the two types, but does not follow pointers.
/// Note that this function does not compare variables of type `Fn`, `Opaque`, `Frame` or `AnyFrame`.
pub fn order(a: anytype, b: @TypeOf(a)) Order {
    const T = @TypeOf(a);

    switch (@typeInfo(T)) {
        .Type => return order(@typeName(a), @typeName(b)),
        .Void, .NoReturn, .Undefined, .Null, .ErrorSet => return .eq,
        .Bool => {
            if (a == b) {
                return .eq;
            } else if (a) {
                return .gt;
            } else {
                return .lt;
            }
        },
        .Array => {
            {
                const tmp = order(a.len, b.len);
                if (tmp != .eq) {
                    return tmp;
                }
            }
            for (a, 0..) |e, i| {
                const tmp = order(e, b[i]);
                if (tmp != .eq) {
                    return tmp;
                }
            }
            return .eq;
        },
        .Vector => |info| {
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                const tmp = order(a[i], b[i]);
                if (tmp != .eq) {
                    return tmp;
                }
            }
            return .eq;
        },
        .Struct => |info| {
            inline for (info.fields) |field_info| {
                const field_order = order(
                    @field(a, field_info.name),
                    @field(b, field_info.name),
                );
                if (field_order != .eq) {
                    return field_order;
                }
            }
            return .eq;
        },
        .Optional => {
            // null < not_null
            if (a == null and b == null) {
                return .eq;
            } else if (a == null) {
                return .lt;
            } else if (b == null) {
                return .gt;
            } else {
                return order(a.?, b.?);
            }
        },
        .ErrorUnion => {
            // we choose `error < value`
            if (a) |a_p| {
                if (b) |b_p| {
                    return order(a_p, b_p);
                } else |_| {
                    return .gt;
                }
            } else |a_e| {
                if (b) |_| {
                    return .lt;
                } else |b_e| {
                    return order(a_e, b_e);
                }
            }
        },
        .Enum, .EnumLiteral => return order(@intFromEnum(a), @intFromEnum(b)),
        .Union => |info| {
            if (info.tag_type) |UnionTag| {
                const tag_a: UnionTag = a;
                const tag_b: UnionTag = b;

                {
                    const tmp = order(tag_a, tag_b);
                    if (tmp != .eq) {
                        return tmp;
                    }
                }

                return switch (a) {
                    inline else => |val, tag| return order(val, @field(b, @tagName(tag))),
                };
            }

            @compileError("cannot compare untagged union type " ++ @typeName(T));
        },
        .Pointer => |info| {
            return switch (info.size) {
                .One, .Many, .C => order(@intFromPtr(a), @intFromPtr(b)),
                .Slice => {
                    {
                        const tmp = order(a.len, b.len);
                        if (tmp != .eq) return tmp;
                    }
                    return order(a.ptr, b.ptr);
                },
            };
        },
        .Int, .Float, .ComptimeInt, .ComptimeFloat => return std.math.order(a, b),
        else => @compileError("cannot compare variables of type " ++ @typeName(T)),
    }
}
