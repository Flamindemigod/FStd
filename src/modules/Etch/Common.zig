const std = @import("std");
const Etch = @import("../Etch.zig");

pub const State = enum { Hovered, Focus, FocusWithin, None };

pub const RenderContext = struct {
    FgColor: ?Color = null,
    BgColor: ?Color = null,
    bounds: ?Rect = null,
    border: ?struct { size: u8, color: Color } = null,
    state: State = .None,
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
    bounds: Rect,
};

pub const Style = struct {
    hovered: Styling = .fromStylix(&.Default, .Hovered),
    focus: Styling = .fromStylix(&.Default, .Focus),
    focusWithin: Styling = .fromStylix(&.Default, .FocusWithin),
    none: Styling = .fromStylix(&.Default, .None),
};

pub const Styling = struct {
    fgColor: Color = .fromHex(0xEFEFEFFF),
    bgColor: Color = .fromHex(0x181818FF),
    borderColor: Color = .fromHex(0x282828FF),

    pub fn fromStylix(stylix: *const Stylix, mode: State) Styling {
        switch (mode) {
            .None => return Styling{
                .bgColor = .fromHex(stylix.base01),
                .fgColor = .fromHex(stylix.base08),
                .borderColor = .fromHex(stylix.base03),
            },
            .Hovered => return Styling{
                .bgColor = .fromHex(stylix.base0F),
                .fgColor = .fromHex(stylix.base08),
                .borderColor = .fromHex(stylix.base04),
            },
            .Focus => return Styling{
                .bgColor = .fromHex(stylix.base03),
                .fgColor = .fromHex(stylix.base08),
                .borderColor = .fromHex(stylix.base04),
            },
            .FocusWithin => return Styling{
                .bgColor = .fromHex(stylix.base01),
                .fgColor = .fromHex(stylix.base08),
                .borderColor = .fromHex(stylix.base04),
            },
            //else => @compileLog(mode),
        }
        return fromStylix(stylix, .None);
    }

    pub const Stylix = struct {
        base00: u32,
        base01: u32,
        base02: u32,
        base03: u32,
        base04: u32,
        base05: u32,
        base06: u32,
        base07: u32,
        base08: u32,
        base09: u32,
        base0A: u32,
        base0B: u32,
        base0C: u32,
        base0D: u32,
        base0E: u32,
        base0F: u32,

        //Just Ripped from my personal Stylix Themes
        pub const Default: Stylix = .{
            .base00 = 0x191B27FF,
            .base01 = 0x75314DFF,
            .base02 = 0x67687AFF,
            .base03 = 0xEF72BDFF,
            .base04 = 0xF0A2C9FF,
            .base05 = 0xE5DDEEFF,
            .base06 = 0xFDECF4FF,
            .base07 = 0xFAECF9FF,
            .base08 = 0xDA66BBFF,
            .base09 = 0xCF73A4FF,
            .base0A = 0x8493A7FF,
            .base0B = 0xA18F68FF,
            .base0C = 0x928EA1FF,
            .base0D = 0xA38B9BFF,
            .base0E = 0x6C92DBFF,
            .base0F = 0xB18691FF,
        };

        pub fn jsonParse(allocator: std.mem.Allocator, source: std.json.Scanner, options: std.json.ParseOptions) !Stylix {
            _ = allocator;
            _ = options;
            if (try source.next() != .object_begin) {
                return error.UnexpectedToken;
            }
            switch (try source.next()) {
                else => |e| @compileLog(e),
            }
            return Stylix{
                .base00 = 0xC0FFEE69,
                .base01 = 0xC0FFEE69,
                .base02 = 0xC0FFEE69,
                .base03 = 0xC0FFEE69,
                .base04 = 0xC0FFEE69,
                .base05 = 0xC0FFEE69,
                .base06 = 0xC0FFEE69,
                .base07 = 0xC0FFEE69,
                .base08 = 0xC0FFEE69,
                .base09 = 0xC0FFEE69,
                .base0A = 0xC0FFEE69,
                .base0B = 0xC0FFEE69,
                .base0C = 0xC0FFEE69,
                .base0D = 0xC0FFEE69,
                .base0E = 0xC0FFEE69,
                .base0F = 0xC0FFEE69,
            };
        }
    };
};

pub const Widget = struct {
    const VTable = struct {
        //How to even propagate events through this?
        layout: *const fn (etch: *Etch, ctx: *anyopaque, parentRC: *const RenderContext, widgetRC: *RenderContext) void,
        handle_events: *const fn (etch: *Etch, ctx: *anyopaque) bool,
        render: *const fn (etch: *Etch, ctx: *anyopaque, renderContext: *const RenderContext) void,
        deinit: *const fn (ctx: *anyopaque) void,
    };
    etch: *Etch,
    renderContext: RenderContext,
    ptr: *anyopaque,
    vtable: VTable,

    pub fn handle_events(self: *Widget) bool {
        return self.vtable.handle_events(self.etch, self.ptr);
    }
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
