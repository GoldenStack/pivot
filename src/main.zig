const std = @import("std");
const Boundary = @import("Boundary.zig");
const Tty = @import("platform/Tty.zig");
const Game = @import("Game.zig");

const posix = std.posix;
const termios = std.posix.termios;

pub fn main() !void {
    const term = try Tty.init();
    defer term.deinit();

    var game = Game.init();

    while (game.running) {
        try term.render(&game.output());

        posix.nanosleep(0, @divTrunc(1e9, 60));
        
        while (try term.poll_input()) |key| game.input(key);
    }
}
