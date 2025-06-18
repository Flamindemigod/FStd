const std = @import("std");
const builtin = @import("builtin");
const Temp = @This();
_path: [255]u8,
_path_len: usize,
fd: std.fs.File,

pub fn create() !Temp {
    var buf: [255]u8 = undefined;
    const pid = switch (builtin.os.tag) {
        .linux => std.os.linux.getpid(),
        .windows => std.os.windows.GetCurrentProcessId(),
        else => {
            unreachable;
        },
    };
    const p = try std.fmt.bufPrint(&buf, "/tmp/FStd.Temp.{d}.{d}", .{ pid, std.crypto.random.int(i64) });
    return .{
        ._path = buf,
        ._path_len = p.len,
        .fd = try std.fs.createFileAbsolute(p, .{
            .exclusive = true,
            .lock = .exclusive,
            .read = true,
        }),
    };
}

pub fn path(self: *Temp)[]const u8{
    return self._path[0..self._path_len];
}

pub fn destroy(self: *Temp) void {
    self.fd.close();
    std.fs.deleteFileAbsolute(self.path()) catch {};
}

test "TempRW" {
    const testing = std.testing;
    {
        var temp = try Temp.create();
        defer temp.destroy();
        var buf: [255]u8 = undefined;
        try temp.fd.writeAll("Hello there. This is a test of making a temp file in zigland\n");
        try temp.fd.seekTo(0);
        while (try temp.fd.readAll(&buf) > 0) {} //std.debug.print("{s}", .{buf});
        try testing.expect(true);
    }
}
