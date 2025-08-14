const std = @import("std");
const zenvars = @import("zenvars");

const EnvArgs = struct {
    name: []const u8 = "none",
    age: i32 = 0,
    male: bool = false,
    pi: f32 = 3.0,
    max_lifetime: usize = 50,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    //const args = try zenvars.parse(alloc, EnvArgs, .{ .filepath = "/Users/jaf/p/zig/zenvars/.env" });
    const args = try zenvars.parse(alloc, EnvArgs, .{ .show_path = true });
    std.debug.print("name={s} age={d} male={} pi={d}, max_lifetime={d}\n", .{
        args.name,
        args.age,
        args.male,
        args.pi,
        args.max_lifetime,
    });
}
