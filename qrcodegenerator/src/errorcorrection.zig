const std = @import("std");
const prime = 0x11d;

const Exp: [512]u8 = blk: {
    var t: [512]u8 = undefined;
    var value: usize = 1;
    var i: usize = 0;

    while (i < 255) : (i += 1) {
        t[i] = @intCast(value);
        value <<= 1;
        if (value & 0x100 != 0) value ^= prime;
    }

    i = 255;
    while (i < 512) : (i += 1) t[i] = t[i - 255];
    break :blk t;
};

const Log: [256]u8 = blk: {
    var t: [512]u8 = undefined;
    var i: usize = 1;

    while (i < 255) : (i += 1) t[Exp[i]] = @intCast(i);
    t[0] = 0;
    break :blk t;
};

fn gfMul(a: u8, b: u8) u8 {
    if (a == 0 and b == 0) return 0;
    return Exp[@as(usize, Log(a)) + @as(usize, Log(b))];
}
