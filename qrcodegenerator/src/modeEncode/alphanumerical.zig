const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;

const INVALID: u8 = 0xFF;

const alphanumeric_table: [128]u8 = blk: {
    var t = [_]u8{INVALID} ** 128;
    t['0'] = 0;
    t['1'] = 1;
    t['2'] = 2;
    t['3'] = 3;
    t['4'] = 4;
    t['5'] = 5;
    t['6'] = 6;
    t['7'] = 7;
    t['8'] = 8;
    t['9'] = 9;
    t['A'] = 10;
    t['B'] = 11;
    t['C'] = 12;
    t['D'] = 13;
    t['E'] = 14;
    t['F'] = 15;
    t['G'] = 16;
    t['H'] = 17;
    t['I'] = 18;
    t['J'] = 19;
    t['K'] = 20;
    t['L'] = 21;
    t['M'] = 22;
    t['N'] = 23;
    t['O'] = 24;
    t['P'] = 25;
    t['Q'] = 26;
    t['R'] = 27;
    t['S'] = 28;
    t['T'] = 29;
    t['U'] = 30;
    t['V'] = 31;
    t['W'] = 32;
    t['X'] = 33;
    t['Y'] = 34;
    t['Z'] = 35;
    t[' '] = 36;
    t['$'] = 37;
    t['%'] = 38;
    t['*'] = 39;
    t['+'] = 40;
    t['-'] = 41;
    t['.'] = 42;
    t['/'] = 43;
    t[':'] = 44;
    break :blk t;
};

pub fn encode(inp: []const u8, out: []u8) ![]u8 {
    var outPos: usize = 0;
    var res: []u8 = undefined;
    var nbits: usize = 0;

    var chunk = mem.window(u8, inp, 2, 2);

    while (chunk.next()) |group| {
        const first_char_val = alphanumeric_table[group[0]];
        if (first_char_val == INVALID) return error.InvalidCharacter;

        var buf: [11]u8 = undefined;

        if (group.len == 2) {
            nbits = 11;

            const second_char_val = alphanumeric_table[group[1]];
            if (second_char_val == INVALID) return error.InvalidCharacter;
            const total_val = (45 * @as(u16, first_char_val)) + second_char_val;

            res = try fmt.bufPrint(&buf, "{b}", .{total_val});
        } else {
            nbits = 6;
            res = try fmt.bufPrint(&buf, "{b}", .{first_char_val});
        }

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

test "HE pair -> (45*17)+14=779 -> 01100001011" {
    var out: [1024]u8 = undefined;
    const result = try encode("HE", &out);
    try testing.expectEqualStrings("01100001011", result);
}

test "LL pair -> (45*21)+21=966 -> 01111000110" {
    var out: [1024]u8 = undefined;
    const result = try encode("LL", &out);
    try testing.expectEqualStrings("01111000110", result);
}

test "O space pair -> (45*24)+36=1116 -> 10001011100" {
    var out: [1024]u8 = undefined;
    const result = try encode("O ", &out);
    try testing.expectEqualStrings("10001011100", result);
}

test "WO pair -> (45*32)+24=1464 -> 10110111000" {
    var out: [1024]u8 = undefined;
    const result = try encode("WO", &out);
    try testing.expectEqualStrings("10110111000", result);
}

test "RL pair -> (45*27)+21=1236 -> 10011010100" {
    var out: [1024]u8 = undefined;
    const result = try encode("RL", &out);
    try testing.expectEqualStrings("10011010100", result);
}

test "odd single char D -> 13 -> 001101" {
    var out: [1024]u8 = undefined;
    const result = try encode("D", &out);
    try testing.expectEqualStrings("001101", result);
}

test "HELLO WORLD -> all pairs concatenated + final D" {
    var out: [1024]u8 = undefined;
    const result = try encode("HELLO WORLD", &out);
    try testing.expectEqualStrings("0110000101101111000110100010111001011011100010011010100001101", result);
}

test "invalid lowercase returns error" {
    var out: [1024]u8 = undefined;
    try testing.expectError(error.InvalidCharacter, encode("he", &out));
}
