const std = @import("std");
const modes = @import("modes.zig");
const numeric_mode = @import("modeEncode/numerical.zig");
const alphanumeric_mode = @import("modeEncode/alphanumerical.zig");
const byte_mode = @import("modeEncode/byte.zig");
const kanji_mode = @import("modeEncode/kanji.zig");
const ec_block = @import("tables.zig").EcBlock;

const mem = std.mem;
const fmt = std.fmt;
const unicode = std.unicode;
const testing = std.testing;
const Modes = modes.Modes;

const VersionError = error{InvalidVersion};

const MAX_ENCODED_BITS = 56712; // version 40 l has 7089 chars so total bits = 7089 * 8(bits)
var encoded_buff: [MAX_ENCODED_BITS]u8 = undefined;

const MAX_TOTAL_BITS = 4 + 16 + MAX_ENCODED_BITS;
var total_bits: [MAX_TOTAL_BITS]u8 = undefined;

const capacity_table: [40][4][4]u16 = .{
    .{ .{ 41, 25, 17, 10 }, .{ 34, 20, 14, 8 }, .{ 27, 16, 11, 7 }, .{ 17, 10, 7, 4 } }, // v1
    .{ .{ 77, 47, 32, 20 }, .{ 63, 38, 26, 16 }, .{ 48, 29, 20, 12 }, .{ 34, 20, 14, 8 } }, // v2
    .{ .{ 127, 77, 53, 32 }, .{ 101, 61, 42, 26 }, .{ 77, 47, 32, 20 }, .{ 58, 35, 24, 15 } }, // v3
    .{ .{ 187, 114, 78, 48 }, .{ 149, 90, 62, 38 }, .{ 111, 67, 46, 28 }, .{ 82, 50, 34, 21 } }, // v4
    .{ .{ 255, 154, 106, 65 }, .{ 202, 122, 84, 52 }, .{ 144, 87, 60, 37 }, .{ 106, 64, 44, 27 } }, // v5
    .{ .{ 322, 195, 134, 82 }, .{ 255, 154, 106, 65 }, .{ 178, 108, 74, 45 }, .{ 139, 84, 58, 36 } }, // v6
    .{ .{ 370, 224, 154, 95 }, .{ 293, 178, 122, 75 }, .{ 207, 125, 86, 53 }, .{ 154, 93, 64, 39 } }, // v7
    .{ .{ 461, 279, 192, 118 }, .{ 365, 221, 152, 93 }, .{ 259, 157, 108, 66 }, .{ 202, 122, 84, 52 } }, // v8
    .{ .{ 552, 335, 230, 141 }, .{ 432, 262, 180, 111 }, .{ 312, 189, 130, 80 }, .{ 235, 143, 98, 60 } }, // v9
    .{ .{ 652, 395, 271, 167 }, .{ 513, 311, 213, 131 }, .{ 364, 221, 151, 93 }, .{ 288, 174, 119, 74 } }, // v10
    .{ .{ 772, 468, 321, 198 }, .{ 604, 366, 251, 155 }, .{ 427, 259, 177, 109 }, .{ 331, 200, 137, 85 } }, // v11
    .{ .{ 883, 535, 367, 226 }, .{ 691, 419, 287, 177 }, .{ 489, 296, 203, 125 }, .{ 374, 227, 155, 96 } }, // v12
    .{ .{ 1022, 619, 425, 262 }, .{ 796, 483, 331, 204 }, .{ 580, 352, 241, 149 }, .{ 427, 259, 177, 109 } }, // v13
    .{ .{ 1101, 667, 458, 282 }, .{ 871, 528, 362, 223 }, .{ 621, 376, 258, 159 }, .{ 468, 283, 194, 120 } }, // v14
    .{ .{ 1250, 758, 520, 320 }, .{ 991, 600, 412, 254 }, .{ 703, 426, 292, 180 }, .{ 530, 321, 220, 136 } }, // v15
    .{ .{ 1408, 854, 586, 361 }, .{ 1082, 656, 450, 277 }, .{ 775, 470, 322, 198 }, .{ 602, 365, 250, 154 } }, // v16
    .{ .{ 1548, 938, 644, 397 }, .{ 1212, 734, 504, 310 }, .{ 876, 531, 364, 224 }, .{ 674, 408, 280, 173 } }, // v17
    .{ .{ 1725, 1046, 718, 442 }, .{ 1346, 816, 560, 345 }, .{ 948, 574, 394, 243 }, .{ 746, 452, 310, 191 } }, // v18
    .{ .{ 1903, 1153, 792, 488 }, .{ 1500, 909, 624, 384 }, .{ 1063, 644, 442, 272 }, .{ 813, 493, 338, 208 } }, // v19
    .{ .{ 2061, 1249, 858, 528 }, .{ 1600, 970, 666, 410 }, .{ 1159, 702, 482, 297 }, .{ 919, 557, 382, 235 } }, // v20
    .{ .{ 2232, 1352, 929, 572 }, .{ 1708, 1035, 711, 438 }, .{ 1224, 742, 509, 314 }, .{ 969, 587, 403, 248 } }, // v21
    .{ .{ 2409, 1460, 1003, 618 }, .{ 1872, 1134, 779, 480 }, .{ 1358, 823, 565, 348 }, .{ 1056, 640, 439, 270 } }, // v22
    .{ .{ 2620, 1588, 1091, 672 }, .{ 2059, 1248, 857, 528 }, .{ 1468, 890, 611, 376 }, .{ 1108, 672, 461, 284 } }, // v23
    .{ .{ 2812, 1704, 1171, 721 }, .{ 2188, 1326, 911, 561 }, .{ 1588, 963, 661, 407 }, .{ 1228, 744, 511, 315 } }, // v24
    .{ .{ 3057, 1853, 1273, 784 }, .{ 2395, 1451, 997, 614 }, .{ 1718, 1041, 715, 440 }, .{ 1286, 779, 535, 330 } }, // v25
    .{ .{ 3283, 1990, 1367, 842 }, .{ 2544, 1542, 1059, 652 }, .{ 1804, 1094, 751, 462 }, .{ 1425, 864, 593, 365 } }, // v26
    .{ .{ 3517, 2132, 1465, 902 }, .{ 2701, 1637, 1125, 692 }, .{ 1933, 1172, 805, 496 }, .{ 1501, 910, 625, 385 } }, // v27
    .{ .{ 3669, 2223, 1528, 940 }, .{ 2857, 1732, 1190, 732 }, .{ 2085, 1263, 868, 534 }, .{ 1581, 958, 658, 405 } }, // v28
    .{ .{ 3909, 2369, 1628, 1002 }, .{ 3035, 1839, 1264, 778 }, .{ 2181, 1322, 908, 559 }, .{ 1677, 1016, 698, 430 } }, // v29
    .{ .{ 4158, 2520, 1732, 1066 }, .{ 3289, 1994, 1370, 843 }, .{ 2358, 1429, 982, 604 }, .{ 1782, 1080, 742, 457 } }, // v30
    .{ .{ 4417, 2677, 1840, 1132 }, .{ 3486, 2113, 1452, 894 }, .{ 2473, 1499, 1030, 634 }, .{ 1897, 1150, 790, 486 } }, // v31
    .{ .{ 4686, 2840, 1952, 1201 }, .{ 3693, 2238, 1538, 947 }, .{ 2670, 1618, 1112, 684 }, .{ 2022, 1226, 842, 518 } }, // v32
    .{ .{ 4965, 3009, 2068, 1273 }, .{ 3909, 2369, 1628, 1002 }, .{ 2805, 1700, 1168, 719 }, .{ 2157, 1307, 898, 553 } }, // v33
    .{ .{ 5253, 3183, 2188, 1347 }, .{ 4134, 2506, 1722, 1060 }, .{ 2949, 1787, 1228, 756 }, .{ 2301, 1394, 958, 590 } }, // v34
    .{ .{ 5529, 3351, 2303, 1417 }, .{ 4343, 2632, 1809, 1113 }, .{ 3081, 1867, 1283, 790 }, .{ 2361, 1431, 983, 605 } }, // v35
    .{ .{ 5836, 3537, 2431, 1496 }, .{ 4588, 2780, 1911, 1176 }, .{ 3244, 1966, 1351, 832 }, .{ 2524, 1530, 1051, 647 } }, // v36
    .{ .{ 6153, 3729, 2563, 1577 }, .{ 4775, 2894, 1989, 1224 }, .{ 3417, 2071, 1423, 876 }, .{ 2625, 1591, 1093, 673 } }, // v37
    .{ .{ 6479, 3927, 2699, 1661 }, .{ 5039, 3054, 2099, 1292 }, .{ 3599, 2181, 1499, 923 }, .{ 2735, 1658, 1139, 701 } }, // v38
    .{ .{ 6743, 4087, 2809, 1729 }, .{ 5313, 3220, 2213, 1362 }, .{ 3791, 2298, 1579, 972 }, .{ 2927, 1774, 1219, 750 } }, // v39
    .{ .{ 7089, 4296, 2953, 1817 }, .{ 5596, 3391, 2331, 1435 }, .{ 3993, 2420, 1663, 1024 }, .{ 3057, 1852, 1273, 784 } }, // v40
};

