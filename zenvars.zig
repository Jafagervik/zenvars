//! Zenvars root module
const std = @import("std");
const fs = std.fs;
const print = std.debug.print;
const eqlIgnoreCase = std.ascii.eqlIgnoreCase;
const isWhitespace = std.ascii.isWhitespace;
const Allocator = std.mem.Allocator;

const MAX_BUF_SIZE: usize = 128;

const Options = struct {
    /// Optional path to `.env` file
    filepath: ?[]const u8 = null,
    /// Print path found or not
    show_path: bool = false,
};

/// Parses a .env(.(a-zA-Z))* file and sets values in struct `T`
/// based on the values in the file
pub fn parse(allocator: Allocator, comptime T: type, opts: Options) !T {
    const path = if (opts.filepath) |filepath|
        filepath
    else
        findEnvPath(allocator, opts.show_path) catch {
            print("Could not find env file\n", .{});
            return error.EnvFileNotFound;
        };

    return try readEnvFile(allocator, path, T);
}

// Helper function to find the absolute path to the top-level .env file.
fn findEnvPath(allocator: Allocator, show_path: bool) ![]const u8 {
    var path_buf: [fs.max_path_bytes]u8 = undefined;
    const cwd_path = try fs.cwd().realpath(".", &path_buf);
    var current_path = try allocator.dupe(u8, cwd_path);

    while (true) {
        const env_path = try std.fs.path.join(allocator, &.{ current_path, ".env" });
        std.fs.accessAbsolute(env_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                // Not found here; go up a directory.
                const parent = std.fs.path.dirname(current_path) orelse return error.EnvFileNotFound;
                // If parent is the same as current, we're at root (shouldn't happen, but safety check).
                if (std.mem.eql(u8, parent, current_path)) return error.EnvFileNotFound;

                current_path = try allocator.dupe(u8, parent);
                continue;
            },
            else => return err,
        };
        // Found it; return the absolute path (dupe it to the caller's allocator).
        const path = allocator.dupe(u8, env_path) catch return error.DupeError;

        if (show_path) print("Path found at: {s}\n", .{path});
        return path;
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

        var items: []const u8 = std.mem.trim(u8, line.items, " \t\r");
        if (items.len == 0 or items[0] == '#') continue;

        const end_idx: usize = blk: {
            for (items, 0..) |c, i| {
                if (c == '#') break :blk i;
            } else break :blk items.len;
        };

        items = items[0..end_idx];
        if (items.len == 0) continue;

        var iter = std.mem.splitAny(u8, items, "=");
        const key = iter.next() orelse return error.MissingKey;

        var buffer: [MAX_BUF_SIZE]u8 = undefined;
        if (key.len > buffer.len) return error.KeyTooLong;

        for (key, 0..) |c, i| buffer[i] = std.ascii.toLower(c);

        const keyLowered: []const u8 = buffer[0..key.len];
        const val = iter.next() orelse return error.MissingValue;

        if (std.mem.eql(u8, "", val)) continue;
        if (iter.next()) |_| return error.TooManyEqualSigns;

        try setStructFieldByName(T, &output_struct, keyLowered, val, allocator);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return err,
    }

    return output_struct;
}

// Generic function to set a field by name for any struct
fn setStructFieldByName(
    comptime T: type,
    instance: *T,
    field_name: []const u8,
    value: []const u8,
    allocator: Allocator,
) !void {
    comptime std.debug.assert(@typeInfo(T) == .@"struct");

    inline for (std.meta.fields(T)) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return switch (@typeInfo(field.type)) {
                .pointer => |ptr| {
                    if (ptr.child != u8 or !ptr.is_const or ptr.size != .slice)
                        return error.UnsupportedType;
                    @field(instance, field.name) = try allocator.dupe(u8, value);
                },
                .@"enum" => {
                    const val = std.meta.stringToEnum(field.type, value) orelse return error.InvalidEnumValue;
                    @field(instance, field.name) = val;
                },
                .int => @field(instance, field.name) = try std.fmt.parseInt(field.type, value, 10),
                .float => @field(instance, field.name) = try std.fmt.parseFloat(field.type, value),
                .bool => {
                    if (parseStringToBool(value)) |b| {
                        @field(instance, field.name) = b;
                    } else return error.TypeMismatch;
                },
                else => return error.UnsupportedType,
            };
        }
    }

    print("No element found for key={s}\n", .{field_name});
    return error.FieldNotFound;
}

inline fn parseStringToBool(s: []const u8) ?bool {
    if (eqlIgnoreCase(s, "true") or eqlIgnoreCase(s, "1"))
        return true;
    if (eqlIgnoreCase(s, "false") or eqlIgnoreCase(s, "0"))
        return false;
    return null;
}

const testing = std.testing;
// test "Parsing" {
//     const EnvArgs = struct {
//         name: []const u8 = "none",
//         age: i32 = 0,
//         male: bool = false,
//         pi: f32 = 3.0,
//         max_lifetime: usize = 50,
//         nick_name: []const u8 = "yoyo",
//     };
//
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();
//     const alloc = arena.allocator();
//
//     const args = try parse(alloc, EnvArgs, .{});
//
//     try std.testing.expectEqualSlices(u8, "Me", args.name);
//     try std.testing.expectEqual(420, args.age);
//     try std.testing.expectEqual(true, args.male);
//     try std.testing.expectEqual(3.0, args.pi);
//     try std.testing.expectEqual(50, args.max_lifetime);
//     try std.testing.expectEqualSlices(u8, "yoyo", args.nick_name);
// }

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
