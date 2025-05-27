//Kyoto is a Async Runtime. The name is inspired by Tokio the async runtime library of Rust.
//Kyoto implements async using futures just like in rust.
//TODO: Implement Future Chaining
//TOOD: Implement Awaiting Mulitple Futures

const std = @import("std");
const testing = std.testing;
const Poll = union(enum) {
    Pending,
    Finished: *anyopaque,
};

pub const Future = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    const VTable = struct {
        poll: *const fn (ptr: *anyopaque) Poll,
    };

    pub fn poll(self: Future) Poll {
        return self.vtable.poll(self.ptr);
    }
};

const Self = @This();

allocator: std.mem.Allocator,
futures: std.ArrayList(Future),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .futures = .init(allocator),
    };
}
pub fn schedule(self: *Self, future: Future) !void {
    try self.futures.append(future);
}

pub fn deinit(self: *Self) void {
    self.futures.deinit();
}

fn done(self: *Self) bool {
    return self.futures.items.len == 0;
}

pub fn run(self: *Self) void {
    while (!self.done()) {
        for (self.futures.items, 0..) |future, idx| {
            const res = future.poll();
            switch (res) {
                .Pending => continue,
                .Finished => {
                    _ = self.futures.swapRemove(@min(idx, self.futures.items.len - 1));
                },
            }
        }
    }
}

test "KyotoSimple" {
    const allocator = testing.allocator;
    var kyoto = Self.init(allocator);
    defer kyoto.deinit();

    const Printer = struct {
        value: i64 = 0,

        const SelfP = @This();
        pub fn poll(ctx: *anyopaque) Poll {
            const self: *SelfP = @ptrCast(@alignCast(ctx));
            if (self.value < 10) {
                std.debug.print("Pending: {d}\n", .{self.value});
                self.value += 1;
                return Poll.Pending;
            } else {
                std.debug.print("Finished: {d}\n", .{self.value});
                return Poll{ .Finished = self };
            }
        }

        pub fn future(self: *SelfP) Future {
            return .{
                .ptr = self,
                .vtable = &.{ .poll = SelfP.poll },
            };
        }
    };
    var p = Printer{};
    var p2 = Printer{ .value = -50 };
    try kyoto.schedule(p.future());
    try kyoto.schedule(p2.future());
    kyoto.run();
    try testing.expect(true);
}