pub const ErrorcorrectionLevel = enum {
    L,
    M,
    Q,
    H,
};

fn getSize(version: usize) !usize {
    return switch (version) {
        1 => 21,
        2 => 25,
        3 => 29,
        4 => 33,
        5 => 37,
        6 => 41,
        7 => 45,
        8 => 49,
        9 => 53,
        10 => 57,
        11 => 61,
        12 => 65,
        13 => 69,
        14 => 73,
        15 => 77,
        16 => 81,
        17 => 85,
        18 => 89,
        19 => 93,
        20 => 97,
        21 => 101,
        22 => 105,
        23 => 109,
        24 => 113,
        25 => 117,
        26 => 121,
        27 => 125,
        28 => 129,
        29 => 133,
        30 => 137,
        31 => 141,
        32 => 145,
        33 => 149,
        34 => 153,
        35 => 157,
        36 => 161,
        37 => 165,
        38 => 169,
        39 => 173,
        40 => 177,
        else => VersionError.InvalidVersion,
    };
}

fn getCharCountIndicator(version: usize, m: Modes) !usize {
    return switch (version) {
        1...9 => switch (m) {
            .numeric => @as(usize, 10),
            .alphanumeric => @as(usize, 9),
            .byte => @as(usize, 8),
            .kanji => @as(usize, 8),
        },
        10...26 => switch (m) {
            .numeric => @as(usize, 12),
            .alphanumeric => @as(usize, 11),
            .byte => @as(usize, 16),
            .kanji => @as(usize, 10),
        },
        27...40 => switch (m) {
            .numeric => @as(usize, 14),
            .alphanumeric => @as(usize, 13),
            .byte => @as(usize, 16),
            .kanji => @as(usize, 12),
        },
        else => return VersionError.InvalidVersion,
    };
}

