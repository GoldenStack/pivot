const std = @import("std");
const Buffer = @import("Buffer.zig");

pub const Width = Buffer.Width;
pub const Height = Buffer.Height;

pub const Cell = enum {
    Air,
    Wall,
    Player,
};

board: [Width][Height]Cell,
player_x: usize,
player_y: usize,

pub fn init() @This() {
    var board: @This() = .{
        .board = [_][Height]Cell{[_]Cell{Cell.Air} ** Height} ** Width,
        .player_x = 0,
        .player_y = 0,
    };

    for (0..Width) |x| {
        for (0..Height) |y| {
            const cell = if (std.crypto.random.int(u2) == 0)
                Cell.Wall
            else
                Cell.Air;

            board.set(x, y, cell);
        }
    }

    board.set(0, 0, Cell.Player);
    return board;
}

pub fn get(self: *const @This(), x: usize, y: usize) Cell {
    return self.board[x][y];
}

pub fn set(self: *@This(), x: usize, y: usize, value: Cell) void {
    self.board[x][y] = value;
}

fn add_range(value: usize, add: isize, max: usize) usize {
    if (add < 0) return value -| @as(usize, @intCast(-add))
    else return @min(max, value +| @as(usize, @intCast(add)));
}

pub fn move_player(self: *@This(), x: isize, y: isize) void {
    const new_x = add_range(self.player_x, x, Width - 1);
    const new_y = add_range(self.player_y, y, Height - 1);
    
    if (self.get(new_x, new_y) != Cell.Air) return;

    self.set(self.player_x, self.player_y, Cell.Air);
    self.set(new_x, new_y, Cell.Player);

    self.player_x = new_x;
    self.player_y = new_y;
}

pub fn compose(self: *const @This()) Buffer {
    var buf = Buffer.init();

    for (0..Width) |x| {
        for (0..Height) |y| {
            const value: u8 = switch (self.get(x, y)) {
                .Air => ' ',
                .Wall => '#',
                .Player => 'X',
            };

            buf.set(y, x, value);
        }
    }

    return buf;
}
