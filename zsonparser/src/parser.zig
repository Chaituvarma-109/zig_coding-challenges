const std = @import("std");
const Io = std.Io;
const lex = @import("lexer.zig");

const Result = lex.Result;
const TokenType = lex.TokenType;

pub fn parse(alloc: std.mem.Allocator, arr_lst: std.MultiArrayList(Result), content: []const u8, stdout_writer: *Io.Writer) ![][]const u8 {
    _ = stdout_writer;
    var pars_lst: std.ArrayList([]const u8) = .empty;
    errdefer pars_lst.deinit(alloc);

    var colon: bool = false;

    for (arr_lst.items(.token), arr_lst.items(.start), arr_lst.items(.end)) |tok, s, e| {
        const str: []const u8 = content[s..e];
        switch (tok) {
            TokenType.object_start => {
                try pars_lst.append(alloc, str);
                try pars_lst.append(alloc, " \n");
            },
            TokenType.object_end => {
                try pars_lst.append(alloc, "\n");
                try pars_lst.append(alloc, " ");
                try pars_lst.append(alloc, str);
            },
            TokenType.array_start => {
                try pars_lst.append(alloc, str);
            },
            TokenType.array_end => {
                try pars_lst.append(alloc, str);
            },
            TokenType.colon => {
                colon = true;
                try pars_lst.append(alloc, str);
                try pars_lst.append(alloc, " ");
            },
            TokenType.comma => {
                try pars_lst.append(alloc, str);
                try pars_lst.append(alloc, "\n");
                try pars_lst.append(alloc, " ");
            },
            TokenType.true => {
                try pars_lst.append(alloc, str);
            },
            TokenType.false => {
                try pars_lst.append(alloc, str);
            },
            TokenType.null => {
                try pars_lst.append(alloc, str);
            },
            TokenType.string => {
                if (!colon) try pars_lst.append(alloc, " ");
                try pars_lst.append(alloc, "\"");
                try pars_lst.append(alloc, str);
                try pars_lst.append(alloc, "\"");
                colon = false;
            },
            TokenType.number => {
                try pars_lst.append(alloc, str);
            },
        }
    }

    return pars_lst.toOwnedSlice(alloc);
}