fn getVersion(inp_len: usize, ecl: ErrorcorrectionLevel, mode: Modes) !usize {
    for (0..40) |i| {
        const char_capcity = capacity_table[i][@intFromEnum(ecl)][@intFromEnum(mode)];
        if (inp_len <= char_capcity) {
            return i + 1;
        }
    }

    return VersionError.InvalidVersion;
}

fn calcCharCountIndicator(inp: []const u8, version: usize, m: Modes, out: []u8) ![]u8 {
    const nbits = try getCharCountIndicator(version, m);

    var buff: [20]u8 = undefined;
    const inp_bin = try fmt.bufPrint(&buff, "{b}", .{try unicode.utf8CountCodepoints(inp)});

    if (out.len < nbits) return error.BuffTooSmall;

    if (inp_bin.len < nbits) {
        const pad = nbits - inp_bin.len;
        @memset(out[0..pad], '0');
        @memcpy(out[pad..nbits], inp_bin);
    } else {
        @memcpy(out[0..nbits], inp_bin);
    }

    return out[0..nbits];
}

fn modeEncode(mode: Modes, inp: []const u8) ![]u8 {
    return switch (mode) {
        .numeric => try numeric_mode.encode(inp, &encoded_buff),
        .alphanumeric => try alphanumeric_mode.encode(inp, &encoded_buff),
        .byte => try byte_mode.encode(inp, &encoded_buff),
        .kanji => try kanji_mode.encode(inp, &encoded_buff),
    };
}

