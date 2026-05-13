const std = @import("std");
const Io = std.Io;
const mem = std.mem;

pub const ParseError = error{
    EmptyInput, // input is empty / whitespace only
    UnexpectedByte, // byte that cannot start a value
    UnexpectedEof, // stream ended before structure closed
    InvalidLiteral, // true/false/null spelled wrong
    InvalidString, // bad escape or bare control char in string
    InvalidNumber, // number violates JSON grammar
    TrailingContent, // leftover data after root value
    InvalidKey, // object key is not a string
    TrailingComma, // comma before closing ] or }
    MissingColon, // missing : in object
    ReadFailed, // propagated from Io.Reader when buffer exhausted
    OutOfMemory,
};

fn skipWhitespace(r: *Io.Reader) void {
    while (r.peekByte()) |b| {
        switch (b) {
            ' ', '\t', '\n', '\r' => r.toss(1),
            else => break,
        }
    } else |_| {}
}

pub fn parse(bytes: []u8) ParseError!void {
    if (bytes.len == 0) {
        std.log.err("Empty Input\n", .{});
        return ParseError.EmptyInput;
    }

    var reader: Io.Reader = .fixed(bytes);
    const r = &reader;

    skipWhitespace(r);
    _ = r.peekByte() catch {
        std.log.err("Input contains only whitespace", .{});
        return error.EmptyInput;
    };

    try parseValue(r);

    skipWhitespace(r);
    if (r.peekByte()) |extra| {
        std.log.err("Trailing content after JSON value: '{c}'", .{extra});
        return ParseError.TrailingContent;
    } else |_| {}
}

fn parseValue(r: *Io.Reader) ParseError!void {
    skipWhitespace(r);

    const b = r.peekByte() catch |err| switch (err) {
        error.EndOfStream => {
            std.log.err("Expected a JSON value but reached end of input", .{});
            return ParseError.UnexpectedEof;
        },
        error.ReadFailed => return ParseError.ReadFailed,
    };

    switch (b) {
        '{' => try parseObject(r),
        '[' => try parseArray(r),
        '"' => try parseString(r),
        '-', '0'...'9' => try parseNumber(r),
        't' => try parseLiteral(r, "true"),
        'f' => try parseLiteral(r, "false"),
        'n' => try parseLiteral(r, "null"),
        else => {
            std.log.err("Unexpected byte '{c}' — not a valid JSON value", .{b});
            return ParseError.UnexpectedByte;
        },
    }
}

fn parseObject(r: *Io.Reader) ParseError!void {
    _ = r.takeByte() catch return ParseError.UnexpectedEof;
    skipWhitespace(r);

    var peeked = r.peekByte() catch |err| switch (err) {
        error.EndOfStream => {
            std.log.err("Expected a JSON value but reached end of input", .{});
            return ParseError.UnexpectedEof;
        },
        error.ReadFailed => return ParseError.ReadFailed,
    };

    if (peeked == '}') {
        r.toss(1);
        return;
    }

    while (true) {
        skipWhitespace(r);

        const key_byte = r.peekByte() catch |err| switch (err) {
            error.EndOfStream => {
                std.log.err("Expected a JSON value but reached end of input", .{});
                return ParseError.UnexpectedEof;
            },
            error.ReadFailed => return ParseError.ReadFailed,
        };

        if (key_byte != '"') {
            std.log.err("Object key must be a string, got '{c}'", .{key_byte});
            return ParseError.InvalidKey;
        }

        try parseString(r);
        skipWhitespace(r);

        const colon = r.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                std.log.err("Expected a JSON value but reached end of input", .{});
                return ParseError.UnexpectedEof;
            },
            error.ReadFailed => return ParseError.ReadFailed,
        };

        if (colon != ':') {
            std.log.err("Expected ':' after object key, got '{c}'", .{colon});
            return ParseError.MissingColon;
        }

        skipWhitespace(r);
        try parseValue(r);
        skipWhitespace(r);

        const sep = r.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                std.log.err("Expected a JSON value but reached end of input", .{});
                return ParseError.UnexpectedEof;
            },
            error.ReadFailed => return ParseError.ReadFailed,
        };

        switch (sep) {
            ',' => {
                skipWhitespace(r);
                peeked = r.peekByte() catch |err| switch (err) {
                    error.EndOfStream => {
                        std.log.err("Expected a JSON value but reached end of input", .{});
                        return ParseError.UnexpectedEof;
                    },
                    error.ReadFailed => return ParseError.ReadFailed,
                };

                if (peeked == '}') {
                    std.log.err("Trailing comma before }} in object", .{});
                    return ParseError.TrailingComma;
                }
            },
            '}' => return,
            else => {
                std.log.err("Expected , or }} in object, got '{c}'", .{sep});
                return ParseError.UnexpectedByte;
            },
        }
    }
}

