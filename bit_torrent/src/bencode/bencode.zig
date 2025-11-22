const std = @import("std");

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
