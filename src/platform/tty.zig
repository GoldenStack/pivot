const std = @import("std");
const posix = std.posix;
const buffer = @import("../buffer.zig");

// Copy pasted from ziglibs/ansi-term
const esc = "\x1B";
const csi = esc ++ "[";

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

        attr.iflag.IXON = false; // Disable flow control

        attr.lflag.ECHO = false; // Disable input cahracters being echoed
        attr.lflag.ICANON = false; // Disable canonical (line-buffered) mode
        attr.lflag.ISIG = false; // Get raw input by disabling signals

        attr.cflag.CSIZE = .CS8; // Set the character mask to 8 bits

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
        try stdout.writeAll(csi ++ "2J");

        // Write each row, separated with newlines
        for (0..buffer.Height) |row| {
            const start = row * buffer.Width;
            try stdout.writeAll(buf[start..start + buffer.Width]);
            
            if (row < buffer.Height - 1) {
                try stdout.writeAll("\n");
            }
        }
    }

};