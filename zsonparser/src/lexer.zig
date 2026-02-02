const std = @import("std");
const Io = std.Io;
const mem = std.mem;

pub const TokenType = enum {
    object_start,
    object_end,
    array_start,
    array_end,
    string,
    colon,
    comma,
    number,
    true,
    false,
    null,
};

pub const Result = struct {
    token: TokenType,
    start: usize,
    end: usize,
};

pub fn lexe(alloc: mem.Allocator, bytes: []u8) !std.MultiArrayList(Result) {
    var tokens_arr_lst: std.MultiArrayList(Result) = .empty;
    errdefer tokens_arr_lst.deinit(alloc);

    var i: usize = 0;
    while (i < bytes.len) {
        const char: u8 = bytes[i];

        const res = blk: switch (char) {
            '{' => {
                const r = Result{ .token = .object_start, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            '}' => {
                const r = Result{ .token = .object_end, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            '[' => {
                const r = Result{ .token = .array_start, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            ']' => {
                const r = Result{ .token = .array_end, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            '"' => {
                i += 1;
                const idx: usize = mem.find(u8, bytes[i..], "\"") orelse return error.NoQuotation;
                const end: usize = i + idx;

                const r = Result{ .token = .string, .start = i, .end = end };
                i += idx + 1;
                break :blk r;
            },
            ':' => {
                const r = Result{ .token = .colon, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            ',' => {
                const r = Result{ .token = .comma, .start = i, .end = i + 1 };
                i += 1;
                break :blk r;
            },
            'n' => {
                const r = Result{ .token = .null, .start = i, .end = i + 4 };
                i += 4;
                break :blk r;
            },
            't' => {
                const r = Result{ .token = .true, .start = i, .end = i + 4 };
                i += 4;
                break :blk r;
            },
            'f' => {
                const r = Result{ .token = .false, .start = i, .end = i + 5 };
                i += 5;
                break :blk r;
            },
            '\n', '\r', '\t', ' ' => {
                i += 1;
                continue;
            },
            '-', '0'...'9' => {
                var end: usize = i + 1;
                while (end < bytes.len) : (end += 1) {
                    const ch = bytes[end];
                    if (ch != '-' and ch != '.' and !std.ascii.isDigit(ch)) break;
                }

                const r = Result{ .token = .number, .start = i, .end = end };
                i = end;
                break :blk r;
            },
            else => {
                std.log.err("err tok: {c}\n", .{char});
                return error.InvalidToken;
            },
        };

        try tokens_arr_lst.append(alloc, res);
    }

    return tokens_arr_lst;
}
