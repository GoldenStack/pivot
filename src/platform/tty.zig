const std = @import("std");
const posix = std.posix;
const buffer = @import("../buffer.zig");

const Break = "\r\n";

// Copy pasted from ziglibs/ansi-term
const Esc = "\x1B";
const Csi = Esc ++ "[";

/// A platform that renders to a terminal. This assumes ANSI escape codes work
/// for escaping and that termios actually works on this platform.
/// Libvaxis source code was referenced while making this.
pub const Tty = struct {

    fd: posix.fd_t,
    previous_attributes: posix.termios,

    pub fn init() !Tty {
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

        // Always block to read, with no timeout
        attr.cc[@intFromEnum(posix.V.TIME)] = 0;
        attr.cc[@intFromEnum(posix.V.MIN)] = 1;

        // Write the new attributes
        try posix.tcsetattr(fd, .FLUSH, attr);

        // Try enabling ANSI for screen clears
        const stdout = std.io.getStdOut();
        _ = stdout.getOrEnableAnsiEscapeSupport();
        
        const tty: Tty = .{
            .fd = fd,
            .previous_attributes = previous_attributes,
        };

        // Initial screen clear
        try tty.render(" " ** (buffer.Width * buffer.Height));

        return tty;
    }

    pub fn deinit(self: Tty) void {
        // Try to restore previous attributes
        posix.tcsetattr(self.fd, .FLUSH, self.previous_attributes) catch |err| {
            std.log.err("could not revert to previous terminal attributes: {}", .{err});
        };
        
        // Close the file handler
        posix.close(self.fd);
    }

    /// Renders the screen buffer for this platform.
    pub fn render(_: *const Tty, buf: *const buffer.Buffer) !void {
        const stdout = std.io.getStdOut();

        // Clear the screen
        try stdout.writeAll(Csi ++ "2J" ++ Break);

        // Write each row, separated with newlines
        for (0..buffer.Height) |row| {
            const start = row * buffer.Width;
            try stdout.writeAll(buf[start..start + buffer.Width]);
            
            if (row < buffer.Height - 1) {
                try stdout.writeAll(Break);
            }
        }
    }

    pub fn blocking_input(_: Tty) ![]u8 {
        const stdin = std.io.getStdIn().reader();
       
        var buf: [16]u8 = undefined;
        const len = try stdin.read(&buf);

        return buf[0..len];
    }

};