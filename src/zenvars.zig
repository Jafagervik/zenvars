//! Root source lib file
const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Options = struct {
    filepath: ?[]const u8 = null,
};

pub fn parse(allocator: Allocator, comptime T: type, opts: Options) !T {
    if (opts.filepath) |filepath| {
        return try readEnvFile(allocator, filepath, T);
    }

    // Parses closest .env file into struct `T`
    const path = findEnvPath(allocator) catch {
        print("Could not find env file\n", .{});
        return error.EnvFileNotFound;
    };
    return try readEnvFile(allocator, path, T);
}

// Helper function to find the absolute path to the top-level .env file.
fn findEnvPath(allocator: Allocator) ![]const u8 {
    var path_buf: [fs.max_path_bytes]u8 = undefined;
    const cwd_path = try fs.cwd().realpath(".", &path_buf);
    var current_path = try allocator.dupe(u8, cwd_path);

    while (true) {
        const env_path = try std.fs.path.join(allocator, &.{ current_path, ".env" });
        std.fs.accessAbsolute(env_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                // Not found here; go up a directory.
                const parent = std.fs.path.dirname(current_path) orelse {
                    return error.EnvFileNotFound;
                };
                // If parent is the same as current, we're at root (shouldn't happen, but safety check).
                if (std.mem.eql(u8, parent, current_path)) {
                    return error.EnvFileNotFound;
                }
                current_path = try allocator.dupe(u8, parent);
                continue;
            },
            else => return err,
        };
        // Found it; return the absolute path (dupe it to the caller's allocator).
        return allocator.dupe(u8, env_path);
    }
}

fn readEnvFile(allocator: Allocator, path: []const u8, comptime T: type) !T {
    const file = fs.cwd().openFile(path, .{}) catch {
        print("Could not open file with path={s}\n", .{path});
        return error.FileNotFound;
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    const writer = line.writer();

    var output_struct: T = T{};

    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();

        // Comment at the start is allowed for now
        if (line.items[0] == '#') continue;

        var iter = std.mem.splitAny(u8, line.items, "=");

        const key = iter.next() orelse {
            print("Missing key\n", .{});
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

        try setStructFieldByName(T, &output_struct, key, value, allocator);
    } else |err| switch (err) {
        error.EndOfStream => {}, // End of file
        else => return err, // Propagate error
    }

    return output_struct;
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
