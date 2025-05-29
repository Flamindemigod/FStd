//Kyoto is a Async Runtime. The name is inspired by Tokio the async runtime library of Rust.
//Kyoto implements async using futures just like in rust.
//TODO: Implement Awaiting Mulitple Futures

const std = @import("std");
const testing = std.testing;
pub const Poll = union(enum) {
    Pending,
    Finished: *anyopaque,
};

pub const Future = struct {
    kyoto: *Self,
    ptr: ?*anyopaque = null,
    thenFut: ?*Future = null,
    vtable: VTable,
    const VTable = struct {
        poll: *const fn (ptr: *anyopaque) Poll,
    };

    pub fn poll(self: *const Future) Poll {
        return self.vtable.poll(self.ptr.?);
    }

    // pub fn then(self: *Future) *Future {
    pub fn then(self: *Future, thenFn: VTable) !*Future {
        const fut = try self.kyoto.newFuture();
        fut.vtable = thenFn;
        self.thenFut = fut;
        return fut;
    }
};

const Self = @This();

allocator: std.mem.Allocator,
futures: std.ArrayList(*Future),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .futures = .init(allocator),
    };
}

//Allocates a Future on the heap and returns a pointer to it.
//Prevents having to allocate them on the stack and the stack being cleared after the end of scope
//Zig currently has a bug where the stack isnt being cleared
//https://github.com/ziglang/zig/issues/23475
//So the stack allocation behaviour works but not necessarily in the future
//In theory Kyoto.schedule copies the future from the stack to the heap. but i've faced a lot of bugs where
//addresses seem to colide when chaining futures. mostly because the next future pointed to the stack.
//So preallocating on the heap should mitigate the issue.
pub fn newFuture(self: *Self) !*Future {
    const fut = try self.allocator.create(Future);
    try self.futures.append(fut);
    fut.kyoto = self;
    fut.ptr = null;
    fut.thenFut = null;
    return fut;
}

pub fn schedule(self: *Self, future: Future) !void {
    _ = self;
    _ = future;
    @compileError("Using schedule is deprecated Use 'Kyoto.newFuture' instead");
    //try self.futures.append(future);
}

pub fn deinit(self: *Self) void {
    for (self.futures.items) |future| {
        self.allocator.destroy(future);
    }
    self.futures.deinit();
}

fn done(self: *Self) bool {
    return self.futures.items.len == 0;
}

pub fn run(self: *Self) void {
    while (!self.done()) {
        for (self.futures.items, 0..) |future, idx| {
            if (future.ptr == null) continue;
            const res = future.poll();
            switch (res) {
                .Pending => continue,
                .Finished => |ptr| {
                    const fut = self.futures.swapRemove(@min(idx, self.futures.items.len - 1));
                    if (fut.thenFut) |thenFut| thenFut.ptr = ptr;
                    self.allocator.destroy(fut);
                },
            }
        }
    }
}
