const std = @import("std");
const FStd = @import("FStd");

const Counter = struct {
    kyoto: *FStd.Kyoto,
    value: usize,
    to: usize,

    pub fn then(ctx: ?*anyopaque) FStd.Kyoto.Poll {
        const self: *Counter = @ptrCast(@alignCast(ctx));
        std.debug.print("We're done. Yippe!: {d}\n", .{self.value});
        return .{ .Finished = self };
    }

    pub fn then2(ctx: ?*anyopaque) FStd.Kyoto.Poll {
        //const self: *Counter = @ptrCast(@alignCast(ctx));
        std.debug.print("Hello There\n", .{});
        return .{ .Finished = ctx };
    }

    pub fn poll(ctx: ?*anyopaque) FStd.Kyoto.Poll {
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
    //Setup GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //Init kyoto with the allocator and defer deinit
    var kyoto = FStd.Kyoto.init(allocator);
    defer kyoto.deinit();

    //Make a counter and schedule it to run after 2 seconds and then run the then function 3 times after the main execution is done
    var counter1 = Counter{ .value = 0, .to = 10, .kyoto = &kyoto };
    var f = try counter1.schedule();
    f = try f.then(Counter.then); //then takes a function of the type `*const fn(ctx: ?*anyopaque) FStd.Kyoto.Poll` and makes a new future
    //and attaches it to the current future and forwards the pointer to the new future

    f = try f.then(Counter.then);
    f = try f.thenFuture(try kyoto.sleep(2000)); //thenFuture is a variant of the then function that accepts a Future.
    //This function causes the pointer from the old function to get discarded and overwridden
    //by the pointer that exists within the next Future.
    f = try f.then(Counter.then2);

    //Make a counter and schedule it to run after 5 seconds and then run the then2 function after the main execution is done
    var counter2 = Counter{ .value = 5, .to = 20, .kyoto = &kyoto };
    f = try kyoto.sleep(5000);
    f = try f.thenFuture(try counter2.schedule());
    f = try f.then(Counter.then2);

    //Run the Kyoto Event loop
    kyoto.run();
}