fn parseArray(r: *Io.Reader) ParseError!void {
    _ = r.takeByte() catch return ParseError.UnexpectedEof;
    skipWhitespace(r);

    var peeked = r.peekByte() catch |err| switch (err) {
        error.EndOfStream => {
            std.log.err("Expected a JSON value but reached end of input", .{});
            return ParseError.UnexpectedEof;
        },
        error.ReadFailed => return ParseError.ReadFailed,
    };

    if (peeked == ']') {
        r.toss(1);
        return;
    }

    while (true) {
        skipWhitespace(r);
        try parseValue(r);
        skipWhitespace(r);

        const sep = r.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                std.log.err("Expected a JSON value but reached end of input", .{});
                return ParseError.UnexpectedEof;
            },
            error.ReadFailed => return ParseError.ReadFailed,
        };

        switch (sep) {
            ',' => {
                skipWhitespace(r);
                peeked = r.peekByte() catch |err| switch (err) {
                    error.EndOfStream => {
                        std.log.err("Expected a JSON value but reached end of input", .{});
                        return ParseError.UnexpectedEof;
                    },
                    error.ReadFailed => return ParseError.ReadFailed,
                };

                if (peeked == ']') {
                    std.log.err("Trailing comma before ']' in array", .{});
                    return ParseError.TrailingComma;
                }
            },
            ']' => return,
            else => {
                std.log.err("Expected ',' or ']' in array, got '{c}'", .{sep});
                return ParseError.UnexpectedByte;
            },
        }
    }
}

fn parseString(r: *Io.Reader) ParseError!void {
    _ = r.takeByte() catch return ParseError.UnexpectedEof;

    while (true) {
        const b = r.takeByte() catch |err| switch (err) {
            error.EndOfStream => {
                std.log.err("Unterminated string", .{});
                return ParseError.UnexpectedEof;
            },
            error.ReadFailed => return ParseError.ReadFailed,
        };

        switch (b) {
            '"' => return,
            '\\' => {
                const esc = r.takeByte() catch |err| switch (err) {
                    error.EndOfStream => {
                        std.log.err("Unterminated escape sequence in string", .{});
                        return ParseError.InvalidString;
                    },
                    error.ReadFailed => return ParseError.ReadFailed,
                };

                switch (esc) {
                    '"', '\\', '/', 'b', 'f', 'n', 'r', 't' => {},
                    'u' => {
                        const hex = r.takeArray(4) catch |err| switch (err) {
                            error.EndOfStream => {
                                std.log.err("Incomplete \\uXXXX escape", .{});
                                return ParseError.InvalidString;
                            },
                            error.ReadFailed => return ParseError.ReadFailed,
                        };

                        for (hex) |h| {
                            if (!std.ascii.isHex(h)) {
                                std.log.err("Non-hex digit '{c}' in \\uXXXX", .{h});
                                return ParseError.InvalidString;
                            }
                        }
                    },
                    else => {
                        std.log.err("Invalid escape '\\{c}' in string", .{esc});
                        return ParseError.InvalidString;
                    },
                }
            },
            0x00...0x1f => {
                std.log.err("Unescaped control character 0x{x:02} in string", .{b});
                return ParseError.InvalidString;
            },
            else => {},
        }
    }
}

fn parseNumber(r: *Io.Reader) ParseError!void {
    if ((r.peekByte() catch 0) == '-') {
        r.toss(1);
        const after: u8 = r.peekByte() catch {
            std.log.err("'-' at end of input in number", .{});
            return ParseError.InvalidNumber;
        };
        if (!std.ascii.isDigit(after)) {
            std.log.err("'-' followed by non-digit '{c}'", .{after});
            return ParseError.InvalidNumber;
        }
    }

    const first: u8 = r.peekByte() catch return ParseError.InvalidNumber;
    if (first == '0') {
        r.toss(1);
        if (r.peekByte()) |d| {
            if (std.ascii.isDigit(d)) {
                std.log.err("Leading zero in number", .{});
                return ParseError.InvalidNumber;
            }
        } else |_| {}
    } else {
        while (r.peekByte()) |d| {
            if (!std.ascii.isDigit(d)) break;
            r.toss(1);
        } else |_| {}
    }

    if ((r.peekByte() catch 0) == '.') {
        r.toss(1);
        const fd: u8 = r.peekByte() catch {
            std.log.err("Expected digit after '.' in number", .{});
            return ParseError.InvalidNumber;
        };
        if (!std.ascii.isDigit(fd)) {
            std.log.err("Expected digit after '.', got '{c}'", .{fd});
            return ParseError.InvalidNumber;
        }
        while (r.peekByte()) |d| {
            if (!std.ascii.isDigit(d)) break;
            r.toss(1);
        } else |_| {}
    }

    // optional exponent: ('e'|'E') ['+' | '-'] digit+
    const exp_ch: u8 = r.peekByte() catch 0;
    if (exp_ch == 'e' or exp_ch == 'E') {
        r.toss(1);
        const sign_or_d: u8 = r.peekByte() catch {
            std.log.err("Expected digit or sign after exponent marker", .{});
            return ParseError.InvalidNumber;
        };
        if (sign_or_d == '+' or sign_or_d == '-') r.toss(1);
        const ed: u8 = r.peekByte() catch {
            std.log.err("Expected digit in exponent", .{});
            return ParseError.InvalidNumber;
        };
        if (!std.ascii.isDigit(ed)) {
            std.log.err("Expected digit in exponent, got '{c}'", .{ed});
            return ParseError.InvalidNumber;
        }
        while (r.peekByte()) |d| {
            if (!std.ascii.isDigit(d)) break;
            r.toss(1);
        } else |_| {}
    }
}

fn parseLiteral(r: *Io.Reader, comptime expected: []const u8) ParseError!void {
    const got = r.takeArray(expected.len) catch |err| switch (err) {
        error.EndOfStream => {
            std.log.err("Expected a JSON value but reached end of input", .{});
            return ParseError.UnexpectedEof;
        },
        error.ReadFailed => return ParseError.ReadFailed,
    };

    if (!mem.eql(u8, got, expected)) {
        std.log.err("Invalid literal: expected '{s}', got '{s}'", .{ expected, got });
        return ParseError.InvalidLiteral;
    }
}
