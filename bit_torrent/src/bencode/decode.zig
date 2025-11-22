const std = @import("std");
const testing = std.testing;

const bcode = @import("bencode.zig");

pub fn decode(alloc: std.mem.Allocator, val: []const u8) !bcode.BencodeValue {
    var pos: usize = 0;
    return try decodeValue(alloc, val, &pos);
}

fn decodeValue(alloc: std.mem.Allocator, value: []const u8, pos: *usize) !bcode.BencodeValue {
    switch (value[pos.*]) {
        'i' => {
            pos.* += 1;
            var j = pos.*;
            while (j < value.len and value[j] != 'e') : (j += 1) {}

            const num_str = value[pos.*..j];
            const num = try std.fmt.parseInt(i64, num_str, 10);

            pos.* = j + 1;

            return .{ .integer = num };
        },
        'l' => {
            pos.* += 1;
            var list: std.ArrayList(bcode.BencodeValue) = .empty;
            errdefer {
                for (list.items) |*item| {
                    item.deinit(alloc);
                }
                list.deinit(alloc);
            }

            while (pos.* < value.len and value[pos.*] != 'e') {
                const item = try decodeValue(alloc, value, pos);
                try list.append(alloc, item);
            }

            pos.* += 1; //skip 'e'

            return .{ .list = try list.toOwnedSlice(alloc) };
        },
        '0'...'9' => {
            var j = pos.*;
            while (j < value.len and value[j] != ':') : (j += 1) {}

            const len_str = value[pos.*..j];
            const len = try std.fmt.parseInt(usize, len_str, 10);

            j += 1; // skip ':'

            const str = value[j .. j + len];

            // Allocate new memory and copy the string
            const allocated_str = try alloc.alloc(u8, len);
            errdefer alloc.free(allocated_str);

            @memcpy(allocated_str, str);

            pos.* = j + len;

            return .{ .string = allocated_str };
        },
        'd' => {
            pos.* += 1; // skip 'd'

            var dict: std.StringHashMap(bcode.BencodeValue) = .init(alloc);
            errdefer {
                var it = dict.iterator();

                while (it.next()) |entry| {
                    alloc.free(entry.key_ptr.*);
                    entry.value_ptr.*.deinit(alloc);
                }
                dict.deinit();
            }

            while (pos.* < value.len and value[pos.*] != 'e') {
                const key = try decodeValue(alloc, value, pos);
                errdefer alloc.free(key.string);

                var val = try decodeValue(alloc, value, pos);
                errdefer val.deinit(alloc);

                try dict.put(key.string, val);
            }

            pos.* += 1; // skip 'e'

            return .{ .dictionary = dict };
        },
        else => {},
    }

    return error.InvalidEncoding;
}

test "decode integer" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "i100e");
    defer value.deinit(allocator);

    try testing.expectEqual(@as(i64, 100), value.integer);
}

test "decode negative integer" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "i-42e");
    defer value.deinit(allocator);

    try testing.expectEqual(@as(i64, -42), value.integer);
}

test "decode string" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "6:coding");
    defer value.deinit(allocator);

    try testing.expectEqualStrings("coding", value.string);
}

test "decode empty string" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "0:");
    defer value.deinit(allocator);

    try testing.expectEqualStrings("", value.string);
}

test "decode list" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "l6:Coding10:Challengese");
    defer value.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), value.list.len);
    try testing.expectEqualStrings("Coding", value.list[0].string);
    try testing.expectEqualStrings("Challenges", value.list[1].string);
}

test "decode empty list" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "le");
    defer value.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), value.list.len);
}

test "decode dictionary" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "d17:Coding Challengesd6:Rating7:Awesome8:website:20:codingchallenges.fyiee");
    defer value.deinit(allocator);

    const inner = value.dictionary.get("Coding Challenges").?;
    try testing.expectEqualStrings("Awesome", inner.dictionary.get("Rating").?.string);
    try testing.expectEqualStrings("codingchallenges.fyi", inner.dictionary.get("website:").?.string);
}

test "decode empty dictionary" {
    const allocator = testing.allocator;
    var value = try decode(allocator, "de");
    defer value.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), value.dictionary.count());
}
