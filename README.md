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

Then, to use it, include it in a file like such: 

```zig 
const std = @import("std");
const zenvars = @import("zenvars");

// The env file variables will override these default values
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

    // IMPORTANT: An arena allocator is needed for now
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const p = try zenvars.parseFromFile(alloc, "/path/to/your/.env", Person);

    std.debug.print("name={s} age={d} male={} pi={d}\n", .{ p.name, p.age, p.male, p.pi });
}
```

## Supported types

* Floats (all kinds)
* Integers (all kinds)
* Strings ([]const u8 for now)
* Bools
