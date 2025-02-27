//! A platform that renders to a terminal. This assumes ANSI escape codes work
//! for escaping and that termios actually works on this platform.
//! Libvaxis source code was referenced while making this.

const std = @import("std");
const posix = std.posix;
const Boundary = @import("../Boundary.zig");

const Break = "\r\n";

// Copy pasted from ziglibs/ansi-term
const Esc = "\x1B";
const Csi = Esc ++ "[";


fd: posix.fd_t,
previous_attributes: posix.termios,

pub fn init() !@This() {
    const fd: posix.fd_t = try posix.open("/dev/tty", .{ .ACCMODE = .RDWR }, 0);

    const previous_attributes = try posix.tcgetattr(fd);
    var attr = previous_attributes;

    // Raw mode, per the manpage
    attr.iflag.IGNBRK = false;
    attr.iflag.BRKINT = false;
    attr.iflag.PARMRK = false;
    attr.iflag.ISTRIP = false;
    attr.iflag.INLCR = false;
    attr.iflag.IGNCR = false;
    attr.iflag.ICRNL = false;
    attr.iflag.IXON = false;

    attr.oflag.OPOST = false;

    attr.lflag.ECHO = false;
    attr.lflag.ECHONL = false;
    attr.lflag.ICANON = false;
    attr.lflag.ISIG = false;
    attr.lflag.IEXTEN = false;
    
    attr.cflag.PARENB = false;
    attr.cflag.CSIZE = .CS8;

    // Polling read that instantly returns
    attr.cc[@intFromEnum(posix.V.TIME)] = 0;
    attr.cc[@intFromEnum(posix.V.MIN)] = 0;

    // Write the new attributes
    try posix.tcsetattr(fd, .FLUSH, attr);

    // Try enabling ANSI for screen clears
    const stdout = std.io.getStdOut();
    _ = stdout.getOrEnableAnsiEscapeSupport();
    
    const tty: @This() = .{
        .fd = fd,
        .previous_attributes = previous_attributes,
    };

    // Initial screen clear
    try tty.render(&Boundary.Buffer.fill(' '));

    return tty;
}

pub fn deinit(self: @This()) void {
    // Try to restore previous attributes
    posix.tcsetattr(self.fd, .FLUSH, self.previous_attributes) catch |err| {
        std.log.err("could not revert to previous terminal attributes: {}", .{err});
    };
    
    // Close the file handler
    posix.close(self.fd);
}

/// Renders the screen buffer for this platform.
pub fn render(_: *const @This(), buf: *const Boundary.Buffer) !void {
    const stdout = std.io.getStdOut();

    // Clear the screen
    try stdout.writeAll(Csi ++ "2J" ++ Break);

    // Write each row, separated with newlines
    for (0..Boundary.Height) |row| {
        const start = row * Boundary.Width;
        try stdout.writeAll(buf.buf[start..start + Boundary.Width]);
        
        if (row < Boundary.Height - 1) {
            try stdout.writeAll(Break);
        }
    }
}

pub fn poll_input(_: @This()) !?Boundary.Key {
    const stdin = std.io.getStdIn().reader();

    // TODO: Ring buffer
    var buf: [64]u8 = undefined;
    const len = try stdin.read(&buf);

    if (len != 0)
    std.debug.print("{any} {any}\r\n", .{len, buf});

    // TODO: Does not handle the possibility of multiple keys in one frame
    const slice = buf[0..len];

    if (slice.len == 1) switch (slice[0]) {
        'w', 'k', => return Boundary.Key.up,
        'a', 'h' => return Boundary.Key.left,
        's', 'j' => return Boundary.Key.down,
        'd', 'l' => return Boundary.Key.right,
        'q' => return Boundary.Key.quit,
        else => {},
    };

    const cc1 = slice.len == 3 and std.mem.eql(u8, slice[0..2], &[_]u8{27, 91});

    if (cc1) switch (slice[slice.len-1]) {
        65 => return Boundary.Key.up,
        68 => return Boundary.Key.left,
        66 => return Boundary.Key.down,
        67 => return Boundary.Key.right,
        else => {},
    };

    return null;

}
