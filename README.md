# Zenvars - Parse .envfiles into structs!

## Install

First to install, run:
```sh 
zig fetch --save git+https://github.com/Jafagervik/zenvars#v1.0.0
```

In your `build.zig` file: add like this:

```zig 
const target = b.standardTargetOptions(.{});
const optimize = b.standardOptimizeOption(.{});

const zenvars_dep = b.dependency("zenvars", .{});
const zenvars = zstb_dep.module("zenvars");

const exe_mod = b.createModule(.{
    .root_source_file = b.path("path/to/your/main/source/file"),
    .target = target,
    .optimize = optimize,
});

exe_mod.addImport("zenvars", zenvars);
```

## Usage

Given you have a .env file somewhere like this
```dosini
# COMMENT will not be parsed
name=Me
age=420
male=true
pi=3.14
```

> [!WARNING]
> Field names in result struct are case sensitive, so the keys need to directly
> match the struct field names

Then, to use it, include it in a file like such: 

```zig 
const std = @import("std");
const zenvars = @import("zenvars");

// 
pub const EnvVars = struct {
    name: []const u8 = "none", 
    age: i32 = 0,
    male: bool = false,
    pi: f32 = 3.0,
};

pub fn main() !void {
    // IMPORTANT: An arena allocator is needed for now
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const envs = try zenvars.parse(alloc, EnvVars, .{.filepath="/path/to/your/.env"});
    // Or you might want to let the program find it 
    const envs2 = try zenvars.parse(alloc, EnvVars, .{});

    std.debug.print("name={s} age={d} male={} pi={d}\n", .{ p.name, p.age, p.male, p.pi });
}
```

## Functions 

`parse(std.mem.Allocator, comptime T: type, opts: Options)` 

Options only contain one field `filepath` which is of type `?[]const u8`, meaning 
that if you set it, you specificaly want to point to your path


## Supported types

* Floats (all kinds)
* Integers (all kinds)
* Strings ([]const u8 for now)
* Bools
