const std = @import("std");
const buffer = @import("buffer.zig");

pub const Cell = enum {
    Air,
    Wall,
    Player,
};

pub const Game = struct {
    board: [buffer.Width * buffer.Height]Cell,
    player_x: usize,
    player_y: usize,

    pub fn init() Game {
        var board: Game = .{
            .board = [_]Cell{Cell.Air} ** (buffer.Width * buffer.Height),
            .player_x = 0,
            .player_y = 0,
        };

        for (0..buffer.Width) |x| {
            for (0..buffer.Height) |y| {
                board.board[x + y * buffer.Width] = if (std.crypto.random.int(u2) == 0)
                    Cell.Wall
                else
                    Cell.Air;
            }
        }

        board.board[0] = Cell.Player;

        return board;
    }

    fn add_range(value: usize, add: isize, max: usize) usize {
        if (add < 0) return value -| @as(usize, @intCast(-add))
        else return @min(max, value +| @as(usize, @intCast(add)));
    }

    pub fn move_player(self: *Game, x: isize, y: isize) void {
        const new_x = add_range(self.player_x, x, buffer.Width - 1);
        const new_y = add_range(self.player_y, y, buffer.Height - 1);
        
        if (self.board[new_x + new_y * buffer.Width] != Cell.Air) return;

        self.board[self.player_x + self.player_y * buffer.Width] = Cell.Air;
        self.board[new_x + new_y * buffer.Width] = Cell.Player;

        self.player_x = new_x;
        self.player_y = new_y;
    }

    pub fn compose(self: *const Game) buffer.Buffer {
        var buf = buffer.Buffer.init();

        for (0..buffer.Width) |x| {
            for (0..buffer.Height) |y| {
                const value: u8 = switch (self.board[x + y * buffer.Width]) {
                    .Air => ' ',
                    .Wall => '#',
                    .Player => 'X',
                };

                buf.set(y, x, value);
            }
        }

        return buf;
    }
};
