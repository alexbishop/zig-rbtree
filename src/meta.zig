//! Provides a default comparison function
const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

fn subtract_level(level: ?usize) ?usize {
    if (level) |l| {
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
    comptime level: ?usize,
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
            if (a.len > b.len) return order(b, a, level).invert();
            for (a, 0..) |_, i| {
                const tmp = order(a[i], b[i], level);
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
                const tmp = order(a[i], b[i], level);
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
                    level,
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
                return order(a.?, b.?, level);
            }
        },
        .error_union => {
            // we choose `error < value`
            if (a) |a_p| {
                if (b) |b_p| {
                    return order(a_p, b_p, level);
                } else |_| {
                    return .gt;
                }
            } else |a_e| {
                if (b) |_| {
                    return .lt;
                } else |b_e| {
                    return order(a_e, b_e, level);
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
                    const tmp = order(tag_a, tag_b, level);
                    if (tmp != .eq) {
                        return tmp;
                    }
                }

                return switch (a) {
                    inline else => |val, tag| return order(val, @field(b, @tagName(tag)), level),
                };
            } else {
                @compileError("cannot compare untagged union type " ++ @typeName(T));
            }
        },
        .pointer => |info| {
            comptime {
                if (level == 0) {
                    @compileError(
                        \\Too many pointer dereferences required to compare types.
                    );
                }
            }
            return switch (info.size) {
                .one => {
                    return order(
                        a.*,
                        b.*,
                        subtract_level(level),
                    );
                },
                .many, .c => {
                    return order(
                        std.mem.span(a),
                        std.mem.span(b),
                        level,
                    );
                },
                .slice => {
                    if (a.len > b.len) return order(b, a, level).invert();
                    for (a, 0..) |_, i| {
                        const tmp = order(
                            a[i],
                            b[i],
                            subtract_level(level),
                        );
                        if (tmp != .eq) {
                            return tmp;
                        }
                    }
                    if (a.len < b.len) return .lt;
                    return .eq;
                },
            };
        },
        .int, .float, .comptime_int, .comptime_float => return std.math.order(a, b),
        else => @compileError("cannot compare variables of type " ++ @typeName(T)),
    }
}
