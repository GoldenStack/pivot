const std = @import("std");
const buffer = @import("buffer.zig");
const tty = @import("platform/tty.zig");
const Game = @import("game.zig").Game;

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {
    const term = try tty.Tty.init();
    defer term.deinit();

    var game = Game.init();

    try term.render(&game.compose());
    while (true) {
        const key = try term.blocking_input();
        const slice = key.slice();

        switch (slice[0]) {
            'w' => game.move_player(0, -1),
            'a' => game.move_player(-1, 0),
            's' => game.move_player(0, 1),
            'd' => game.move_player(1, 0),
            else => {},
        }

        try term.render(&game.compose());

        if (slice[0] == 13) {
            return;
        }
    }
}
