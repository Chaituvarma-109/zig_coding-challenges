const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

pub fn encode(inp: []const u8, out: []u8) ![]u8 {
    if (out.len < inp.len * 8) return error.BufferTooSmall;

    for (inp, 0..) |byte, i| {
        var buf: [8]u8 = undefined;
        const bin = try fmt.bufPrint(&buf, "{b}", .{byte});

        const start = i * 8;
        if (bin.len < 8) {
            const pad = 8 - bin.len;
            @memset(out[start .. start + pad], '0');
            @memcpy(out[start + pad .. start + 8], bin);
        } else {
            @memcpy(out[start .. start + 8], bin);
        }
    }

    return out[0 .. inp.len * 8];
}

test "H -> 01001000" {
    var out: [8]u8 = undefined;
    const result = try encode("H", &out);
    try testing.expectEqualStrings("01001000", result);
}

test "Hello, world! -> correct 8-bit binary per byte" {
    var out: [1024]u8 = undefined;
    const result = try encode("Hello, world!", &out);
    try testing.expectEqualStrings(
        "01001000" // H  0x48
        ++ "01100101" // e  0x65
        ++ "01101100" // l  0x6c
        ++ "01101100" // l  0x6c
        ++ "01101111" // o  0x6f
        ++ "00101100" // ,  0x2c
        ++ "00100000" //    0x20
        ++ "01110111" // w  0x77
        ++ "01101111" // o  0x6f
        ++ "01110010" // r  0x72
        ++ "01101100" // l  0x6c
        ++ "01100100" // d  0x64
        ++ "00100001", // ! 0x21
        result,
    );
}

test "my name is claude -> full 136-bit binary string" {
    var out: [1024]u8 = undefined;
    const result = try encode("my name is claude", &out);
    try testing.expectEqualStrings(
        "01101101" // m  0x6d
        ++ "01111001" // y  0x79
        ++ "00100000" //    0x20
        ++ "01101110" // n  0x6e
        ++ "01100001" // a  0x61
        ++ "01101101" // m  0x6d
        ++ "01100101" // e  0x65
        ++ "00100000" //    0x20
        ++ "01101001" // i  0x69
        ++ "01110011" // s  0x73
        ++ "00100000" //    0x20
        ++ "01100011" // c  0x63
        ++ "01101100" // l  0x6c
        ++ "01100001" // a  0x61
        ++ "01110101" // u  0x75
        ++ "01100100" // d  0x64
        ++ "01100101", // e  0x65
        result,
    );
}

test "null byte (0x00) -> 00000000 (max left padding)" {
    var out: [8]u8 = undefined;
    const result = try encode(&[_]u8{0x00}, &out);
    try testing.expectEqualStrings("00000000", result);
}

test "0xFF -> 11111111 (no padding needed)" {
    var out: [8]u8 = undefined;
    const result = try encode(&[_]u8{0xFF}, &out);
    try testing.expectEqualStrings("11111111", result);
}

test "space (0x20) -> 00100000" {
    var out: [8]u8 = undefined;
    const result = try encode(" ", &out);
    try testing.expectEqualStrings("00100000", result);
}

test "empty input -> empty output" {
    var out: [8]u8 = undefined;
    const result = try encode("", &out);
    try testing.expectEqualStrings("", result);
}

test "buffer too small returns error" {
    var out: [7]u8 = undefined; // needs 8 for a single char
    try testing.expectError(error.BufferTooSmall, encode("H", &out));
}
