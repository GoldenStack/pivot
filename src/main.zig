const std = @import("std");
const Buffer = @import("Buffer.zig");
const Tty = @import("platform/Tty.zig");
const Game = @import("Game.zig");

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {
    const term = try Tty.init();
    defer term.deinit();

    var game = Game.init();

    try term.render(&game.compose());
    while (true) {
        const key = try term.blocking_input();
        const slice = key.slice();

        if (slice.len == 1) switch (slice[0]) {
            'w', 'k', => game.move_player(0, -1),
            'a', 'h' => game.move_player(-1, 0),
            's', 'j' => game.move_player(0, 1),
            'd', 'l' => game.move_player(1, 0),
            13 => return,
            else => {},
        };

        const cc1 = slice.len == 3 and std.mem.eql(u8, slice[0..2], &[_]u8{27, 91});

        if (cc1) switch (slice[slice.len-1]) {
            65 => game.move_player(0, -1),
            68 => game.move_player(-1, 0),
            66 => game.move_player(0, 1),
            67 => game.move_player(1, 0),
            else => {},
        };

        try term.render(&game.compose());
    }
}
