const std = @import("std");
const testing = std.testing;

pub const BencodeValue = union(enum) {
    string: []const u8,
    integer: i64,
    list: []BencodeValue,
    dictionary: std.StringHashMap(BencodeValue),

    pub fn deinit(self: *BencodeValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .list => |l| {
                for (l) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(l);
            },
            .dictionary => |*d| {
                var it = d.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                d.deinit();
            },
            .integer => {},
        }
    }
};

pub fn encode(alloc: std.mem.Allocator, value: BencodeValue) ![]u8 {
    var buff: std.ArrayList(u8) = .empty;
    errdefer buff.deinit(alloc);

    try encodeValue(value, &buff, alloc);
    return buff.toOwnedSlice(alloc);
}

fn encodeValue(v: BencodeValue, encode_buff: *std.ArrayList(u8), alloc: std.mem.Allocator) !void {
    switch (v) {
        .string => |s| try encode_buff.print(alloc, "{d}:{s}", .{ s.len, s }),
        .integer => |i| try encode_buff.print(alloc, "i{d}e", .{i}),
        .list => |l| {
            try encode_buff.append(alloc, 'l');

            for (l) |item| {
                try encodeValue(item, encode_buff, alloc);
            }

            try encode_buff.append(alloc, 'e');
        },
        .dictionary => |d| {
            try encode_buff.append(alloc, 'd');

            var keys: std.ArrayList([]const u8) = .empty;
            defer keys.deinit(alloc);

            var iter = d.iterator();
            while (iter.next()) |entry| try keys.append(alloc, entry.key_ptr.*);

            std.mem.sort([]const u8, keys.items, {}, struct {
                pub fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.order(u8, a, b) == .lt;
                }
            }.lessThan);

            for (keys.items) |key| {
                try encodeValue(.{ .string = key }, encode_buff, alloc);
                const value = d.get(key).?;
                try encodeValue(value, encode_buff, alloc);
            }

            try encode_buff.append(alloc, 'e');
        },
    }
}

test "encode string" {
    const allocator = testing.allocator;
    const value = BencodeValue{ .string = "coding" };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("6:coding", encoded);
}

test "encode integer" {
    const allocator = testing.allocator;
    const value = BencodeValue{ .integer = 100 };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("i100e", encoded);
}

test "encode negative integer" {
    const allocator = testing.allocator;
    const value = BencodeValue{ .integer = -42 };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("i-42e", encoded);
}

test "encode list" {
    const allocator = testing.allocator;

    var items = try allocator.alloc(BencodeValue, 2);
    defer allocator.free(items);
    items[0] = BencodeValue{ .string = "Coding" };
    items[1] = BencodeValue{ .string = "Challenges" };

    const value = BencodeValue{ .list = items };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("l6:Coding10:Challengese", encoded);
}

test "encode dictionary" {
    const allocator = testing.allocator;

    var dict = std.StringHashMap(BencodeValue).init(allocator);
    defer dict.deinit();

    try dict.put("Rating", BencodeValue{ .string = "Awesome" });
    try dict.put("website:", BencodeValue{ .string = "codingchallenges.fyi" });

    var outer_dict = std.StringHashMap(BencodeValue).init(allocator);
    defer outer_dict.deinit();

    try outer_dict.put("Coding Challenges", BencodeValue{ .dictionary = dict });

    const value = BencodeValue{ .dictionary = outer_dict };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("d17:Coding Challengesd6:Rating7:Awesome8:website:20:codingchallenges.fyiee", encoded);
}

test "encode empty string" {
    const allocator = testing.allocator;
    const value = BencodeValue{ .string = "" };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("0:", encoded);
}

test "encode empty list" {
    const allocator = testing.allocator;
    const items = try allocator.alloc(BencodeValue, 0);
    defer allocator.free(items);

    const value = BencodeValue{ .list = items };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("le", encoded);
}

test "encode empty dictionary" {
    const allocator = testing.allocator;
    const dict = std.StringHashMap(BencodeValue).init(allocator);

    const value = BencodeValue{ .dictionary = dict };
    const encoded = try encode(allocator, value);
    defer allocator.free(encoded);

    try testing.expectEqualStrings("de", encoded);
}
