const std = @import("std");

const zenvars = @import("zenvars_lib");

pub const Person = struct {
    name: []const u8 = "none",
    age: i32 = 0,
    male: bool = false,
    pi: f32 = 3.0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const p = try zenvars.parseFromFile(alloc, "", Person);

    std.debug.print("name={s} age={d} male={} pi={d}\n", .{ p.name, p.age, p.male, p.pi });
}
