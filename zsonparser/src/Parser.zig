const std = @import("std");
const Token = @import("Tokens.zig");

const Arraylist = std.ArrayList;

const Self = @This();

tokens: Arraylist(Token),
current: usize,

pub fn init(tokens: std.ArrayList(Token)) Self {
    return Self{
        .tokens = tokens,
        .current = 0,
    };
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
    return self.tokens.orderedRemove(self.current);
}

fn peekNext(self: *Self) u8 {
    if (self.current + 1 >= self.source.len) return '\n';
    return self.source[self.current + 1];
}

pub fn parse(self: *Self) !bool {
    for (self.tokens.items) |token| {
        switch (token.type) {
            .OBJECT_BEGIN => return try self.parseObject(),
            .ARRAY_BEGIN => try self.parseArray(),
            else => {}
        }
    }
}

fn parseObject(self: *Self) !bool {
    if (self.peek() != '"' and self.peekNext() == '}') {
        return true;
    }
}

fn parseArray(self: *Self) !void {
    _ = self;
}
