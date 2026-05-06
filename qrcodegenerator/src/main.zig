const std = @import("std");
const encode = @import("encode.zig");
const lexopts = @import("lexopts");
const short = lexopts.matchShort;
const long = lexopts.matchLong;
const Io = std.Io;
const mem = std.mem;
const meta = std.meta;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    var ecl: encode.ErrorcorrectionLevel = undefined;
    var inp: []const u8 = undefined;

    const argv = try init.minimal.args.toSlice(arena);
    var parser = lexopts.Parser.init(argv);

    while (try parser.next()) |arg| {
        switch (arg) {
            .option => |opt| {
                if (short(opt, 'e') or long(opt, "ecl")) {
                    const val = parser.value() catch return error.UnknownArgument;
                    ecl = meta.stringToEnum(encode.ErrorcorrectionLevel, val) orelse return error.InvalidErrorLevel;
                } else if (short(opt, 'i') or long(opt, "inp")) {
                    inp = parser.value() catch return error.InvalidInput;
                }
            },
            .pos_arg => std.debug.print("no positional args\n", .{}),
        }
    }

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const r = try encode.totalBits(inp, ecl);

    try stdout_writer.print("r: {s}, len: {d}\n", .{ r, r.len });
    try stdout_writer.flush(); // Don't forget to flush!
}
