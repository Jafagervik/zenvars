# Zenvars - Parse .env files into Zig structs

![CI](https://github.com/Jafagervik/zenvars/actions/workflows/ci.yml/badge.svg)
![](https://img.shields.io/badge/language-zig-%23ec915c)
[![License: Zlib](https://img.shields.io/badge/License-Zlib-lightgrey.svg)](https://opensource.org/licenses/Zlib)

## Install

First to install, run:
```sh 
zig fetch --save git+https://github.com/Jafagervik/zenvars#v1.0.0
```
Swap out version with any of the newer versions

Add the zenvars module to your `build.zig` file this:

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

Given you have a `.env` file somewhere like this
```dosini
# COMMENT will not be parsed
name=Me
age=42#0 
male=
pi=3.14
```

> [!NOTE]
> Keys can have empty values. in that case, the default value of the struct will be used
> Comments starts with #, so everything to the rightside will be ignored

> [!NOTE]
> The keys are case insensitive, so you could have a key `NICK_NAME` in your env file
> This will then map to field `nick_name` in your struct


Now, you can simply use it as is shown in the example below:

```zig 
const std = @import("std");
const zenvars = @import("zenvars");

// Default values are necessary
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
    _ = try zenvars.parse(alloc, EnvVars, .{});
    // You can even show the path if you'd like
    _ = try zenvars.parse(alloc, EnvVars, .{ .show_path = true });

    std.debug.print("name={s} age={d} male={} pi={d}\n", .{ p.name, p.age, p.male, p.pi });
}
```

## Functions and Types

`parse(std.mem.Allocator, comptime T: type, opts: Options)` 

```zig
const Options = struct {
    filepath: ?[]const u8 = null,
    show_path: bool = false,
};
```

- `filepath`: If set, this will try to open the file at that specific location, otherwise
the closest top-level `.env` file will be used
- `show_path`: If true, the full path to the `.env` file will be printed

> [!NOTE]
> `show_path` is best used when `filepath` is not set


## Supported types

* Floats (all kinds)
* Integers (all kinds)
* Strings ([]const u8 for now)
* Bools
* Enums
