const std = @import("std");
const Fstd = @import("FStd");

const Step = enum {
    Hello,
    World,
    Bob,
    Says,
    Hi,
    Count,
};


fn poll(ctx: ?*anyopaque) Fstd.Kyoto.Poll{
    const counter: *usize = @ptrCast(@alignCast(ctx));
    if(counter.* >= @intFromEnum(Step.Count)) return .Killed;
    std.debug.print("{s}\n", .{@tagName(@as(Step, @enumFromInt(counter.*)))});
    counter.* += 1;
    return .{.Finished = ctx};
}

pub fn main() !void{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    //Init kyoto with the allocator and defer deinit
    var kyoto = try Fstd.Kyoto.init(allocator);
    defer kyoto.deinit();

    var counter: usize = 0;

    const fut = try kyoto.newFuture();
    fut.ptr = &counter;
    fut.vtable.poll = poll;
    _ = try kyoto.schedule(fut);

    const sleep = try kyoto.sleep(10000);
    _ = try fut.thenFuture(sleep);
    try sleep.loop(fut);
    try kyoto.run();
}
