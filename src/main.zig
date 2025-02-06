const std = @import("std");
const buffer = @import("buffer.zig");
const tty = @import("platform/tty.zig");

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {

    const term = try tty.Tty.init();
    defer term.deinit();
    
    try term.render(("meow,meow." ** (buffer.Width / 10)) ** (buffer.Height));

    const stdin = std.io.getStdIn().reader();
    while (true) {
        var buf: [10]u8 = undefined;
        _ = try stdin.read(&buf);

        var buf2: buffer.Buffer = undefined;
        for (0..(buffer.Width * buffer.Height)) |i| {
            buf2[i] = buf[0];
        }

        try term.render(&buf2);

        if (buf[0] == 10) {
            return;
        }
    }

}