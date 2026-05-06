const ECL = @import("encode.zig").ErrorcorrectionLevel;

pub const EcBlock = struct {
    total_data_codewords: u16,
    ec_per_block: u8,
    g1_blocks: u8,
    g1_data_per_block: u8,
    g2_blocks: u8,
    g2_data_per_block: u8,

    pub fn getTotalDataCodewords(v: usize, ecl: ECL) u16 {
        return ec_table[v - 1][@intFromEnum(ecl)].total_data_codewords;
    }

    pub fn getBloc(v: usize, ecl: ECL) EcBlock {
        return ec_table[v - 1][@intFromEnum(ecl)];
    }
};

// Index: [version - 1][ec_level] where ec_level L=0 M=1 Q=2 H=3
const ec_table: [40][4]EcBlock = .{
    // v1
    .{
        .{ .total_data_codewords = 19, .ec_per_block = 7, .g1_blocks = 1, .g1_data_per_block = 19, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 16, .ec_per_block = 10, .g1_blocks = 1, .g1_data_per_block = 16, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 13, .ec_per_block = 13, .g1_blocks = 1, .g1_data_per_block = 13, .g2_blocks = 0, .g2_data_per_block = 0 }, // Q
        .{ .total_data_codewords = 9, .ec_per_block = 17, .g1_blocks = 1, .g1_data_per_block = 9, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v2
    .{
        .{ .total_data_codewords = 34, .ec_per_block = 10, .g1_blocks = 1, .g1_data_per_block = 34, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 28, .ec_per_block = 16, .g1_blocks = 1, .g1_data_per_block = 28, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 22, .ec_per_block = 22, .g1_blocks = 1, .g1_data_per_block = 22, .g2_blocks = 0, .g2_data_per_block = 0 }, // Q
        .{ .total_data_codewords = 16, .ec_per_block = 28, .g1_blocks = 1, .g1_data_per_block = 16, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v3
    .{
        .{ .total_data_codewords = 55, .ec_per_block = 15, .g1_blocks = 1, .g1_data_per_block = 55, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 44, .ec_per_block = 26, .g1_blocks = 1, .g1_data_per_block = 44, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 34, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 17, .g2_blocks = 0, .g2_data_per_block = 0 }, // Q
        .{ .total_data_codewords = 26, .ec_per_block = 22, .g1_blocks = 2, .g1_data_per_block = 13, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v4
    .{
        .{ .total_data_codewords = 80, .ec_per_block = 20, .g1_blocks = 1, .g1_data_per_block = 80, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 64, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 32, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 48, .ec_per_block = 26, .g1_blocks = 2, .g1_data_per_block = 24, .g2_blocks = 0, .g2_data_per_block = 0 }, // Q
        .{ .total_data_codewords = 36, .ec_per_block = 16, .g1_blocks = 4, .g1_data_per_block = 9, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v5
    .{
        .{ .total_data_codewords = 108, .ec_per_block = 26, .g1_blocks = 1, .g1_data_per_block = 108, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 86, .ec_per_block = 24, .g1_blocks = 2, .g1_data_per_block = 43, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 62, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 15, .g2_blocks = 2, .g2_data_per_block = 16 }, // Q
        .{ .total_data_codewords = 46, .ec_per_block = 22, .g1_blocks = 2, .g1_data_per_block = 11, .g2_blocks = 2, .g2_data_per_block = 12 }, // H
    },
    // v6
    .{
        .{ .total_data_codewords = 136, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 68, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 108, .ec_per_block = 16, .g1_blocks = 4, .g1_data_per_block = 27, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 76, .ec_per_block = 24, .g1_blocks = 4, .g1_data_per_block = 19, .g2_blocks = 0, .g2_data_per_block = 0 }, // Q
        .{ .total_data_codewords = 60, .ec_per_block = 28, .g1_blocks = 4, .g1_data_per_block = 15, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v7
    .{
        .{ .total_data_codewords = 156, .ec_per_block = 20, .g1_blocks = 2, .g1_data_per_block = 78, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 124, .ec_per_block = 18, .g1_blocks = 4, .g1_data_per_block = 31, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 88, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 14, .g2_blocks = 4, .g2_data_per_block = 15 }, // Q
        .{ .total_data_codewords = 66, .ec_per_block = 26, .g1_blocks = 4, .g1_data_per_block = 13, .g2_blocks = 1, .g2_data_per_block = 14 }, // H
    },
    // v8
    .{
        .{ .total_data_codewords = 194, .ec_per_block = 24, .g1_blocks = 2, .g1_data_per_block = 97, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 154, .ec_per_block = 22, .g1_blocks = 2, .g1_data_per_block = 38, .g2_blocks = 2, .g2_data_per_block = 39 }, // M
        .{ .total_data_codewords = 110, .ec_per_block = 22, .g1_blocks = 4, .g1_data_per_block = 18, .g2_blocks = 2, .g2_data_per_block = 19 }, // Q
        .{ .total_data_codewords = 86, .ec_per_block = 26, .g1_blocks = 4, .g1_data_per_block = 14, .g2_blocks = 2, .g2_data_per_block = 15 }, // H
    },
    // v9
    .{
        .{ .total_data_codewords = 232, .ec_per_block = 30, .g1_blocks = 2, .g1_data_per_block = 116, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 182, .ec_per_block = 22, .g1_blocks = 3, .g1_data_per_block = 36, .g2_blocks = 2, .g2_data_per_block = 37 }, // M
        .{ .total_data_codewords = 132, .ec_per_block = 20, .g1_blocks = 4, .g1_data_per_block = 16, .g2_blocks = 4, .g2_data_per_block = 17 }, // Q
        .{ .total_data_codewords = 100, .ec_per_block = 24, .g1_blocks = 4, .g1_data_per_block = 12, .g2_blocks = 4, .g2_data_per_block = 13 }, // H
    },
    // v10
    .{
        .{ .total_data_codewords = 274, .ec_per_block = 18, .g1_blocks = 2, .g1_data_per_block = 68, .g2_blocks = 2, .g2_data_per_block = 69 }, // L
        .{ .total_data_codewords = 216, .ec_per_block = 26, .g1_blocks = 4, .g1_data_per_block = 43, .g2_blocks = 1, .g2_data_per_block = 44 }, // M
        .{ .total_data_codewords = 154, .ec_per_block = 24, .g1_blocks = 6, .g1_data_per_block = 19, .g2_blocks = 2, .g2_data_per_block = 20 }, // Q
        .{ .total_data_codewords = 122, .ec_per_block = 28, .g1_blocks = 6, .g1_data_per_block = 15, .g2_blocks = 2, .g2_data_per_block = 16 }, // H
    },
    // v11
    .{
        .{ .total_data_codewords = 324, .ec_per_block = 20, .g1_blocks = 4, .g1_data_per_block = 81, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 254, .ec_per_block = 30, .g1_blocks = 1, .g1_data_per_block = 50, .g2_blocks = 4, .g2_data_per_block = 51 }, // M
        .{ .total_data_codewords = 180, .ec_per_block = 28, .g1_blocks = 4, .g1_data_per_block = 22, .g2_blocks = 4, .g2_data_per_block = 23 }, // Q
        .{ .total_data_codewords = 140, .ec_per_block = 24, .g1_blocks = 3, .g1_data_per_block = 12, .g2_blocks = 8, .g2_data_per_block = 13 }, // H
    },
    // v12
    .{
        .{ .total_data_codewords = 370, .ec_per_block = 24, .g1_blocks = 2, .g1_data_per_block = 92, .g2_blocks = 2, .g2_data_per_block = 93 }, // L
        .{ .total_data_codewords = 290, .ec_per_block = 22, .g1_blocks = 6, .g1_data_per_block = 36, .g2_blocks = 2, .g2_data_per_block = 37 }, // M
        .{ .total_data_codewords = 206, .ec_per_block = 26, .g1_blocks = 4, .g1_data_per_block = 20, .g2_blocks = 6, .g2_data_per_block = 21 }, // Q
        .{ .total_data_codewords = 158, .ec_per_block = 28, .g1_blocks = 7, .g1_data_per_block = 14, .g2_blocks = 4, .g2_data_per_block = 15 }, // H
    },
    // v13
    .{
        .{ .total_data_codewords = 428, .ec_per_block = 26, .g1_blocks = 4, .g1_data_per_block = 107, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 334, .ec_per_block = 22, .g1_blocks = 8, .g1_data_per_block = 37, .g2_blocks = 1, .g2_data_per_block = 38 }, // M
        .{ .total_data_codewords = 244, .ec_per_block = 24, .g1_blocks = 8, .g1_data_per_block = 20, .g2_blocks = 4, .g2_data_per_block = 21 }, // Q
        .{ .total_data_codewords = 180, .ec_per_block = 22, .g1_blocks = 12, .g1_data_per_block = 11, .g2_blocks = 4, .g2_data_per_block = 12 }, // H
    },
    // v14
    .{
        .{ .total_data_codewords = 461, .ec_per_block = 30, .g1_blocks = 3, .g1_data_per_block = 115, .g2_blocks = 1, .g2_data_per_block = 116 }, // L
        .{ .total_data_codewords = 365, .ec_per_block = 24, .g1_blocks = 4, .g1_data_per_block = 40, .g2_blocks = 5, .g2_data_per_block = 41 }, // M
        .{ .total_data_codewords = 261, .ec_per_block = 20, .g1_blocks = 11, .g1_data_per_block = 16, .g2_blocks = 5, .g2_data_per_block = 17 }, // Q
        .{ .total_data_codewords = 197, .ec_per_block = 24, .g1_blocks = 11, .g1_data_per_block = 12, .g2_blocks = 5, .g2_data_per_block = 13 }, // H
    },
    // v15
    .{
        .{ .total_data_codewords = 523, .ec_per_block = 22, .g1_blocks = 5, .g1_data_per_block = 87, .g2_blocks = 1, .g2_data_per_block = 88 }, // L
        .{ .total_data_codewords = 415, .ec_per_block = 24, .g1_blocks = 5, .g1_data_per_block = 41, .g2_blocks = 5, .g2_data_per_block = 42 }, // M
        .{ .total_data_codewords = 295, .ec_per_block = 30, .g1_blocks = 5, .g1_data_per_block = 24, .g2_blocks = 7, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 223, .ec_per_block = 24, .g1_blocks = 11, .g1_data_per_block = 12, .g2_blocks = 7, .g2_data_per_block = 13 }, // H
    },
    // v16
    .{
        .{ .total_data_codewords = 589, .ec_per_block = 24, .g1_blocks = 5, .g1_data_per_block = 98, .g2_blocks = 1, .g2_data_per_block = 99 }, // L
        .{ .total_data_codewords = 453, .ec_per_block = 28, .g1_blocks = 7, .g1_data_per_block = 45, .g2_blocks = 3, .g2_data_per_block = 46 }, // M
        .{ .total_data_codewords = 325, .ec_per_block = 24, .g1_blocks = 15, .g1_data_per_block = 19, .g2_blocks = 2, .g2_data_per_block = 20 }, // Q
        .{ .total_data_codewords = 253, .ec_per_block = 30, .g1_blocks = 3, .g1_data_per_block = 15, .g2_blocks = 13, .g2_data_per_block = 16 }, // H
    },
    // v17
    .{
        .{ .total_data_codewords = 647, .ec_per_block = 28, .g1_blocks = 1, .g1_data_per_block = 107, .g2_blocks = 5, .g2_data_per_block = 108 }, // L
        .{ .total_data_codewords = 507, .ec_per_block = 28, .g1_blocks = 10, .g1_data_per_block = 46, .g2_blocks = 1, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 367, .ec_per_block = 28, .g1_blocks = 1, .g1_data_per_block = 22, .g2_blocks = 15, .g2_data_per_block = 23 }, // Q
        .{ .total_data_codewords = 283, .ec_per_block = 28, .g1_blocks = 2, .g1_data_per_block = 14, .g2_blocks = 17, .g2_data_per_block = 15 }, // H
    },
    // v18
    .{
        .{ .total_data_codewords = 721, .ec_per_block = 30, .g1_blocks = 5, .g1_data_per_block = 120, .g2_blocks = 1, .g2_data_per_block = 121 }, // L
        .{ .total_data_codewords = 563, .ec_per_block = 26, .g1_blocks = 9, .g1_data_per_block = 43, .g2_blocks = 4, .g2_data_per_block = 44 }, // M
        .{ .total_data_codewords = 397, .ec_per_block = 28, .g1_blocks = 17, .g1_data_per_block = 22, .g2_blocks = 1, .g2_data_per_block = 23 }, // Q
        .{ .total_data_codewords = 313, .ec_per_block = 28, .g1_blocks = 2, .g1_data_per_block = 14, .g2_blocks = 19, .g2_data_per_block = 15 }, // H
    },
    // v19
    .{
        .{ .total_data_codewords = 795, .ec_per_block = 28, .g1_blocks = 3, .g1_data_per_block = 113, .g2_blocks = 4, .g2_data_per_block = 114 }, // L
        .{ .total_data_codewords = 627, .ec_per_block = 26, .g1_blocks = 3, .g1_data_per_block = 44, .g2_blocks = 11, .g2_data_per_block = 45 }, // M
        .{ .total_data_codewords = 445, .ec_per_block = 26, .g1_blocks = 17, .g1_data_per_block = 21, .g2_blocks = 4, .g2_data_per_block = 22 }, // Q
        .{ .total_data_codewords = 341, .ec_per_block = 26, .g1_blocks = 9, .g1_data_per_block = 13, .g2_blocks = 16, .g2_data_per_block = 14 }, // H
    },
    // v20
    .{
        .{ .total_data_codewords = 861, .ec_per_block = 28, .g1_blocks = 3, .g1_data_per_block = 107, .g2_blocks = 5, .g2_data_per_block = 108 }, // L
        .{ .total_data_codewords = 669, .ec_per_block = 26, .g1_blocks = 3, .g1_data_per_block = 41, .g2_blocks = 13, .g2_data_per_block = 42 }, // M
        .{ .total_data_codewords = 485, .ec_per_block = 30, .g1_blocks = 15, .g1_data_per_block = 24, .g2_blocks = 5, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 385, .ec_per_block = 28, .g1_blocks = 15, .g1_data_per_block = 15, .g2_blocks = 10, .g2_data_per_block = 16 }, // H
    },
    // v21
    .{
        .{ .total_data_codewords = 932, .ec_per_block = 28, .g1_blocks = 4, .g1_data_per_block = 116, .g2_blocks = 4, .g2_data_per_block = 117 }, // L
        .{ .total_data_codewords = 714, .ec_per_block = 26, .g1_blocks = 17, .g1_data_per_block = 42, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 512, .ec_per_block = 28, .g1_blocks = 17, .g1_data_per_block = 22, .g2_blocks = 6, .g2_data_per_block = 23 }, // Q
        .{ .total_data_codewords = 406, .ec_per_block = 30, .g1_blocks = 19, .g1_data_per_block = 16, .g2_blocks = 6, .g2_data_per_block = 17 }, // H
    },
    // v22
    .{
        .{ .total_data_codewords = 1006, .ec_per_block = 28, .g1_blocks = 2, .g1_data_per_block = 111, .g2_blocks = 7, .g2_data_per_block = 112 }, // L
        .{ .total_data_codewords = 782, .ec_per_block = 28, .g1_blocks = 17, .g1_data_per_block = 46, .g2_blocks = 0, .g2_data_per_block = 0 }, // M
        .{ .total_data_codewords = 568, .ec_per_block = 30, .g1_blocks = 7, .g1_data_per_block = 24, .g2_blocks = 16, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 442, .ec_per_block = 24, .g1_blocks = 34, .g1_data_per_block = 13, .g2_blocks = 0, .g2_data_per_block = 0 }, // H
    },
    // v23
    .{
        .{ .total_data_codewords = 1094, .ec_per_block = 30, .g1_blocks = 4, .g1_data_per_block = 121, .g2_blocks = 5, .g2_data_per_block = 122 }, // L
        .{ .total_data_codewords = 860, .ec_per_block = 28, .g1_blocks = 4, .g1_data_per_block = 47, .g2_blocks = 14, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 614, .ec_per_block = 30, .g1_blocks = 11, .g1_data_per_block = 24, .g2_blocks = 14, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 464, .ec_per_block = 30, .g1_blocks = 16, .g1_data_per_block = 15, .g2_blocks = 14, .g2_data_per_block = 16 }, // H
    },
    // v24
    .{
        .{ .total_data_codewords = 1174, .ec_per_block = 30, .g1_blocks = 6, .g1_data_per_block = 117, .g2_blocks = 4, .g2_data_per_block = 118 }, // L
        .{ .total_data_codewords = 914, .ec_per_block = 28, .g1_blocks = 6, .g1_data_per_block = 45, .g2_blocks = 14, .g2_data_per_block = 46 }, // M
        .{ .total_data_codewords = 664, .ec_per_block = 30, .g1_blocks = 11, .g1_data_per_block = 24, .g2_blocks = 16, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 514, .ec_per_block = 30, .g1_blocks = 30, .g1_data_per_block = 16, .g2_blocks = 2, .g2_data_per_block = 17 }, // H
    },
    // v25
    .{
        .{ .total_data_codewords = 1276, .ec_per_block = 26, .g1_blocks = 8, .g1_data_per_block = 106, .g2_blocks = 4, .g2_data_per_block = 107 }, // L
        .{ .total_data_codewords = 1000, .ec_per_block = 28, .g1_blocks = 8, .g1_data_per_block = 47, .g2_blocks = 13, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 718, .ec_per_block = 30, .g1_blocks = 7, .g1_data_per_block = 24, .g2_blocks = 22, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 538, .ec_per_block = 30, .g1_blocks = 22, .g1_data_per_block = 15, .g2_blocks = 13, .g2_data_per_block = 16 }, // H
    },
    // v26
    .{
        .{ .total_data_codewords = 1370, .ec_per_block = 28, .g1_blocks = 10, .g1_data_per_block = 114, .g2_blocks = 2, .g2_data_per_block = 115 }, // L
        .{ .total_data_codewords = 1062, .ec_per_block = 28, .g1_blocks = 19, .g1_data_per_block = 46, .g2_blocks = 4, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 754, .ec_per_block = 28, .g1_blocks = 28, .g1_data_per_block = 22, .g2_blocks = 6, .g2_data_per_block = 23 }, // Q
        .{ .total_data_codewords = 596, .ec_per_block = 30, .g1_blocks = 33, .g1_data_per_block = 16, .g2_blocks = 4, .g2_data_per_block = 17 }, // H
    },
    // v27
    .{
        .{ .total_data_codewords = 1468, .ec_per_block = 30, .g1_blocks = 8, .g1_data_per_block = 122, .g2_blocks = 4, .g2_data_per_block = 123 }, // L
        .{ .total_data_codewords = 1128, .ec_per_block = 28, .g1_blocks = 22, .g1_data_per_block = 45, .g2_blocks = 3, .g2_data_per_block = 46 }, // M
        .{ .total_data_codewords = 808, .ec_per_block = 30, .g1_blocks = 8, .g1_data_per_block = 23, .g2_blocks = 26, .g2_data_per_block = 24 }, // Q
        .{ .total_data_codewords = 628, .ec_per_block = 30, .g1_blocks = 12, .g1_data_per_block = 15, .g2_blocks = 28, .g2_data_per_block = 16 }, // H
    },
    // v28
    .{
        .{ .total_data_codewords = 1531, .ec_per_block = 30, .g1_blocks = 3, .g1_data_per_block = 117, .g2_blocks = 10, .g2_data_per_block = 118 }, // L
        .{ .total_data_codewords = 1193, .ec_per_block = 28, .g1_blocks = 3, .g1_data_per_block = 45, .g2_blocks = 23, .g2_data_per_block = 46 }, // M
        .{ .total_data_codewords = 871, .ec_per_block = 30, .g1_blocks = 4, .g1_data_per_block = 24, .g2_blocks = 31, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 661, .ec_per_block = 30, .g1_blocks = 11, .g1_data_per_block = 15, .g2_blocks = 31, .g2_data_per_block = 16 }, // H
    },
    // v29
    .{
        .{ .total_data_codewords = 1631, .ec_per_block = 30, .g1_blocks = 7, .g1_data_per_block = 116, .g2_blocks = 7, .g2_data_per_block = 117 }, // L
        .{ .total_data_codewords = 1267, .ec_per_block = 28, .g1_blocks = 21, .g1_data_per_block = 45, .g2_blocks = 7, .g2_data_per_block = 46 }, // M
        .{ .total_data_codewords = 911, .ec_per_block = 30, .g1_blocks = 1, .g1_data_per_block = 23, .g2_blocks = 37, .g2_data_per_block = 24 }, // Q
        .{ .total_data_codewords = 701, .ec_per_block = 30, .g1_blocks = 19, .g1_data_per_block = 15, .g2_blocks = 26, .g2_data_per_block = 16 }, // H
    },
    // v30
    .{
        .{ .total_data_codewords = 1735, .ec_per_block = 30, .g1_blocks = 5, .g1_data_per_block = 115, .g2_blocks = 10, .g2_data_per_block = 116 }, // L
        .{ .total_data_codewords = 1373, .ec_per_block = 28, .g1_blocks = 19, .g1_data_per_block = 47, .g2_blocks = 10, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 985, .ec_per_block = 30, .g1_blocks = 15, .g1_data_per_block = 24, .g2_blocks = 25, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 745, .ec_per_block = 30, .g1_blocks = 23, .g1_data_per_block = 15, .g2_blocks = 25, .g2_data_per_block = 16 }, // H
    },
    // v31
    .{
        .{ .total_data_codewords = 1843, .ec_per_block = 30, .g1_blocks = 13, .g1_data_per_block = 115, .g2_blocks = 3, .g2_data_per_block = 116 }, // L
        .{ .total_data_codewords = 1455, .ec_per_block = 28, .g1_blocks = 2, .g1_data_per_block = 46, .g2_blocks = 29, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1033, .ec_per_block = 30, .g1_blocks = 42, .g1_data_per_block = 24, .g2_blocks = 1, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 793, .ec_per_block = 30, .g1_blocks = 23, .g1_data_per_block = 15, .g2_blocks = 28, .g2_data_per_block = 16 }, // H
    },
    // v32
    .{
        .{ .total_data_codewords = 1955, .ec_per_block = 30, .g1_blocks = 17, .g1_data_per_block = 115, .g2_blocks = 0, .g2_data_per_block = 0 }, // L
        .{ .total_data_codewords = 1541, .ec_per_block = 28, .g1_blocks = 10, .g1_data_per_block = 46, .g2_blocks = 23, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1115, .ec_per_block = 30, .g1_blocks = 10, .g1_data_per_block = 24, .g2_blocks = 35, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 845, .ec_per_block = 30, .g1_blocks = 19, .g1_data_per_block = 15, .g2_blocks = 35, .g2_data_per_block = 16 }, // H
    },
    // v33
    .{
        .{ .total_data_codewords = 2071, .ec_per_block = 30, .g1_blocks = 17, .g1_data_per_block = 115, .g2_blocks = 1, .g2_data_per_block = 116 }, // L
        .{ .total_data_codewords = 1631, .ec_per_block = 28, .g1_blocks = 14, .g1_data_per_block = 46, .g2_blocks = 21, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1171, .ec_per_block = 30, .g1_blocks = 29, .g1_data_per_block = 24, .g2_blocks = 19, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 901, .ec_per_block = 30, .g1_blocks = 11, .g1_data_per_block = 15, .g2_blocks = 46, .g2_data_per_block = 16 }, // H
    },
    // v34
    .{
        .{ .total_data_codewords = 2191, .ec_per_block = 30, .g1_blocks = 13, .g1_data_per_block = 115, .g2_blocks = 6, .g2_data_per_block = 116 }, // L
        .{ .total_data_codewords = 1725, .ec_per_block = 28, .g1_blocks = 14, .g1_data_per_block = 46, .g2_blocks = 23, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1231, .ec_per_block = 30, .g1_blocks = 44, .g1_data_per_block = 24, .g2_blocks = 7, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 961, .ec_per_block = 30, .g1_blocks = 59, .g1_data_per_block = 16, .g2_blocks = 1, .g2_data_per_block = 17 }, // H
    },
    // v35
    .{
        .{ .total_data_codewords = 2306, .ec_per_block = 30, .g1_blocks = 12, .g1_data_per_block = 121, .g2_blocks = 7, .g2_data_per_block = 122 }, // L
        .{ .total_data_codewords = 1812, .ec_per_block = 28, .g1_blocks = 12, .g1_data_per_block = 47, .g2_blocks = 26, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 1286, .ec_per_block = 30, .g1_blocks = 39, .g1_data_per_block = 24, .g2_blocks = 14, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 986, .ec_per_block = 30, .g1_blocks = 22, .g1_data_per_block = 15, .g2_blocks = 41, .g2_data_per_block = 16 }, // H
    },
    // v36
    .{
        .{ .total_data_codewords = 2434, .ec_per_block = 30, .g1_blocks = 6, .g1_data_per_block = 121, .g2_blocks = 14, .g2_data_per_block = 122 }, // L
        .{ .total_data_codewords = 1914, .ec_per_block = 28, .g1_blocks = 6, .g1_data_per_block = 47, .g2_blocks = 34, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 1354, .ec_per_block = 30, .g1_blocks = 46, .g1_data_per_block = 24, .g2_blocks = 10, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 1054, .ec_per_block = 30, .g1_blocks = 2, .g1_data_per_block = 15, .g2_blocks = 64, .g2_data_per_block = 16 }, // H
    },
    // v37
    .{
        .{ .total_data_codewords = 2566, .ec_per_block = 30, .g1_blocks = 17, .g1_data_per_block = 122, .g2_blocks = 4, .g2_data_per_block = 123 }, // L
        .{ .total_data_codewords = 1992, .ec_per_block = 28, .g1_blocks = 29, .g1_data_per_block = 46, .g2_blocks = 14, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1426, .ec_per_block = 30, .g1_blocks = 49, .g1_data_per_block = 24, .g2_blocks = 10, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 1096, .ec_per_block = 30, .g1_blocks = 24, .g1_data_per_block = 15, .g2_blocks = 46, .g2_data_per_block = 16 }, // H
    },
    // v38
    .{
        .{ .total_data_codewords = 2702, .ec_per_block = 30, .g1_blocks = 4, .g1_data_per_block = 122, .g2_blocks = 18, .g2_data_per_block = 123 }, // L
        .{ .total_data_codewords = 2102, .ec_per_block = 28, .g1_blocks = 13, .g1_data_per_block = 46, .g2_blocks = 32, .g2_data_per_block = 47 }, // M
        .{ .total_data_codewords = 1502, .ec_per_block = 30, .g1_blocks = 48, .g1_data_per_block = 24, .g2_blocks = 14, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 1142, .ec_per_block = 30, .g1_blocks = 42, .g1_data_per_block = 15, .g2_blocks = 32, .g2_data_per_block = 16 }, // H
    },
    // v39
    .{
        .{ .total_data_codewords = 2812, .ec_per_block = 30, .g1_blocks = 20, .g1_data_per_block = 117, .g2_blocks = 4, .g2_data_per_block = 118 }, // L
        .{ .total_data_codewords = 2216, .ec_per_block = 28, .g1_blocks = 40, .g1_data_per_block = 47, .g2_blocks = 7, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 1582, .ec_per_block = 30, .g1_blocks = 43, .g1_data_per_block = 24, .g2_blocks = 22, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 1222, .ec_per_block = 30, .g1_blocks = 10, .g1_data_per_block = 15, .g2_blocks = 67, .g2_data_per_block = 16 }, // H
    },
    // v40
    .{
        .{ .total_data_codewords = 2956, .ec_per_block = 30, .g1_blocks = 19, .g1_data_per_block = 118, .g2_blocks = 6, .g2_data_per_block = 119 }, // L
        .{ .total_data_codewords = 2334, .ec_per_block = 28, .g1_blocks = 18, .g1_data_per_block = 47, .g2_blocks = 31, .g2_data_per_block = 48 }, // M
        .{ .total_data_codewords = 1666, .ec_per_block = 30, .g1_blocks = 34, .g1_data_per_block = 24, .g2_blocks = 34, .g2_data_per_block = 25 }, // Q
        .{ .total_data_codewords = 1276, .ec_per_block = 30, .g1_blocks = 20, .g1_data_per_block = 15, .g2_blocks = 61, .g2_data_per_block = 16 }, // H
    },
};
