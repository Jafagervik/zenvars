const std = @import("std");
const zenvars = @import("zenvars");

pub const Person = struct {
    name: []const u8 = "none",
    age: i32 = 0,
    male: bool = false,
    pi: f32 = 3.0,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const p = try zenvars.parse(alloc, Person, .{ .filepath = "/Users/jaf/p/zig/zenvars/.env" });
    std.debug.print("name={s} age={d} male={} pi={d}\n", .{ p.name, p.age, p.male, p.pi });
}
