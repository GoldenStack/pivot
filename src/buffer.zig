pub const Width = 80;
pub const Height = 24;

pub const Buffer = struct {
    buf: [Width * Height]u8,

    pub fn init() Buffer {
        return .{
            .buf = [_]u8{0} ** (Width * Height),
        };
    }

    pub fn fill(value: u8) Buffer {
        var buf = Buffer.init();

        for (0..(Width * Height)) |i| {
            buf.buf[i] = value;
        }

        return buf;
    }

    pub fn get(self: *const Buffer, row: usize, column: usize) u8 {
        return self.buf[row * Width + column];
    }

    pub fn set(self: *Buffer, row: usize, column: usize, value: u8) void {
        self.buf[row * Width + column] = value;
    }
};
