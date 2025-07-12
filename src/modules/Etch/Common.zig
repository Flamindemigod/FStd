const Etch = @import("../Etch.zig");

pub const RenderContext = struct {
    FgColor: ?Color = null,
    BgColor: ?Color = null,
    bounds: ?Rect = null,
    state: enum { Hovered, Focus, FocusWithin, None } = .None,
};

pub const FRect = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,

    pub fn addPos(self: *FRect, other: *const FRect) *FRect {
        self.x += other.x;
        self.y += other.y;
        return self;
    }

    pub fn asRect(self: *const FRect) Rect {
        return .{
            .x = @intFromFloat(self.x),
            .y = @intFromFloat(self.y),
            .width = @intFromFloat(self.width),
            .height = @intFromFloat(self.height),
        };
    }
    pub fn containsPos(self: *const FRect, pos_x: f32, pos_y: f32) bool {
        return (pos_x >= self.x and pos_y >= self.y and pos_x <= (self.x + self.width) and pos_y <= (self.y + self.height));
    }
};

pub const Rect = struct {
    x: u32 = 0,
    y: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,

    pub fn addPos(self: *Rect, other: *const Rect) *Rect {
        self.x += other.x;
        self.y += other.y;
        return self;
    }

    pub fn asFRect(self: *const Rect) FRect {
        return .{
            .x = @floatFromInt(self.x),
            .y = @floatFromInt(self.y),
            .width = @floatFromInt(self.width),
            .height = @floatFromInt(self.height),
        };
    }

    pub fn containsPos(self: *const Rect, pos_x: u32, pos_y: u32) bool {
        return (pos_x >= self.x and pos_y >= self.y and pos_x <= (self.x + self.width) and pos_y <= (self.y + self.height));
    }
};

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn fromHex(val: u32) Color {
        return .{
            .r = @intCast((val >> (8 * 3)) & 0xFF),
            .g = @intCast((val >> (8 * 2)) & 0xFF),
            .b = @intCast((val >> (8 * 1)) & 0xFF),
            .a = @intCast((val >> (8 * 0)) & 0xFF),
        };
    }
};

pub const Mouse = struct {
    pub const MouseState = packed struct {
        //Left Mouse Button
        left: u1 = 0,
        //Middle Mouse Button / Scroll Wheel Press
        middle: u1 = 0,
        //Right Mouse Button
        right: u1 = 0,
        //Mouse Side Button 1
        x1: u1 = 0,
        //Mouse Side Button 2
        x2: u1 = 0,
    };
    pos: struct { x: f32 = 0, y: f32 = 0 } = .{},
    state: MouseState = .{},
};

pub const AnyProps = struct {
    FgColor: Color = .fromHex(0xEFEFEF),
    BgColor: Color = .fromHex(0x181818),
    bounds: Rect,
};

pub const Widget = struct {
    const VTable = struct {
        //How to even propagate events through this?
        layout: *const fn (etch: *Etch, ctx: *anyopaque, parentRC: *const RenderContext, widgetRC: *RenderContext) void,
        render: *const fn (etch: *Etch, ctx: *anyopaque, renderContext: *const RenderContext) void,
        deinit: *const fn (ctx: *anyopaque) void,
    };
    etch: *Etch,
    renderContext: RenderContext,
    ptr: *anyopaque,
    vtable: VTable,

    pub fn render(self: *Widget) void {
        self.vtable.render(self.etch, self.ptr, &self.renderContext);
    }
    pub fn deinit(self: *Widget) void {
        self.vtable.deinit(self.ptr);
    }
    pub fn layout(self: *Widget, parentRC: *const RenderContext) void {
        self.vtable.layout(self.etch, self.ptr, parentRC, &self.renderContext);
    }
};
