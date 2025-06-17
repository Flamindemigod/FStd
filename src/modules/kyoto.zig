//Kyoto is a Async Runtime. The name is inspired by Tokio the async runtime library of Rust.
//Kyoto implements async using futures just like in rust.
//TODO: Implement Awaiting Mulitple Futures

const std = @import("std");
const a = @import("Arboroboros.zig");
const Arb = a.Arboroboros;
const Node = a.Node;
const testing = std.testing;
pub const Poll = union(enum) {
    Pending,
    Finished: ?*anyopaque,
    //.Killed causes the runtime to terminate
    Killed,
};

pub const Future = struct {
    kyoto: *Self,
    ptr: ?*anyopaque = null,
    vtable: VTable,
    const VTable = struct {
        poll: *const fn (ptr: ?*anyopaque) Poll,
        handover: ?*const fn (ptr: ?*anyopaque, prev_ptr: ?*anyopaque) void,
        destroy: ?*const fn (ptr: ?*anyopaque) void,
        reset: ?*const fn (ptr: ?*anyopaque) void,

        pub fn init(self: *VTable) void {
            self.handover = null;
            self.destroy = null;
            self.reset = null;
        }
    };

    pub fn poll(self: *const Future) Poll {
        return self.vtable.poll(self.ptr);
    }

    pub fn reset(self: *Future) void {
        if (self.vtable.reset) |resetFn| return resetFn(self.ptr);
    }

    pub fn destroy(self: *Future) void {
        if (self.vtable.destroy) |destroyFn| return destroyFn(self.ptr);
    }

    pub fn handover(self: *Future, prev_ptr: ?*anyopaque) void {
        if (self.vtable.handover) |handoverFn| return handoverFn(self.ptr, prev_ptr);
        if (self.ptr == null) self.ptr = prev_ptr;
    }

    // pub fn then(self: *Future) *Future {
    pub fn then(self: *Future, thenFn: *const fn (ptr: ?*anyopaque) Poll) !*Future {
        const fut = try self.kyoto.newFuture();
        fut.vtable.poll = thenFn;
        if (self.kyoto.futures.findNode(self)) |node| {
            _ = try self.kyoto.futures.insertNode(node, fut);
            return fut;
        }
        return error.BaseFutureNotScheduled;
    }

    pub fn thenFuture(self: *Future, fut: *Future) !*Future {
        if (self.kyoto.futures.findNode(self)) |node| {
            _ = try self.kyoto.futures.insertNode(node, fut);
            return fut;
        }
        return error.BaseFutureNotScheduled;
    }

    pub fn loop(loopTail: *Future, loopHead: *Future) !void {
        if (loopTail.kyoto.futures.findNode(loopHead)) |nodeHead| {
            if (loopTail.kyoto.futures.findNode(loopTail)) |nodeTail| {
                try nodeTail.insertParent(nodeHead);
                try nodeTail.insertBranch(nodeHead);
                return;
            }
        }
        return error.BaseFutureNotScheduled;
    }
};

const Self = @This();
allocator: std.mem.Allocator,
futures: Arb(*Future),

pub fn init(allocator: std.mem.Allocator) !Self {
    const root_fut = try allocator.create(Future);
    root_fut.vtable.init();
    return .{
        .allocator = allocator,
        .futures = try .init(allocator, root_fut),
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
    fut.kyoto = self;
    fut.ptr = null;
    fut.vtable.init();
    return fut;
}

pub fn newFutureNode(self: *Self) !*Node(*Future) {
    const fut = try self.allocator.create(Future);
    fut.kyoto = self;
    fut.ptr = null;
    fut.vtable.init();
    return try self.futures.insertNode(self.futures.rootNode, fut);
}

//Time to sleep in millis
pub fn sleep(self: *Self, timeMs: i64) !*Future {
    const Sleep = struct {
        const Sleep = @This();
        allocator: std.mem.Allocator,
        timeEnd: i64,
        duration: i64,
        previousPtr: ?*anyopaque,

        fn init(allocator: std.mem.Allocator, durationMs: i64) !*Sleep {
            const s = try allocator.create(Sleep);
            s.allocator = allocator;
            s.timeEnd = std.time.milliTimestamp() + durationMs;
            s.duration = durationMs;
            return s;
        }

        fn reset(ctx: ?*anyopaque) void {
            const s: *Sleep = @ptrCast(@alignCast(ctx));
            s.timeEnd = s.timeEnd + s.duration;
        }

        fn deinit(ctx: ?*anyopaque) void {
            const sleepSelf: *Sleep = @ptrCast(@alignCast(ctx));
            sleepSelf.allocator.destroy(sleepSelf);
        }
        fn poll(ctx: ?*anyopaque) Poll {
            const sleepSelf: *Sleep = @ptrCast(@alignCast(ctx));
            if (sleepSelf.timeEnd > std.time.milliTimestamp()) {
                return .Pending;
            } else {
                Sleep.reset(ctx);
                return .{ .Finished = sleepSelf.previousPtr };
            }
        }
        fn handover(ctx: ?*anyopaque, prev_ptr: ?*anyopaque) void {
            const sleepSelf: *Sleep = @ptrCast(@alignCast(ctx));
            sleepSelf.previousPtr = prev_ptr;
        }
    };
    const fut = try self.newFuture();
    fut.ptr = try Sleep.init(self.allocator, timeMs);
    fut.vtable.poll = Sleep.poll;
    fut.vtable.handover = Sleep.handover;
    fut.vtable.destroy = Sleep.deinit;
    fut.vtable.reset = Sleep.reset;
    return fut;
}

pub fn schedule(self: *Self, future: *Future) !*Future {
    _ = try self.futures.insertNode(self.futures.rootNode, future);
    return future;
}

pub fn deinit(self: *Self) void {
    for (self.futures.nodes.items) |node| {
        node.node.destroy();
        self.allocator.destroy(node.node);
    }
    self.futures.deinit();
}

fn done(self: *Self) bool {
    return self.futures.nodeBuffer.items.len == 0;
}

pub fn run(self: *Self) !void {
    var skipped: usize = 0;
    while (try self.futures.peak()) |future| {
        //FIXME: This is a fookin hack
        //If we dont do this. the runtime busyloops
        //and currently i dont have a good idea for preventing it.
        //Currently the best i have in mind is using something like poll or epoll to let the kernel take over till one of the futures are finished.
        //but this only really works for sleep or anything that doesnt require cpu cycles.
        //So currently hard to implement in a way that works for every future.
        //Testing with sdl3-kyoto showed a cpu usage of 6.3% without the hack
        //And 0.5% with the hack
        std.time.sleep(skipped * 10000);
        switch (future.node.poll()) {
            .Pending => {
                skipped += 1;
                self.futures.skip(future);
            },
            .Killed => break,
            .Finished => |ptr| {
                skipped = 0;
                const node = try self.futures.nextNode();
                for (node.?.branches.items) |branch| {
                    branch.node.handover(ptr);
                }
            },
        }
    }
}