pub fn totalBits(inp: []const u8, ecl: ErrorcorrectionLevel) ![]u8 {
    var cci_buff: [50]u8 = undefined;

    const mode = try modes.getMode(inp);
    const char_count = if (mode == .kanji) try unicode.utf8CountCodepoints(inp) else inp.len;
    const ver = try getVersion(char_count, ecl, mode);

    const mi = modes.getModeIndicator(mode);
    const cci = try calcCharCountIndicator(inp, ver, mode, &cci_buff);
    const mode_encode = try modeEncode(mode, inp);

    var pos: usize = 0;
    @memcpy(total_bits[pos .. pos + mi.len], mi);
    pos += mi.len;
    @memcpy(total_bits[pos .. pos + cci.len], cci);
    pos += cci.len;
    @memcpy(total_bits[pos .. pos + mode_encode.len], mode_encode);
    pos += mode_encode.len;

    const tot_data_codewords = ec_block.getTotalDataCodewords(ver, ecl) * 8;

    const term_len = @min(4, tot_data_codewords - pos);
    @memset(total_bits[pos .. pos + term_len], '0');
    pos += term_len;

    const rem = pos % 8;
    if (rem != 0) {
        const pad = 8 - rem;
        @memset(total_bits[pos .. pos + pad], '0');
        pos += pad;
    }

    const pad_bytes = [_][]const u8{ "11101100", "00010001" };
    var pad_idx: usize = 0;
    while (pos < tot_data_codewords) {
        @memcpy(total_bits[pos .. pos + 8], pad_bytes[pad_idx % 2]);
        pos += 8;
        pad_idx += 1;
    }

    return total_bits[0..pos];
}

// ── Numeric mode ──────────────────────────────────────────────────────────────

test "totalBits numeric L: 8675309 -> v1 152 bits" {
    const result = try totalBits("8675309", .L);
    try testing.expectEqual(@as(usize, 152), result.len);
    try testing.expectEqualStrings(
        "00010000000111110110001110000100101001000000000011101100000100011110110000010001111011000001000111101100000100011110110000010001111011000001000111101100",
        result,
    );
}

test "totalBits numeric H: 8675309 -> v1 72 bits" {
    const result = try totalBits("8675309", .H);
    try testing.expectEqual(@as(usize, 72), result.len);
    try testing.expectEqualStrings(
        "000100000001111101100011100001001010010000000000111011000001000111101100",
        result,
    );
}

test "totalBits numeric Q: 8675309 -> v1 104 bits" {
    const result = try totalBits("8675309", .Q);
    try testing.expectEqual(@as(usize, 104), result.len);
    try testing.expectEqualStrings("0001", result[0..4]);
}

test "totalBits numeric M: 8675309 -> v1 128 bits" {
    const result = try totalBits("8675309", .M);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings("0001", result[0..4]);
}

// ── Alphanumeric mode ─────────────────────────────────────────────────────────

test "totalBits alphanumeric Q: HELLO WORLD -> v1 104 bits" {
    const result = try totalBits("HELLO WORLD", .Q);
    try testing.expectEqual(@as(usize, 104), result.len);
    try testing.expectEqualStrings(
        "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100",
        result,
    );
}

test "totalBits alphanumeric M: HELLO WORLD -> v1 128 bits" {
    const result = try totalBits("HELLO WORLD", .M);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings(
        "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100000100011110110000010001",
        result,
    );
}

test "totalBits alphanumeric L: HELLO WORLD -> v1 152 bits" {
    const result = try totalBits("HELLO WORLD", .L);
    try testing.expectEqual(@as(usize, 152), result.len);
    try testing.expectEqualStrings(
        "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100000100011110110000010001111011000001000111101100",
        result,
    );
}

test "totalBits alphanumeric H: HELLO WORLD -> v2 128 bits" {
    // 11 chars exceeds v1 H cap (10) -> lands in v2, tdc=16
    const result = try totalBits("HELLO WORLD", .H);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings(
        "00100000010110110000101101111000110100010111001011011100010011010100001101000000111011000001000111101100000100011110110000010001",
        result,
    );
}

// ── Byte mode ─────────────────────────────────────────────────────────────────

