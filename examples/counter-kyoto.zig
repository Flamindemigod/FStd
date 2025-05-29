const std = @import("std");
const FStd = @import("FStd");

const Counter = struct {
    value: usize,
    to: usize,

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
    pub fn future(self: *Counter) FStd.Kyoto.Future {
        return .{ .ptr = self, .vtable = &.{ .poll = Counter.poll } };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var kyoto = FStd.Kyoto.init(allocator);
    defer kyoto.deinit();
    var counter1 = Counter{ .value = 0, .to = 10 };
    try kyoto.schedule(counter1.future());
    var counter2 = Counter{ .value = 5, .to = 20 };
    try kyoto.schedule(counter2.future());
    kyoto.run();
}
