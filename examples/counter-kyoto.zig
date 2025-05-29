const std = @import("std");
const FStd = @import("FStd");

const Counter = struct {
    kyoto: *FStd.Kyoto,
    value: usize,
    to: usize,

    pub fn then(ctx: *anyopaque) FStd.Kyoto.Poll {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        std.debug.print("We're done. Yippe!: {d}\n", .{self.value});
        return .{ .Finished = self };
    }

    pub fn then2(ctx: *anyopaque) FStd.Kyoto.Poll {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        std.debug.print("Hello There: {d}\n", .{self.value});
        return .{ .Finished = self };
    }

    pub fn poll(ctx: *anyopaque) FStd.Kyoto.Poll {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        if (self.value < self.to) {
            std.debug.print("Pending: {d}\n", .{self.value});
            self.value += 1;
            return .Pending;
        } else {
            std.debug.print("Finished: {d}\n", .{self.value});
            return .{ .Finished = self };
        }
    }
    pub fn schedule(self: *Counter) !*FStd.Kyoto.Future {
        const fut = try self.kyoto.newFuture();
        fut.ptr = self;
        fut.vtable.poll = Counter.poll;
        return fut;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var kyoto = FStd.Kyoto.init(allocator);
    defer kyoto.deinit();
    var counter1 = Counter{ .value = 0, .to = 10, .kyoto = &kyoto };
    var f = try counter1.schedule();
    f = try f.then(.{ .poll = Counter.then });
    f = try f.then(.{ .poll = Counter.then });
    f = try f.then(.{ .poll = Counter.then });
    f = try f.then(.{ .poll = Counter.then2 });
    f = try f.then(.{ .poll = Counter.then });
    f = try f.then(.{ .poll = Counter.then });
    var counter2 = Counter{ .value = 5, .to = 20, .kyoto = &kyoto };
    f = try counter2.schedule();
    f = try f.then(.{ .poll = Counter.then2 });
    kyoto.run();
}
