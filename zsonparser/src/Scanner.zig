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

pub fn scan(self: *Self) !bool {
    s: switch (self.source[self.current]) {
        '{' => {
            self.current += 1;
            continue :s self.source[self.current];
        },
        '[' => {
            self.current += 1;
            continue :s self.source[self.current];
        },
        '}' => {
            self.current += 1;
            if (!self.isAtEnd()) {
                continue :s self.source[self.current];
            } else {
                if (self.source.len - 1 == ',') {
                    return error.FoundTrailingComma;
                }
                return true;
            }
        },
        ']' => {
            self.current += 1;
            if (!self.isAtEnd()) {
                continue :s self.source[self.current];
            } else {
                return true;
            }
        },
        'f' => {
            if (try self.matchkeyword("false")) {
                continue :s self.source[self.current];
            } else {
                try stderr.print("{c} is not boolean.\n", .{self.source[self.current]});
                return false;
            }
        },
        't' => {
            if (try self.matchkeyword("true")) {
                continue :s self.source[self.current];
            } else {
                try stderr.print("{c} is not boolean.\n", .{self.source[self.current]});
                return false;
            }
        },
        'n' => {
            if (try self.matchkeyword("null")) {
                continue :s self.source[self.current];
            } else {
                try stderr.print("{c} is not null.\n", .{self.source[self.current]});
                return false;
            }
        },
        ',' => {
            self.current += 1;
            continue :s self.source[self.current];
        },
        ':' => {},
        '"' => {
            const res = self.handlestring() catch |err| {
                return err;
            };
            if (res) {
                continue :s self.source[self.current];
            }
        },
        ' ', '\n', '\r', '\t' => {
            self.current += 1;
            continue :s self.source[self.current];
        },
        0...9 => try self.handleNumber(),
        else => return error.UnexpectedToken,
    }

    return true;
}

fn matchkeyword(self: *Self, keyword: []const u8) !bool {
    if (self.current + keyword.len > self.source.len) {
        return false;
    }

    for (keyword, 0..) |char, i| {
        if (self.source[self.current + i] != char) {
            return false;
        }
    }

    if (self.current + keyword.len < self.source.len) {
        const next_char = self.source[self.current + keyword.len];
        if (std.ascii.isAlphabetic(next_char) or std.ascii.isDigit(next_char) or next_char == '_') {
            return false;
        }
    }

    self.current += keyword.len;
    return true;
}

fn handlestring(self: *Self) anyerror!bool {
    _ = self.advance();
    var pos = self.current;
    p: switch (self.source[pos]) {
        '"' => {
            if (self.source[pos + 1] == ':' or self.source[pos + 1] == ',') {
                self.current = pos + 1;
                return true;
            }
        },
        else => {
            pos += 1;
            continue :p self.source[pos];
        },
    }

    return error.NotFoundStringPair;
}

fn handleNumber(self: *Self) !void {
    _ = self;
    std.debug.print("in the handle number\n", .{});
}