test "totalBits byte L: Hello, world! -> v1 152 bits" {
    const result = try totalBits("Hello, world!", .L);
    try testing.expectEqual(@as(usize, 152), result.len);
    try testing.expectEqualStrings(
        "01000000110101001000011001010110110001101100011011110010110000100000011101110110111101110010011011000110010000100001000011101100000100011110110000010001",
        result,
    );
}

test "totalBits byte M: Hello, world! -> v1 128 bits" {
    const result = try totalBits("Hello, world!", .M);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings(
        "01000000110101001000011001010110110001101100011011110010110000100000011101110110111101110010011011000110010000100001000011101100",
        result,
    );
}

test "totalBits byte H: Hello, world! -> v2 128 bits" {
    // 13 chars exceeds v1 H cap (7) -> lands in v2, tdc=16
    const result = try totalBits("Hello, world!", .H);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings(
        "01000000110101001000011001010110110001101100011011110010110000100000011101110110111101110010011011000110010000100001000011101100",
        result,
    );
}

test "totalBits byte Q: Hello, world! -> v2 176 bits" {
    // 13 chars exceeds v1 Q cap (11) -> lands in v2, tdc=22
    const result = try totalBits("Hello, world!", .Q);
    try testing.expectEqual(@as(usize, 176), result.len);
    try testing.expectEqualStrings(
        "01000000110101001000011001010110110001101100011011110010110000100000011101110110111101110010011011000110010000100001000011101100000100011110110000010001111011000001000111101100",
        result,
    );
}

// ── Kanji mode ────────────────────────────────────────────────────────────────

test "totalBits kanji L: 茗荷 -> v1 152 bits" {
    const result = try totalBits("茗荷", .L);
    try testing.expectEqual(@as(usize, 152), result.len);
    try testing.expectEqualStrings("1000", result[0..4]);
    try testing.expectEqualStrings("00000010", result[4..12]); // cci: 2 chars
    try testing.expectEqualStrings("1101010101010", result[12..25]); // 茗
    try testing.expectEqualStrings("0011010010111", result[25..38]); // 荷
}

test "totalBits kanji M: 茗荷 -> v1 128 bits" {
    const result = try totalBits("茗荷", .M);
    try testing.expectEqual(@as(usize, 128), result.len);
    try testing.expectEqualStrings("1000", result[0..4]);
}

test "totalBits kanji Q: 茗荷 -> v1 104 bits" {
    const result = try totalBits("茗荷", .Q);
    try testing.expectEqual(@as(usize, 104), result.len);
    try testing.expectEqualStrings("1000", result[0..4]);
}

test "totalBits kanji H: 茗荷 -> v1 72 bits" {
    const result = try totalBits("茗荷", .H);
    try testing.expectEqual(@as(usize, 72), result.len);
    try testing.expectEqualStrings(
        "100000000010110101010101000110100101110000000000111011000001000111101100",
        result,
    );
}

// ── Version boundary: cci width change at v10 ─────────────────────────────────

test "totalBits numeric L v10: cci is 12 bits" {
    // v9 L numeric cap=552, 560 digits -> v10 (tdc=274, req=2192 bits)
    const inp = "9876543210" ** 56;
    const result = try totalBits(inp, .L);
    try testing.expectEqualStrings("0001", result[0..4]);
    try testing.expectEqualStrings("001000110000", result[4..16]); // 560 in 12 bits
    try testing.expectEqual(@as(usize, 274 * 8), result.len);
}

test "totalBits alphanumeric M v10: cci is 11 bits" {
    // v9 M alpha cap=262, 263 chars -> v10 (tdc=216, req=1728 bits)
    const inp = "A" ** 263;
    const result = try totalBits(inp, .M);
    try testing.expectEqualStrings("0010", result[0..4]);
    try testing.expectEqualStrings("00100000111", result[4..15]); // 263 in 11 bits
    try testing.expectEqual(@as(usize, 216 * 8), result.len);
}

test "totalBits byte H v10: cci is 16 bits" {
    // v9 H byte cap=98, 99 bytes -> v10 (tdc=122, req=976 bits)
    const inp = "a" ** 99;
    const result = try totalBits(inp, .H);
    try testing.expectEqualStrings("0100", result[0..4]);
    try testing.expectEqualStrings("0000000001100011", result[4..20]); // 99 in 16 bits
    try testing.expectEqual(@as(usize, 122 * 8), result.len);
}
