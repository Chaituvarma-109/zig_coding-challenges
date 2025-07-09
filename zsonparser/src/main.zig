const std = @import("std");
const Scanner = @import("Scanner.zig");
const Parser = @import("Parser.zig");

const testing = std.testing;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;

    const args = try std.process.argsAlloc(page_alloc);
    defer std.process.argsFree(page_alloc, args);

    if (args.len > 2) {
        try stderr.print("Too many arguments\n", .{});
        return;
    }

    const file = args[1];

    _ = try parseJson(file, page_alloc);
}

pub fn parseJson(json_file: []const u8, alloc: std.mem.Allocator) anyerror![]const u8 {
    const file_contents = try std.fs.cwd().readFileAlloc(alloc, json_file, std.math.maxInt(usize));
    defer alloc.free(file_contents);

    if (file_contents.len == 0) {
        return error.EmptyJsonFile;
    }

    const is_valid_object = std.mem.startsWith(u8, file_contents, "{") and std.mem.endsWith(u8, file_contents, "}");
    const is_valid_array = std.mem.startsWith(u8, file_contents, "[") and std.mem.endsWith(u8, file_contents, "]");

    if (!(is_valid_object or is_valid_array)) {
        return error.InvalidJson;
    } else {
        var scanner = Scanner.init(file_contents, alloc);
        defer scanner.tokens.deinit();
        const res = scanner.scan() catch |err| {
            return err;
        };
        // try scanner.printtokens();
        // var parser = Parser.init(scanner.tokens);
        // const res = try parser.parse();

        if (res) {
            return "ValidJson";
        } else {
            return "some error";
        }
    }
}

test "step 1 valid json" {
    std.debug.print("test 1 valid json\n", .{});
    const file_path: []const u8 = "tests/step1/valid.json";
    const result = parseJson(file_path, testing.allocator) catch |err| {
        std.debug.print("Unexpected error: {}\n", .{err});
        return error.TestFailed;
    };
    try testing.expectEqualStrings("ValidJson", result);
}

test "step 1 invalid json" {
    std.debug.print("test 1 invalid json\n", .{});
    const file_path: []const u8 = "tests/step1/invalid.json";
    _ = parseJson(file_path, testing.allocator) catch |err| {
        try testing.expectEqual(error.EmptyJsonFile, err);
        return;
    };
}

test "step 2 valid json" {
    std.debug.print("test 2 valid json\n", .{});
    const file_path: []const u8 = "tests/step2/valid.json";
    const result = parseJson(file_path, testing.allocator) catch |err| {
        std.debug.print("Unexpected error: {}\n", .{err});
        return error.TestFailed;
    };
    try testing.expectEqualStrings("ValidJson", result);
}

test "step 2 valid2 json" {
    std.debug.print("test 2 valid2 json\n", .{});
    const file_path: []const u8 = "tests/step2/valid2.json";
    const result = parseJson(file_path, testing.allocator) catch |err| {
        std.debug.print("Unexpected error: {}\n", .{err});
        return error.TestFailed;
    };
    try testing.expectEqualStrings("ValidJson", result);
}

test "step 2 invalid json" {
    std.debug.print("test 2 invalid json\n", .{});
    const file_path: []const u8 = "tests/step2/invalid.json";
    _ = parseJson(file_path, testing.allocator) catch |err| {
        try testing.expectEqual(error.FoundTrailingComma, err);
        return;
    };
}

test "step 2 invalid2 json" {
    std.debug.print("test 2 invalid2 json\n", .{});
    const file_path: []const u8 = "tests/step2/invalid2.json";
    _ = parseJson(file_path, testing.allocator) catch |err| {
        try testing.expectEqual(error.NotFoundStringPair, err);
        return;
    };
}

// test "step 1 test pass 1 json" {
//     const file_path: []const u8 = "test/pass1.json"; // Fixed path
//     const result = parseJson(file_path, testing.allocator) catch |err| {
//         std.debug.print("Unexpected error: {}\n", .{err});
//         return error.TestFailed;
//     };
//     try testing.expectEqualStrings("ValidJson", result);
// }

// test "step 1 test pass 2 json" {
//     const file_path: []const u8 = "test/pass2.json"; // Fixed path
//     const result = parseJson(file_path, testing.allocator) catch |err| {
//         std.debug.print("Unexpected error: {}\n", .{err});
//         return error.TestFailed;
//     };
//     try testing.expectEqualStrings("ValidJson", result);
// }

// test "step 1 test pass 3 json" {
//     const file_path: []const u8 = "test/pass3.json"; // Fixed path
//     const result = parseJson(file_path, testing.allocator) catch |err| {
//         std.debug.print("Unexpected error: {}\n", .{err});
//         return error.TestFailed;
//     };
//     try testing.expectEqualStrings("ValidJson", result);
// }

// test "step 1 test fail 1 json" {
//     const file_path: []const u8 = "test/fail1.json"; // Fixed path
//     _ = parseJson(file_path, testing.allocator) catch |err| {
//         try testing.expectEqual(error.InvalidJson, err);
//         return;
//     };
// }

// test "step 1 test fail 2 json" {
//     const file_path: []const u8 = "test/fail2.json"; // Fixed path
//     _ = parseJson(file_path, testing.allocator) catch |err| {
//         try testing.expectEqual(error.InvalidJson, err);
//         return;
//     };
// }

// test "step 1 test fail 32 json" {
//     const file_path: []const u8 = "test/fail32.json"; // Fixed path
//     _ = parseJson(file_path, testing.allocator) catch |err| {
//         try testing.expectEqual(error.InvalidJson, err);
//         return;
//     };
// }
