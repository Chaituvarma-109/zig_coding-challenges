const std = @import("std");
const Modes = @import("modes.zig").Modes;

const ErrorcorrectionLevel = enum {
    L,
    M,
    Q,
    H,
};

const Version = struct {
    h: usize,
    w: usize,
};

const QRcodeVersion = enum {
    v1,
    v2,
    v3,
    v4,
    v5,

    fn getSize(version: QRcodeVersion) Version {
        return switch (version) {
            .v1 => .{ .h = 21, .w = 21 },
            .v2 => .{ .h = 25, .w = 25 },
            .v3 => .{ .h = 29, .w = 29 },
            .v4 => .{ .h = 33, .w = 33 },
            .v5 => .{ .h = 37, .w = 37 },
        };
    }
};

fn charCountIndicator(qrversion: QRcodeVersion, m: Modes) usize {
    return switch (qrversion) {
        .v1, .v2, .v3, .v4, .v5 => {
            switch (m) {
                .numeric => 10,
                .alphanumeric => 9,
                .byte => 8,
                .kanji => 8,
            }
        },
        else => {},
    };
}
