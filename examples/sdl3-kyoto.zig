const std = @import("std");
const FStd = @import("FStd");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const SDL = struct {
    kyoto: *FStd.Kyoto,

    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    exited: bool = false,
    event: c.SDL_Event = undefined,
    color: u8 = 0,
    color_dir: u1 = 0,

    pub fn init(kyoto: *FStd.Kyoto) !SDL {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS)) {
            return error.SDLNoInit;
        }
        const window = c.SDL_CreateWindow("Kyoto Testing", 600, 400, c.SDL_WINDOW_RESIZABLE) orelse return error.SDLNoWindow;
        const renderer = c.SDL_CreateRenderer(window, "") orelse return error.SDLNoRenderer;
        return .{
            .kyoto = kyoto,
            .window = window,
            .renderer = renderer,
        };
    }
    pub fn deinit(self: *SDL) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }
    fn eventPoll(ctx: ?*anyopaque) FStd.Kyoto.Poll {
        const self: *SDL = @ptrCast(@alignCast(ctx));
        while (c.SDL_PollEvent(&self.event)) {
            if (self.event.type == c.SDL_EVENT_QUIT) {
                self.exited = true;
                return .{ .Finished = self };
            }
        }
        return .Pending;
    }

    fn poll(ctx: ?*anyopaque) FStd.Kyoto.Poll {
        const self: *SDL = @ptrCast(@alignCast(ctx));
        if (self.exited) {
            return .Killed;
        }
        _ = c.SDL_SetRenderDrawColor(self.renderer, self.color, self.color, self.color, 255);
        if (self.color == 255) {
            self.color_dir = 1;
        } else if (self.color == 0) {
            self.color_dir = 0;
        }
        if (self.color_dir == 0) {
            self.color += 1;
        } else {
            self.color -= 1;
        }
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderPresent(self.renderer);
        return .{ .Finished = self };
    }
    pub fn future(self: *SDL) !void {
        const sleepfut = try self.kyoto.sleep(16);
        var fut = try self.kyoto.newFuture();
        fut.ptr = self;
        fut.vtable.poll = SDL.poll;
        _ = try self.kyoto.schedule(fut);
        _ = try fut.thenFuture(sleepfut);
        try sleepfut.loop(fut);
        fut = try self.kyoto.newFuture();
        fut.ptr = self;
        fut.vtable.poll = SDL.eventPoll;
        _ = try self.kyoto.schedule(fut);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var kyoto = try FStd.Kyoto.init(allocator);
    defer kyoto.deinit();
    var sdl = try SDL.init(&kyoto);
    defer sdl.deinit();

    try sdl.future();
    try kyoto.run();
}
