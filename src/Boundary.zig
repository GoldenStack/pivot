pub const Width = 80;
pub const Height = 24;

pub const Buffer = struct {

    buf: [Width * Height]u8,

    pub fn init() @This() {
        return .{
            .buf = [_]u8{' '} ** (Width * Height),
        };
    }

    pub fn fill(value: u8) @This() {
        var buf = @This().init();

        for (0..(Width * Height)) |i| {
            buf.buf[i] = value;
        }

        return buf;
    }

    pub fn get(self: *const @This(), row: usize, column: usize) u8 {
        return self.buf[row * Width + column];
    }

    pub fn set(self: *@This(), row: usize, column: usize, value: u8) void {
        self.buf[row * Width + column] = value;
    }

};

pub const Key = enum {
    up,
    down,
    left,
    right,
    quit,
};
