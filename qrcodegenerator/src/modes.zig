const std = @import("std");
const unicode = std.unicode;
const testing = std.testing;

const ModeError = error{ EmptyInput, UnsupportedEncoding };

pub const Modes = enum {
    numeric,
    alphanumeric,
    byte,
    kanji,
};

pub fn getMode(inp: []const u8) !Modes {
    if (inp.len == 0) return ModeError.EmptyInput;

    const is_numeric = blk: {
        for (inp) |c| {
            if (c < '0' or c > '9') break :blk false;
        }
        break :blk true;
    };

    if (is_numeric) return .numeric;

    const alphanumeric_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
    const is_alphanumeric = blk: {
        for (inp) |c| {
            var found = false;
            for (alphanumeric_chars) |ch| {
                if (c == ch) {
                    found = true;
                    break;
                }
            }
            if (!found) break :blk false;
        }
        break :blk true;
    };

    if (is_alphanumeric) return .alphanumeric;

    const is_kanji = blk: {
        var found_kanji = false;
        var kiter = unicode.Utf8Iterator{ .bytes = inp, .i = 0 };

        while (kiter.nextCodepoint()) |cp| {
            if ((cp >= 0x3000 and cp <= 0x303F) or
                (cp >= 0x3040 and cp <= 0x30FF) or
                (cp >= 0x31F0 and cp <= 0x33FF) or
                (cp >= 0x3400 and cp <= 0x4DBF) or
                (cp >= 0x4E00 and cp <= 0x9FFF))
            {
                found_kanji = true;
            }
        }
        break :blk found_kanji;
    };

    if (is_kanji) return .kanji;

    const is_byte = blk: {
        var biter = unicode.Utf8Iterator{ .bytes = inp, .i = 0 };

        while (biter.nextCodepoint()) |cp| {
            if (cp > 0xFF) break :blk false;
        }
        break :blk true;
    };

    if (is_byte) return .byte;

    return ModeError.UnsupportedEncoding;
}

pub fn getModeIndicator(mode: Modes) []const u8 {
    return switch (mode) {
        .numeric => "0001",
        .alphanumeric => "0010",
        .byte => "0100",
        .kanji => "1000",
    };
}

test "numeric mode" {
    const num = "234234243234";
    const m = try getMode(num);

    try testing.expectEqual(m, Modes.numeric);
}

test "alphanumeric mode1" {
    const s = "HTTPS://CODINGCHALLENGES.FYI/CHALLENGES/CHALLENGE-QR-GENERATOR";
    const m = try getMode(s);

    try testing.expectEqual(m, Modes.alphanumeric);
}

test "alphanumeric mode2" {
    const s = "234234234 ";
    const m = try getMode(s);

    try testing.expectEqual(m, Modes.alphanumeric);
}

test "byte mode" {
    const s = "Lorenz Hänggi";
    const m = try getMode(s);

    try testing.expectEqual(m, Modes.byte);
}

test "kanji mode1" {
    const str = "漢字QRコード";
    const m = try getMode(str);

    try testing.expectEqual(m, Modes.kanji);
}

test "kanji mode2" {
    const str2 = "23423423424234漢";
    const m = try getMode(str2);

    try testing.expectEqual(m, Modes.kanji);
}

test "kanji mode3" {
    const str = "https://anywebsite.com?漢";
    const m = try getMode(str);

    try testing.expectEqual(m, Modes.kanji);
}

test "numeric mode indicator" {
    const num = "234234243234";
    const m = try getMode(num);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "0001");
}

test "alphanumeric mode indicator1" {
    const s = "HTTPS://CODINGCHALLENGES.FYI/CHALLENGES/CHALLENGE-QR-GENERATOR";
    const m = try getMode(s);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "0010");
}

test "alphanumeric mode indicator2" {
    const s = "234234234 ";
    const m = try getMode(s);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "0010");
}

test "byte mode indicator" {
    const s = "Lorenz Hänggi";
    const m = try getMode(s);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "0100");
}

test "kanji mode indicator1" {
    const str = "漢字QRコード";
    const m = try getMode(str);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "1000");
}

test "kanji mode indicator2" {
    const str = "23423423424234漢";
    const m = try getMode(str);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "1000");
}

test "kanji mode indicator3" {
    const str = "https://anywebsite.com?漢";
    const m = try getMode(str);

    const mi = getModeIndicator(m);

    try testing.expectEqual(mi, "1000");
}
