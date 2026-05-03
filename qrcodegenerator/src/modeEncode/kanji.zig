const std = @import("std");
const c = @import("c");
const unicode = std.unicode;
const fmt = std.fmt;
const math = std.math;
const testing = std.testing;

const KanjiError = error{ InvalidKanjiChar, InvalidUtf8, BufferTooSmall, IconvError };

fn unicodeToSjis(utf8_char: []const u8) !?u16 {
    const cd = c.iconv_open("SHIFT_JIS", "UTF-8");
    if (cd == @as(c.iconv_t, @ptrFromInt(math.maxInt(usize)))) return KanjiError.IconvError;
    defer _ = c.iconv_close(cd);

    var in_buf: [4]u8 = undefined;
    @memcpy(in_buf[0..utf8_char.len], utf8_char);
    var in_ptr: [*c]u8 = &in_buf;
    var in_left: usize = utf8_char.len;

    var out_buf: [2]u8 = undefined;
    var out_ptr: [*c]u8 = &out_buf;
    var out_left: usize = 2;

    const result = c.iconv(cd, &in_ptr, &in_left, &out_ptr, &out_left);

    // iconv returns (size_t)-1 on error — character not convertible
    if (result == std.math.maxInt(usize)) return null;

    // bytes_written == 1 means single-byte SJIS (ASCII range) — not kanji
    // bytes_written == 2 means double-byte SJIS — a kanji character
    const bytes_written = 2 - out_left;
    if (bytes_written != 2) return null;

    return (@as(u16, out_buf[0]) << 8) | out_buf[1];
    // return sjis;
}

fn encodeChar(sjis: u16, out: []u8, start: usize) !void {
    if (start + 13 > out.len) return KanjiError.BufferTooSmall;

    const diff: u16 = if (sjis >= 0x8140 and sjis <= 0x9FFC)
        sjis - 0x8140
    else if (sjis >= 0xE040 and sjis <= 0xEBBF)
        sjis - 0xC140
    else
        return KanjiError.InvalidKanjiChar;

    const msb: u16 = (diff >> 8) & 0xFF;
    const lsb: u16 = diff & 0xFF;
    const value: u16 = (msb * 0xC0) + lsb;

    var buf: [13]u8 = undefined;
    const bin = try fmt.bufPrint(&buf, "{b}", .{value});

    const nbits: usize = 13;
    if (bin.len < nbits) {
        const pad = nbits - bin.len;
        @memset(out[start .. start + pad], '0');
        @memcpy(out[start + pad .. start + nbits], bin);
    } else {
        @memcpy(out[start .. start + nbits], bin);
    }
}

pub fn encode(inp: []const u8, out: []u8) ![]u8 {
    if (!unicode.utf8ValidateSlice(inp)) return KanjiError.InvalidUtf8;

    var outPos: usize = 0;
    var iter = unicode.Utf8Iterator{ .bytes = inp, .i = 0 };

    while (iter.nextCodepointSlice()) |cp| {
        if (outPos + 13 > out.len) return KanjiError.BufferTooSmall;

        const sjis: u16 = try unicodeToSjis(cp) orelse return KanjiError.InvalidKanjiChar;
        try encodeChar(sjis, out, outPos);

        outPos += 13;
    }

    return out[0..outPos];
}

test "荷 SJIS 0x89D7 -> 0011010010111" {
    var out: [13]u8 = undefined;
    try encodeChar(0x89D7, &out, 0);
    try testing.expectEqualStrings("0011010010111", out[0..13]);
}

test "茗 SJIS 0xE4AA -> 1101010101010" {
    var out: [13]u8 = undefined;
    try encodeChar(0xE4AA, &out, 0);
    try testing.expectEqualStrings("1101010101010", out[0..13]);
}

test "boundary 0x8140 -> 0000000000000" {
    var out: [13]u8 = undefined;
    try encodeChar(0x8140, &out, 0);
    try testing.expectEqualStrings("0000000000000", out[0..13]);
}

test "boundary 0x9FFC -> 1011100111100" {
    var out: [13]u8 = undefined;
    try encodeChar(0x9FFC, &out, 0);
    try testing.expectEqualStrings("1011100111100", out[0..13]);
}

test "boundary 0xE040 -> 1011101000000" {
    var out: [13]u8 = undefined;
    try encodeChar(0xE040, &out, 0);
    try testing.expectEqualStrings("1011101000000", out[0..13]);
}

test "boundary 0xEBBF -> 1111111111111" {
    var out: [13]u8 = undefined;
    try encodeChar(0xEBBF, &out, 0);
    try testing.expectEqualStrings("1111111111111", out[0..13]);
}

test "invalid SJIS range -> InvalidKanjiChar" {
    var out: [13]u8 = undefined;
    try testing.expectError(KanjiError.InvalidKanjiChar, encodeChar(0x8130, &out, 0));
    try testing.expectError(KanjiError.InvalidKanjiChar, encodeChar(0xA000, &out, 0));
    try testing.expectError(KanjiError.InvalidKanjiChar, encodeChar(0xEBC0, &out, 0));
}

test "buffer too small -> BufferTooSmall" {
    var out: [12]u8 = undefined;
    try testing.expectError(error.BufferTooSmall, encodeChar(0x89D7, &out, 1));
}

test "encode: 荷 (U+8377) -> 0011010010111" {
    var out: [13]u8 = undefined;
    const result = try encode("荷", &out);
    try testing.expectEqualStrings("0011010010111", result);
}

test "encode: 茗 (U+8317) -> 1101010101010" {
    var out: [13]u8 = undefined;
    const result = try encode("茗", &out);
    try testing.expectEqualStrings("1101010101010", result);
}

test "encode: 茗荷 -> 11010101010100011010010111" {
    var out: [26]u8 = undefined;
    const result = try encode("茗荷", &out);
    try testing.expectEqualStrings("11010101010100011010010111", result);
}

test "encode: 漢 (U+6F22) -> 0011100111111" {
    var out: [13]u8 = undefined;
    const result = try encode("漢", &out);
    try testing.expectEqualStrings("0011100111111", result);
}

test "encode: 字 (U+5B57) -> 0101000011010" {
    var out: [13]u8 = undefined;
    const result = try encode("字", &out);
    try testing.expectEqualStrings("0101000011010", result);
}

test "encode: 漢字 -> 00111001111110101000011010" {
    var out: [26]u8 = undefined;
    const result = try encode("漢字", &out);
    try testing.expectEqualStrings("00111001111110101000011010", result);
}

test "encode: invalid UTF-8 -> InvalidUtf8" {
    var out: [13]u8 = undefined;
    try testing.expectError(error.InvalidUtf8, encode(&[_]u8{ 0x89, 0xD7 }, &out));
}

test "encode: non-kanji UTF-8 -> InvalidKanjiChar" {
    var out: [13]u8 = undefined;
    try testing.expectError(error.InvalidKanjiChar, encode("A", &out));
}

test "encode: buffer too small -> BufferTooSmall" {
    var out: [12]u8 = undefined;
    try testing.expectError(error.BufferTooSmall, encode("茗荷", &out));
}
