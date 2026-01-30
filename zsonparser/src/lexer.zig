const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const TokenType = enum {
    object_start,
    object_end,
    array_start,
    array_end,
    quote,
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

        switch (char) {
            '{' => {
                try tokens_arr_lst.append(alloc, .{ .token = .object_start, .start = i, .end = i + 1 });
                i += 1;
            },
            '}' => {
                try tokens_arr_lst.append(alloc, .{ .token = .object_end, .start = i, .end = i + 1 });
                i += 1;
            },
            '[' => {
                try tokens_arr_lst.append(alloc, .{ .token = .array_start, .start = i, .end = i + 1 });
                i += 1;
            },
            ']' => {
                try tokens_arr_lst.append(alloc, .{ .token = .array_end, .start = i, .end = i + 1 });
                i += 1;
            },
            '"' => {
                i += 1;
                const idx: usize = mem.find(u8, bytes[i..], "\"") orelse {
                    std.log.err("tok: {s}\n", .{bytes[i..]});
                    return error.NoQuotation;
                };
                const end: usize = i + idx;

                try tokens_arr_lst.append(alloc, .{ .token = .string, .start = i, .end = end });
                i += idx + 1;
            },
            ':' => {
                try tokens_arr_lst.append(alloc, .{ .token = .colon, .start = i, .end = i + 1 });
                i += 1;
            },
            ',' => {
                try tokens_arr_lst.append(alloc, .{ .token = .comma, .start = i, .end = i + 1 });
                i += 1;
            },
            'n' => {
                try tokens_arr_lst.append(alloc, .{ .token = .null, .start = i, .end = i + 4 });
                i += 4;
            },
            't' => {
                try tokens_arr_lst.append(alloc, .{ .token = .true, .start = i, .end = i + 4 });
                i += 4;
            },
            'f' => {
                try tokens_arr_lst.append(alloc, .{ .token = .false, .start = i, .end = i + 5 });
                i += 5;
            },
            '\n', '\r', '\t', ' ' => {
                i += 1;
                continue;
            },
            '-', '0'...'9' => {
                var end: usize = 1;
                for (bytes[i..]) |value| {
                    if (value != '-' and !std.ascii.isDigit(value)) {
                        end += 1;
                    }
                }
                try tokens_arr_lst.append(alloc, .{ .token = .number, .start = i, .end = i + end });
                i += end;
            },
            else => {
                std.log.err("err tok: {c}\n", .{char});
                return error.InvalidToken;
            },
        }
    }

    return tokens_arr_lst;
}
