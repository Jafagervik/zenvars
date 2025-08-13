//! Root source lib file
const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Load closest env file into struct
pub fn parse(allocator: Allocator, comptime T: type) !T {
    const path = findEnvFile() catch {
        print("Could not find env file", .{});
        return error.EnvFileNotFound;
    };
    return try readEnvFile(allocator, path, T);
}

/// Parse env file into struct by filename
pub fn parseFromFile(allocator: Allocator, filename: []const u8, comptime T: type) !T {
    return readEnvFile(allocator, filename, T);
}

/// Find closest env file in your project
fn findEnvFile() ![]const u8 {
    return error.EnvFileNotFound;
}

fn readEnvFile(allocator: Allocator, path: []const u8, comptime T: type) !T {
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit(); // TODO: is this the wrong one?

    const writer = line.writer();

    var t: T = T{};

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();

        // Comment at the start is allowed for now
        if (line.items[0] == '#') continue;

        var iter = std.mem.splitAny(u8, line.items, "=");

        const key = iter.next() orelse {
            print("missing key\n", .{});
            return error.MissingKey;
        };

        const value = iter.next() orelse {
            print("Missing Value for key={s}\n", .{key});
            return error.MissingValue;
        };

        if (iter.next()) |_| {
            print("Too many items\n", .{});
            return error.EnvFileNotFound;
        }

        try setStructFieldByName(T, &t, key, value, allocator);
    } else |err| switch (err) {
        error.EndOfStream => {}, // End of file
        else => return err, // Propagate error
    }

    return t;
}

// Generic function to set a field by name for any struct
fn setStructFieldByName(
    /// Env var struct type
    comptime T: type,
    /// Pointer to instance of this new type
    instance: *T,
    /// Name of struct field to set
    field_name: []const u8,
    /// Value of struct field to set
    value: anytype,
    allocator: Allocator,
) !void {
    comptime {
        std.debug.assert(@typeInfo(T) == .@"struct");
    }
    // if (@typeInfo(T) != .@"struct") return error.NotAStruct;

    // Iterate over the struct's fields at compile time
    inline for (std.meta.fields(T)) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            switch (@typeInfo(field.type)) {
                .pointer => |ptr| {
                    if (ptr.child != u8 or !ptr.is_const or ptr.size != .slice) {
                        return error.UnsupportedType;
                    }
                    // Ensure value is a string and allocator is provided
                    if (@TypeOf(value) != []const u8) return error.TypeMismatch;

                    // Duplicate the string to ensure proper memory management
                    @field(instance, field.name) = try allocator.dupe(u8, value);
                    return;
                },
                .int => {
                    @field(instance, field.name) = try std.fmt.parseInt(field.type, value, 10);
                    return;
                },
                .float => {
                    @field(instance, field.name) = try std.fmt.parseFloat(field.type, value);
                    return;
                },
                .bool => {
                    if (parseStringToBool(value)) |b| {
                        @field(instance, field.name) = b;
                        return;
                    }
                    return error.TypeMismatch;
                },
                else => return error.UnsupportedType,
            }
        }
    }
    print("No element found for key={s}\n", .{field_name});
    return error.FieldNotFound;
}

inline fn parseStringToBool(s: []const u8) ?bool {
    if (std.ascii.eqlIgnoreCase(s, "true") or std.ascii.eqlIgnoreCase(s, "1"))
        return true;
    if (std.ascii.eqlIgnoreCase(s, "false") or std.ascii.eqlIgnoreCase(s, "0"))
        return false;
    return null;
}

test "Test parse string to bool" {
    try std.testing.expectEqual(true, parseStringToBool("true").?);
    try std.testing.expectEqual(true, parseStringToBool("True").?);
    try std.testing.expectEqual(true, parseStringToBool("1").?);
    try std.testing.expectEqual(false, parseStringToBool("false").?);
    try std.testing.expectEqual(false, parseStringToBool("False").?);
    try std.testing.expectEqual(false, parseStringToBool("0").?);
    try std.testing.expectEqual(null, parseStringToBool(""));
    try std.testing.expectEqual(null, parseStringToBool("  "));
    try std.testing.expectEqual(null, parseStringToBool("  true"));
}
