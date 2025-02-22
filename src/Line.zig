
pub const Point = struct { usize, usize };

pub const CollisionTag = enum { edge, vertex };

pub const Collision = union(CollisionTag) {
    edge: [2]Point,
    vertex: struct {
        all_of: [2]Point,
        any_of: [2]Point,
    },
};

pub const Iterator = struct {
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

    pub fn init(start_x: usize, start_y: usize, end_x: usize, end_y: usize) Iterator {
        var iter: Iterator = .{
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

    pub fn next(self: *Iterator) ?Collision {
        if (self.x_index <= self.x_index_end) {
            const y_f = line_x_to_y(self.start_x, self.start_y, self.end_x, self.end_y, @as(f64, @floatFromInt(self.x_index)));
            const x = self.x_index;
            const y = @as(usize, @intFromFloat(@floor(y_f)));

            self.x_index += 1;

            if (@round(y_f) == y_f) {
                return corners(x, y, self.slope);
            } else {
                return Collision{ .edge = [_]Point{
                    .{ x, y },
                    .{ x - 1, y },
                } };
            }
        }

        if (self.y_index <= self.y_index_end) {
            const x_f = line_y_to_x(self.start_x, self.start_y, self.end_x, self.end_y, @floatFromInt(self.y_index));
            const x = @as(usize, @intFromFloat(@floor(x_f)));
            const y = self.y_index;

            self.y_index += 1;

            if (@round(x_f) == x_f) {
                return corners(x, y, self.slope);
            } else {
                return Collision{ .edge = [_]Point{
                    .{ x, y },
                    .{ x, y - 1 },
                } };
            }
        }

        return null;
    }
};

fn corners(x: usize, y: usize, slope: f64) Collision {
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