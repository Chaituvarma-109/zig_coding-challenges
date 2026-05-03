const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;

pub fn encode(inp: []const u8, out: []u8) ![]u8 {
    var outPos: usize = 0;
    var chunk = mem.window(u8, inp, 3, 3);

    while (chunk.next()) |group| {
        const nbits: usize = blk: switch (group.len) {
            3 => {
                if (group[0] == '0' and group[1] == '0') break :blk 4;
                if (group[0] == '0') break :blk 7;
                break :blk 10;
            },
            2 => break :blk 7,
            1 => break :blk 4,
            else => unreachable,
        };

        const effective_group = switch (nbits) {
            4 => group[group.len - 1 ..],
            7 => group[group.len - 2 ..],
            else => group,
        };

        const val = try fmt.parseInt(u16, effective_group, 10);

        var buff: [10]u8 = undefined;
        const res = try fmt.bufPrint(&buff, "{b}", .{val});

        if (outPos + nbits > out.len) return error.BufferTooSmall;

        if (res.len < nbits) {
            const pad = nbits - res.len;
            @memset(out[outPos .. outPos + pad], '0');
            @memcpy(out[outPos + pad .. outPos + nbits], res);
        } else {
            @memcpy(out[outPos .. outPos + nbits], res);
        }

        outPos += nbits;
    }

    return out[0..outPos];
}

test "8675309 -> 1101100011 1000010010 1001" {
    var out: [1024]u8 = undefined;
    const result = try encode("8675309", &out);
    try testing.expectEqualStrings("110110001110000100101001", result);
}

test "000 -> 0000 (two leading zeros -> 4 bits)" {
    var out: [1024]u8 = undefined;
    const result = try encode("000", &out);
    try testing.expectEqualStrings("0000", result);
}

test "042 -> 0101010 (one leading zero -> 7 bits)" {
    var out: [1024]u8 = undefined;
    const result = try encode("042", &out);
    try testing.expectEqualStrings("0101010", result);
}

test "two-digit remainder -> 7 bits" {
    var out: [1024]u8 = undefined;
    const result = try encode("53", &out);
    try testing.expectEqualStrings("0110101", result);
}

test "one-digit remainder -> 4 bits" {
    var out: [1024]u8 = undefined;
    const result = try encode("9", &out);
    try testing.expectEqualStrings("1001", result);
}
