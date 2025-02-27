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

    try term.render(&game.output());
    while (game.running) {
        posix.nanosleep(0, @divTrunc(1e9, 60));
        
        while (try term.poll_input()) |key| game.input(key);

        try term.render(&game.output());
    }
}
