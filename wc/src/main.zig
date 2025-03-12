const std = @import("std");

pub fn main() !void {
    var options: ?[]const u8 = null;
    var file_name: ?[]const u8 = null;
    var file: std.fs.File = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    while (args.next()) |arg| {
        if (arg.len > 1 and std.mem.startsWith(u8, arg, "-")) {
            options = arg;
        } else {
            file_name = arg;
        }
    }

    if (file_name) |f_name| {
        file = std.fs.cwd().openFile(f_name, .{}) catch |err| {
            std.debug.print("Error in opening file: {any}\n", .{err});
            return;
        };
    } else {
        file = std.io.getStdIn();
    }
    defer file.close();

    const file_content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(file_content);

    const stats = get_stats(file_content);

    if (options) |opt| {
        if (std.mem.eql(u8, opt, "-c")) {
            std.debug.print("{d}\n", .{file_content.len});
        } else if (std.mem.eql(u8, opt, "-l")) {
            std.debug.print("{d}\n", .{stats.lines});
        } else if (std.mem.eql(u8, opt, "-w")) {
            std.debug.print("{d}\n", .{stats.words});
        } else if (std.mem.eql(u8, opt, "-m")) {
            std.debug.print("{d}\n", .{stats.chars});
        } else {
            std.debug.print("Invalid option: {s}\n", .{opt});
        }
    } else {
        if (file_name) |fname| {
            std.debug.print("{d} {d} {d} {s}\n", .{ stats.lines, stats.words, file_content.len, fname });
        } else {
            std.debug.print("{d} {d} {d} {any}\n", .{ stats.lines, stats.words, file_content.len, file });
        }
    }
}

fn get_stats(content: []u8) struct { lines: u64, chars: u64, words: u64 } {
    var line_no: u64 = 0;
    var char_no: u64 = 0;
    var words: u64 = 0;
    var is_word = false;
    for (content) |char| {
        // num of lines
        if (char == '\n') {
            line_no += 1;
        }
        // num of words
        if (std.ascii.isWhitespace(char)) {
            if (is_word) {
                words += 1;
            }
            is_word = false;
        } else {
            is_word = true;
        }

        // Add 1 to line count if file doesn't end with newline but has content
        if (content.len > 0 and content[content.len - 1] != '\n') {
            line_no += 1;
        }
        // char_no += 1;
        if ((char <= 0x7f) or (char >= 0xc0 and char <= 0xf7)) {
            char_no += 1;
        }
    }

    return .{ .lines = line_no, .chars = char_no, .words = words };
}
