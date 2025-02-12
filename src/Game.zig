const std = @import("std");
const Buffer = @import("Buffer.zig");

pub const Width = Buffer.Width;
pub const Height = Buffer.Height;

pub const CellTag = enum {
    air,
    wall,
    player,
};

pub const Wall = enum {
    side,
    top,
};

pub const Cell = union(CellTag) {
    air,
    wall: Wall,
    player,
};

board: [Width * Height]Cell,
player_x: usize,
player_y: usize,

pub fn init() @This() {
    var board: @This() = .{
        .board = [_]Cell{Cell.air} ** (Width * Height),
        .player_x = 0,
        .player_y = 0,
    };

    board.room(10, 10, 15, 6);

    board.set(0, 0, Cell.player);
    return board;
}

fn room(self: *@This(), x: usize, y: usize, width: usize, height: usize) void {
    for (y..y+height+1) |ry| {
        self.set(x, ry, Cell{ .wall = Wall.side });
        self.set(x + width, ry, Cell{ .wall = Wall.side });
    }

    for (x..x+width+1) |rx| {
        self.set(rx, y, Cell{ .wall = Wall.top });
        self.set(rx, y + height, Cell{ .wall = Wall.top });
    }
}

pub fn get(self: *const @This(), x: usize, y: usize) Cell {
    return self.board[x + Width * y];
}

pub fn set(self: *@This(), x: usize, y: usize, value: Cell) void {
    self.board[x + Width * y] = value;
}

fn add_range(value: usize, add: isize, max: usize) usize {
    if (add < 0) return value -| @as(usize, @intCast(-add))
    else return @min(max, value +| @as(usize, @intCast(add)));
}

pub fn move_player(self: *@This(), x: isize, y: isize) void {
    const new_x = add_range(self.player_x, x, Width - 1);
    const new_y = add_range(self.player_y, y, Height - 1);
    
    if (self.get(new_x, new_y) != Cell.air) return;

    self.set(self.player_x, self.player_y, Cell.air);
    self.set(new_x, new_y, Cell.player);

    self.player_x = new_x;
    self.player_y = new_y;
}

pub fn compose(self: *const @This()) Buffer {
    var buf = Buffer.init();

    const light = self.trace_light(self.player_x, self.player_y);

    for (0..Width) |x| {
        for (0..Height) |y| {
            const value: u8 = if (light[x + y * Width]) switch (self.get(x, y)) {
                .air => ' ',
                .wall => |value| switch (value) {
                    .side => '|',
                    .top => '-',
                },
                .player => 'X',
            } else ' ';

            buf.set(y, x, value);
        }
    }

    return buf;
}

pub fn trace_light(self: *const @This(), x: usize, y: usize) [Width * Height]bool {
    var items = [_]bool{true} ** (Width * Height);

    for (0..Width) |cx| {
        for (0..Height) |cy| {
            const distance = std.math.hypot(
                @as(f32, @floatFromInt(x)) - @as(f32, @floatFromInt(cx)),
                @as(f32, @floatFromInt(y)) - @as(f32, @floatFromInt(cy))
            );
            items[cx + cy * Width] = distance < 5;
        }
    }
    _ = self;

    return items;
}