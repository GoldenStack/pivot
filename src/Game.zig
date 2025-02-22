const std = @import("std");
const builtin = @import("builtin");
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

pub const Point = struct { usize, usize };

board: [Width * Height]Cell,
player_x: usize,
player_y: usize,

pub fn init() @This() {
    var board: @This() = .{
        .board = [_]Cell{Cell.air} ** (Width * Height),
        .player_x = 14,
        .player_y = 18,
    };

    board.room(10, 10, 15, 6);
    // board.set(10, 11, Cell.air);

    board.set(board.player_x, board.player_y, Cell.player);
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
    if (add < 0) return value -| @as(usize, @intCast(-add)) else return @min(max, value +| @as(usize, @intCast(add)));
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

    const light = self.fov_naive(self.player_x, self.player_y);

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

fn convert(items: [Width * Height]u2) [Width * Height]bool {
    var out = [_]bool{false} ** (Width * Height);
    for (0.., items) |index, value| {
        if (builtin.mode == std.builtin.OptimizeMode.Debug and value == 0) {
            // std.debug.print("Failed to determine FOV status for index {any}\r\n", .{index});
            // @panic("Did not determine in-FOV status for entire screen!");
        }
        out[index] = value == 2;
    }
    return out;
}

pub const CollisionTag = enum { edge, vertex };

pub const Collision = union(CollisionTag) {
    edge: [2]Point,
    vertex: struct {
        all_of: [2]Point,
        any_of: [2]Point,
    },
};

const LineIterator = struct {
    start_x: usize,
    start_y: usize,
    end_x: usize,
    end_y: usize,

    x_index: usize,
    y_index: usize,

    x_index_start: usize,
    x_index_end: usize,
    y_index_start: usize,
    y_index_end: usize,

    slope: f64,

    fn init(start_x: usize, start_y: usize, end_x: usize, end_y: usize) LineIterator {
        var iter: LineIterator = .{
            .start_x = start_x,
            .start_y = start_y,
            .end_x = end_x,
            .end_y = end_y,

            .x_index_start = @min(start_x, end_x),
            .y_index_start = @min(start_y, end_y),
            .x_index_end = @max(start_x, end_x),
            .y_index_end = @max(start_y, end_y),

            .x_index = start_x,
            .y_index = start_y,

            .slope = slope: {
                const ox_f = @as(f64, @floatFromInt(start_x)) + 0.5;
                const oy_f = @as(f64, @floatFromInt(start_y)) + 0.5;

                const px_f = @as(f64, @floatFromInt(end_x)) + 0.5;
                const py_f = @as(f64, @floatFromInt(end_y)) + 0.5;

                break :slope (px_f - ox_f) / (py_f - oy_f);
            },
        };

        // Ignore the lowest value. This is done because we are technically
        // considering cells from their centers but the coordinates refer to
        // their top left corner. This means that we have to exclude the cells
        // that have their top lefts not in the line we're casting. Since the
        // largest X and Y values are supposed to be considered in the line, we
        // include them, so we solely care about the smallest x and y values.
        iter.x_index_start += 1;
        iter.y_index_start += 1;

        iter.x_index = iter.x_index_start;
        iter.y_index = iter.y_index_start;

        return iter;
    }

    fn next(self: *LineIterator) ?Collision {
        if (self.x_index <= self.x_index_end and false) {
            const y_f = line_x_to_y(self.start_x, self.start_y, self.end_x, self.end_y, @as(f64, @floatFromInt(self.x_index)));
            const x = self.x_index;

            self.x_index += 1;

            return collision(x, y_f, self.slope);
        }

        if (self.y_index <= self.y_index_end) {
            const x_f = line_y_to_x(self.start_x, self.start_y, self.end_x, self.end_y, @floatFromInt(self.y_index));
            const y = self.y_index;

            self.y_index += 1;

            return collision(y, x_f, self.slope);
        }

        return null;
    }
};


fn collision(x: usize, y_f: f64, slope: f64) Collision {
    const y = @as(usize, @intFromFloat(@floor(y_f)));

    if (@round(y_f) == y_f) {
        const corners_pos = [_]Point{
            .{ x - 1, y },
            .{ x, y - 1 },
        };

        const corners_neg = [_]Point{
            .{ x - 1, y - 1 },
            .{ x, y },
        };

        if (slope > 0) {
            return Collision{ .vertex = .{
                .all_of = corners_neg,
                .any_of = corners_pos,
            } };
        } else {
            return Collision{ .vertex = .{
                .all_of = corners_pos,
                .any_of = corners_neg,
            } };
        }
    } else {
        return Collision{ .edge = [_]Point{
            .{ x, y - 1 }
        } };
    }
}

fn line_y_to_x(ox: usize, oy: usize, px: usize, py: usize, y: f64) f64 {
    const ox_f = @as(f64, @floatFromInt(ox)) + 0.5;
    const oy_f = @as(f64, @floatFromInt(oy)) + 0.5;

    const px_f = @as(f64, @floatFromInt(px)) + 0.5;
    const py_f = @as(f64, @floatFromInt(py)) + 0.5;

    const slope = (px_f - ox_f) / (py_f - oy_f);

    return ox_f + (y - oy_f) * slope;
}

fn line_x_to_y(ox: usize, oy: usize, px: usize, py: usize, x: f64) f64 {
    // Simply flip coordinates
    return line_y_to_x(oy, ox, py, px, x);
}

pub fn fov_naive(self: *const @This(), x: usize, y: usize) [Width * Height]bool {
    // 0 = unchecked
    // 1 = not in FOV
    // 2 = in FOV
    var items = [_]u2{0} ** (Width * Height);
    items[x + y * Width] = 2;
    items[10 + 14 * Width] = 2;

    var iter = LineIterator.init(x, y, 10, 14);
    while (iter.next()) |item| {
        switch (item) {
            .edge => |edge| {
                for (edge) |edge3| {
                    items[edge3[0] + edge3[1] * Width] = 2;
                }
            },
            .vertex => |vertex| {
                for (vertex.all_of) |edge3| {
                    items[edge3[0] + edge3[1] * Width] = 2;
                }
                for (vertex.any_of) |edge3| {
                    items[edge3[0] + edge3[1] * Width] = 2;
                }
            },
        }
    }

    if (true) return convert(items);

    for (0..Width) |cx| {
        nextcell: for (0..Height) |cy| {
            if (cx != x) for (@min(cx, x)+1..@max(cx, x)) |nx| {
                const ny_f = line_x_to_y(x, y, cx, cy, @floatFromInt(nx));
                const ny = @as(usize, @intFromFloat(@floor(ny_f)));

                if (self.get(nx, ny) != Cell.air or (nx - 1 != @min(cx, x) and self.get(nx - 1, ny) != Cell.air)) {
                    items[cx + cy * Width] = 1;
                    continue :nextcell;
                }
            };

            if (cy != y) for (@min(cy, y)+1..@max(cy, y)) |ny| {
                const nx_f = line_y_to_x(x, y, cx, cy, @floatFromInt(ny));
                const nx = @as(usize, @intFromFloat(@floor(nx_f)));

                if (self.get(nx, ny) != Cell.air or (ny - 1 != @min(cy, y) and self.get(nx, ny - 1) != Cell.air)) {
                    items[cx + cy * Width] = 1;
                    continue :nextcell;
                }
            };

            items[cx + cy * Width] = 2;
        }
    }

    return convert(items);
}
