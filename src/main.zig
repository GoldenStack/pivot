const std = @import("std");
const buffer = @import("buffer.zig");
const tty = @import("platform/tty.zig");

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {
    const term = try tty.Tty.init();
    defer term.deinit();

    var x: usize = 0;
    var y: usize = 0;

    while (true) {
        const key = try term.blocking_input();
        const slice = key.slice();

        switch (slice[0]) {
            'w' => { if (y > 0) y -= 1; },
            'a' => { if (x > 0) x -= 1; },
            's' => { if (y < buffer.Height - 1) y += 1; },
            'd' => { if (x < buffer.Width - 1) x += 1; },
            else => {},
        }

        var buf = buffer.Buffer.init();
        buf.set(y, x, 'X');
        try term.render(&buf);

        if (slice[0] == 13) {
            return;
        }
    }
}
