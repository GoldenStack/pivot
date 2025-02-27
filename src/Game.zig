const std = @import("std");
const builtin = @import("builtin");
const Boundary = @import("Boundary.zig");
const Line = @import("Line.zig");

pub const Width = Boundary.Width;
pub const Height = Boundary.Height;

pub const CellTag = enum {
    air,
    wall,
    player,
};

pub const Cell = union(CellTag) {
    air,
    wall: enum {
        side,
        top,
    },
    player,
};

running: bool,

board: [Width * Height]Cell,
player_x: usize,
player_y: usize,

pub fn init() @This() {
    var board: @This() = .{
        .running = true,
        .board = [_]Cell{Cell.air} ** (Width * Height),
        .player_x = 14,
        .player_y = 18,
    };

    board.room(10, 10, 15, 6);
    board.set(10, 11, Cell.air);

    board.set(board.player_x, board.player_y, Cell.player);
    return board;
}

fn room(self: *@This(), x: usize, y: usize, width: usize, height: usize) void {
    for (y..y+height+1) |ry| {
        self.set(x, ry, Cell{ .wall = .side });
        self.set(x + width, ry, Cell{ .wall = .side });
    }

    for (x..x+width+1) |rx| {
        self.set(rx, y, Cell{ .wall = .top });
        self.set(rx, y + height, Cell{ .wall = .top });
    }
}

pub fn get(self: *const @This(), x: usize, y: usize) Cell {
    return self.board[x + Width * y];
}

pub fn set(self: *@This(), x: usize, y: usize, value: Cell) void {
    self.board[x + Width * y] = value;
}

fn add_range(value: usize, add: isize, max: usize) usize {
    if (add < 0) return value -| @as(usize, @intCast(-add)) else return @min(max, value +| @as(usize, @intCast(add)));
}

pub fn input(self: *@This(), key: Boundary.Key) void {
    switch (key) {
        .up => self.move_player(0, -1),
        .down => self.move_player(0, 1),
        .left => self.move_player(-1, 0),
        .right => self.move_player(1, 0),
        .quit => self.running = false,
    }
}

fn move_player(self: *@This(), x: isize, y: isize) void {
    const new_x = add_range(self.player_x, x, Width - 1);
    const new_y = add_range(self.player_y, y, Height - 1);

    if (self.get(new_x, new_y) != Cell.air) return;

    self.set(self.player_x, self.player_y, Cell.air);
    self.set(new_x, new_y, Cell.player);

    self.player_x = new_x;
    self.player_y = new_y;
}

pub fn output(self: *const @This()) Boundary.Buffer {
    const DefaultDisplay = ' ';

    var buf = Boundary.Buffer.init();

    const start = std.time.nanoTimestamp();

    for (0..Width) |x| {
        for (0..Height) |y| {
            var value: u8 = switch (self.get(x, y)) {
                .air => ' ',
                .wall => |value| switch (value) {
                    .side => '|',
                    .top => '-',
                },
                .player => 'X',
            };

            if (value != DefaultDisplay and detect_collision_greedy_rasterize(self, self.player_x, self.player_y, x, y)) {
                value = DefaultDisplay;
            }

            buf.set(y, x, value);
        }
    }

    const duration = std.time.nanoTimestamp() - start;
    std.debug.print("{d:.3}ms\r\n", .{(@as(f64, @floatFromInt(duration))) / 1e6});
    
    return buf;
}

fn detect_collision_greedy_rasterize(self: *const @This(), start_x: usize, start_y: usize, end_x: usize, end_y: usize) bool {
    if (start_x == end_x and start_y == end_y) return false;

    var iter = Line.Iterator.init(
        @as(f64, @floatFromInt(start_x)) + 0.5, @as(f64, @floatFromInt(start_y)) + 0.5,
        @as(f64, @floatFromInt(end_x)) + 0.5, @as(f64, @floatFromInt(end_y)) + 0.5
    );

    while (iter.next()) |item| {
        switch (item) {
            .edge => |points| {
                for (points) |point| {
                    if (point[0] == start_x and point[1] == start_y) continue;
                    if (point[0] == end_x and point[1] == end_y) continue;

                    if (self.get(point[0], point[1]) != Cell.air) return true;
                }
            },
            .vertex => |vertex| {
                for (vertex.all_of) |point| {
                    if (point[0] == start_x and point[1] == start_y) continue;
                    if (point[0] == end_x and point[1] == end_y) continue;

                    if (self.get(point[0], point[1]) != Cell.air) return true;
                }
                block: {
                    for (vertex.any_of) |point| {
                        if (point[0] == start_x and point[1] == start_y) continue;
                        if (point[0] == end_x and point[1] == end_y) continue;

                        if (self.get(point[0], point[1]) == Cell.air) break :block;
                    }

                    return true;
                }
            },
        }
    }

    return false;
}
