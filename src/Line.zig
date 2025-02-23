
pub const Point = struct { usize, usize };

pub const Epsilon: f64 = 1e-6;

pub const CollisionTag = enum { edge, vertex };

pub const Collision = union(CollisionTag) {
    edge: [2]Point,
    vertex: struct {
        all_of: [2]Point,
        any_of: [2]Point,
    },
};

pub const Iterator = struct {
    start_x: f64,
    start_y: f64,
    end_x: f64,
    end_y: f64,

    x_index: usize,
    y_index: usize,

    x_index_start: usize,
    x_index_end: usize,
    y_index_start: usize,
    y_index_end: usize,

    slope: f64,

    pub fn init(start_x: f64, start_y: f64, end_x: f64, end_y: f64) Iterator {
        const x_index_start: usize = @intFromFloat(@ceil(@min(start_x, end_x)));
        const y_index_start: usize = @intFromFloat(@ceil(@min(start_y, end_y)));

        const x_index_end: usize = @intFromFloat(@floor(@max(start_x, end_x)));
        const y_index_end: usize = @intFromFloat(@floor(@max(start_y, end_y)));

        return .{
            .start_x = start_x,
            .start_y = start_y,
            .end_x = end_x,
            .end_y = end_y,

            .x_index_start = x_index_start,
            .y_index_start = y_index_start,
            .x_index_end = x_index_end,
            .y_index_end = y_index_end,

            .x_index = x_index_start,
            .y_index = y_index_start,

            .slope = (end_y - start_y) / (end_x - start_x),
        };
    }

    fn line_y_to_x(self: *const Iterator, y: f64) f64 {
        const slope_y_to_x = (self.end_x - self.start_x) / (self.end_y - self.start_y);

        return self.start_x + (y - self.start_y) * slope_y_to_x;
    }

    fn line_x_to_y(self: *const Iterator, x: f64) f64 {
        const slope_x_to_y = (self.end_y - self.start_y) / (self.end_x - self.start_x);

        return self.start_y + (x - self.start_x) * slope_x_to_y;
    }

    pub fn next(self: *Iterator) ?Collision {
        if (self.x_index <= self.x_index_end) {
            const y_f = self.line_x_to_y(@as(f64, @floatFromInt(self.x_index)));
            const x = self.x_index;
            const y = @as(usize, @intFromFloat(@floor(y_f)));

            self.x_index += 1;

            if (@abs(@round(y_f) - y_f) < Epsilon) {
                return corners(x, y, self.slope);
            } else {
                return Collision{ .edge = [_]Point{
                    .{ x, y },
                    .{ x - 1, y },
                } };
            }
        }

        if (self.y_index <= self.y_index_end) {
            const x_f = self.line_y_to_x(@floatFromInt(self.y_index));
            const x = @as(usize, @intFromFloat(@floor(x_f)));
            const y = self.y_index;

            self.y_index += 1;

            if (@abs(@round(x_f) - x_f) < Epsilon) {
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
