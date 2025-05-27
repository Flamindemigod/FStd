//Kyoto is a Async Runtime. The name is inspired by Tokio the async runtime library of Rust.
//Kyoto implements async using futures just like in rust.
//TODO: Implement Future Chaining
//TOOD: Implement Awaiting Mulitple Futures

const std = @import("std");
const testing = std.testing;
pub const Poll = union(enum) {
    Pending,
    Finished: *anyopaque,
};

pub const Future = struct {
    ptr: ?*anyopaque,
    nextFuture: ?*Future = null,
    vtable: *const VTable,
    kyoto: ?*Self = null,
    const VTable = struct {
        poll: *const fn (ptr: *anyopaque) Poll,
    };

    fn setThen(base: *Future, nextFuture: *Future) void {
        if (base.nextFuture != null) {
            setThen(base.nextFuture.?, nextFuture);
        } else {
            base.nextFuture = nextFuture;
        }
    }

    pub fn then(self: *Future, nextFuture: Future) !void {
        const c = try self.kyoto.?.createFuture();
        c.* = nextFuture;
        Future.setThen(self, c);
    }
    pub fn poll(self: Future) Poll {
        return self.vtable.poll(self.ptr.?);
    }
};

const Self = @This();

allocator: std.mem.Allocator,
futures: std.ArrayList(Future),
createdFutures: std.ArrayListUnmanaged(Future),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .futures = .init(allocator),
        .createdFutures = .{},
    };
}

pub fn createFuture(self: *Self) !*Future {
    return try self.createdFutures.addOne(self.allocator);
}

pub fn schedule(self: *Self, future: Future) !*Future {
    try self.futures.append(future);
    const v = &self.futures.items[self.futures.items.len - 1];
    v.kyoto = self;
    return v;
}

pub fn deinit(self: *Self) void {
    self.createdFutures.deinit(self.allocator);
    self.futures.deinit();
}

fn done(self: *Self) bool {
    return self.futures.items.len == 0;
}

pub fn run(self: *Self) !void {
    while (!self.done()) {
        for (self.futures.items, 0..) |future, idx| {
            const res = future.poll();
            switch (res) {
                .Pending => continue,
                .Finished => |ptr| {
                    _ = self.futures.swapRemove(@min(idx, self.futures.items.len - 1));
                    if (future.nextFuture) |f| {
                        const nf = Future{
                            .ptr = ptr,
                            .vtable = f.vtable,
                            .nextFuture = f.nextFuture,
                        };
                        _ = try self.schedule(nf);
                    }
                },
            }
        }
    }
}
