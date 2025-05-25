const std = @import("std");
const Token = @import("Tokens.zig");

const stderr = std.io.getStdErr().writer();
const Arraylist = std.ArrayList;

const Self = @This();

source: []const u8,
current: usize,
start: usize,
tokens: Arraylist(Token),

pub fn init(source: []const u8, allocator: std.mem.Allocator) Self {
    return Self{
        .source = source,
        .current = 0,
        .start = 0,
        .tokens = Arraylist(Token).init(allocator),
    };
}

pub fn deinit(self: *Self) !void {
    self.tokens.deinit();
}

pub fn printtokens(self: *Self) !void {
    std.debug.print("{any}\n", .{self.tokens.items});
}

fn isAtEnd(self: *Self) bool {
    return self.current >= self.source.len;
}

fn advance(self: *Self) u8 {
    const c = self.source[self.current];
    self.current += 1;
    return c;
}

fn peek(self: *Self) u8 {
    if (self.isAtEnd()) return '\n';
    return self.source[self.current];
}

fn peekNext(self: *Self) u8 {
    if (self.current + 1 >= self.source.len) return '\n';
    return self.source[self.current + 1];
}

fn add_tokens(self: *Self, token_type: Token.TokenType, lex: []const u8) !void {
    const tok = Token.new(token_type, lex);
    try self.tokens.append(tok);
}

pub fn scan(self: *Self) !void {
    while (!self.isAtEnd()) {
        self.start = self.current;
        try self.scanToken();
    }

    const eofToken = Token.new(.EOF, "");
    _ = try self.tokens.append(eofToken);
}

pub fn scanToken(self: *Self) !void {
    const ch = self.advance();
    switch (ch) {
        '{' => try self.add_tokens(.OBJECT_BEGIN, "{"),
        '[' => try self.add_tokens(.ARRAY_BEGIN, "["),
        '}' => try self.add_tokens(.OBJECT_END, "}"),
        ']' => try self.add_tokens(.OBJECT_END, "]"),
        'f' => {
            const pos = self.current;
            if (self.source[pos + 1] == 'a' and self.source[pos + 2] == 'l' and self.source[pos + 3] == 's' and self.source[pos + 4] == 'e') {
                try self.add_tokens(.FALSE, "false");
            } else {
                try stderr.print("{c} is not boolean.", .{ch});
            }
            self.current += 4;
        },
        't' => {
            const pos = self.current;
            if (self.source[pos + 1] == 'r' and self.source[pos + 2] == 'u' and self.source[pos + 3] == 'e') {
                try self.add_tokens(.TRUE, "true");
            } else {
                try stderr.print("{c} is not boolean.", .{ch});
            }
            self.current += 3;
        },
        'n' => {
            const pos = self.current;
            if (self.source[pos + 1] == 'u' and self.source[pos + 2] == 'l' and self.source[pos + 3] == 'l') {
                try self.add_tokens(.NULL, "null");
            } else {
                try stderr.print("{c} is not null.", .{ch});
            }

            self.current += 3;
        },
        ',' => try self.add_tokens(.COMMA, ","),
        ':' => try self.add_tokens(.NAME_SEPARATOR, ":"),
        '"' => try self.handlestring(),
        ' ', 0, '\r', '\t' => {},
        else => try self.handleNumber(),
    }
}

fn handlestring(self: *Self) !void {
    _= self;
}

fn handleNumber(self: *Self) !void {
    _ = self;
}
