const std = @import("std");
const Etch = @import("FStd").Etch;
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub fn drawRect(rect: Etch.Rect, color: Etch.Color) void {
    var old_color = Etch.Color{};
    _ = c.SDL_GetRenderDrawColor(renderer, &old_color.r, &old_color.g, &old_color.b, &old_color.a);
    defer _ = c.SDL_SetRenderDrawColor(renderer, old_color.r, old_color.g, old_color.b, old_color.a);
    _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
    _ = c.SDL_RenderFillRect(renderer, &.{
        .x = @floatFromInt(rect.x),
        .y = @floatFromInt(rect.y),
        .h = @floatFromInt(rect.height),
        .w = @floatFromInt(rect.width),
    });
}
pub fn drawText(text: []const u8, color: Etch.Color) void {
    _ = text;
    _ = color;
    unreachable;
}

var renderer: ?*c.SDL_Renderer = undefined;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_EVENTS)) {
        return error.SDLNoInit;
    }
    defer c.SDL_Quit();
    const window = c.SDL_CreateWindow("Kyoto Testing", 600, 400, c.SDL_WINDOW_RESIZABLE) orelse return error.SDLNoWindow;
    defer c.SDL_DestroyWindow(window);
    renderer = c.SDL_CreateRenderer(window, "") orelse return error.SDLNoRenderer;
    defer c.SDL_DestroyRenderer(renderer);
    var windowBounds = Etch.Rect{ .width = 600, .height = 400 };
    var etch = try Etch.init(
        allocator,
        windowBounds,
        .{
            .drawRect = &drawRect,
            // .drawText = drawText,
        },
    );
    defer etch.deinit();
    var quit = false;
    _ = try etch.Box(Etch.BoxProps{ .any = .{
        .bounds = .{ .x = 20, .height = 100, .width = 100 },
    }, .draggable = true, .border = 10 });
    _ = try etch.Box(Etch.BoxProps{ .any = .{
        .bounds = .{ .height = 40, .width = 100 },
    }, .draggable = true, .border = 10 });
    _ = try etch.Box(Etch.BoxProps{ .any = .{
        .bounds = .{ .x = 10, .height = 200, .width = 100 },
    }, .draggable = true, .border = 10 });
    _ = try etch.Box(Etch.BoxProps{ .any = .{
        .bounds = .{ .height = 100, .width = 500 },
    }, .draggable = true, .border = 10 });
    var event: c.SDL_Event = undefined;
    while (!quit) {
        //Update Mouse State Within Etch
        etch.mouse.state = @as(*const Etch.Mouse.MouseState, @ptrCast(&c.SDL_GetMouseState(&etch.mouse.pos.x, &etch.mouse.pos.y))).*;
        etch.updateRootBounds(windowBounds);
        //etch.updateRootBounds(bounds: Common.Rect)
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => quit = true,
                c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.key == c.SDLK_Q) quit = true;
                },
                c.SDL_EVENT_WINDOW_RESIZED => {
                    _ = c.SDL_GetWindowSizeInPixels(window, @ptrCast(&windowBounds.width), @ptrCast(&windowBounds.height));
                },
                c.SDL_EVENT_MOUSE_MOTION => {

                    //std.debug.print("{any}\n", .{event.motion});
                },
                else => {},
            }
        }
        _ = c.SDL_SetRenderDrawColor(renderer, 18, 18, 18, 255);
        _ = c.SDL_RenderClear(renderer);
        etch.twist();
        etch.sketch();
        _ = c.SDL_RenderPresent(renderer);
        c.SDL_Delay(16);
    }
}
