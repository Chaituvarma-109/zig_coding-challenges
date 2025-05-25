const std = @import("std");

const Self = @This();

pub const TokenType = enum {
    OBJECT_BEGIN, // {
    OBJECT_END, // }
    ARRAY_BEGIN, // [
    ARRAY_END, // ]
    NAME_SEPARATOR, // :
    COMMA, // ,
    TRUE, // true
    FALSE, // false
    NULL, // null
    STRING, // "string"
    NUMBER, // 123.456
    EOF, // end of file
};

type: TokenType,
lexeme: []const u8,

pub fn new(token_type: TokenType, lexeme: []const u8) Self {
    return Self{
        .type = token_type,
        .lexeme = lexeme,
    };
}
