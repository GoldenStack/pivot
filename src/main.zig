const std = @import("std");
const buffer = @import("buffer.zig");
const tty = @import("platform/tty.zig");

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {
    const term = try tty.Tty.init();
    defer term.deinit();

    var buf = buffer.Buffer.init();
    buf.set(5, 1, 'X');

    while (true) {
        const key = try term.blocking_input();
        const slice = key.slice();

        try term.render(&buffer.Buffer.fill(slice[0]));

        if (slice[0] == 13) {
            return;
        }
    }
}
