const std = @import("std");
const Common = @import("./Common.zig");
const Etch = @import("../Etch.zig");
pub const BoxProps = struct {
    any: Common.AnyProps,
    draggable: bool = false,
};

pub const Inner = struct {
    allocator: std.mem.Allocator,
    props: BoxProps,
    scratch: struct {
        dragOffs: ?@Vector(2, f32) = null,
    } = .{},
    pub fn render(etch: *Etch, ctx: *anyopaque, renderContext: *const Common.RenderContext) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        _ = self;
        std.debug.assert(renderContext.bounds != null);
        std.debug.assert(renderContext.BgColor != null);
        etch.primitives.drawRect(renderContext.bounds.?, renderContext.BgColor.?);
    }

    pub fn deinit(ctx: *anyopaque) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        self.allocator.destroy(self);
    }

    pub fn layout(etch: *Etch, ctx: *anyopaque, parentRC: *const Common.RenderContext, widgetRC: *Common.RenderContext) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        widgetRC.bounds = parentRC.bounds;
        widgetRC.bounds = widgetRC.bounds.?.addPos(&self.props.any.bounds).*;
        widgetRC.bounds.?.width = self.props.any.bounds.width;
        widgetRC.bounds.?.height = self.props.any.bounds.height;
        widgetRC.BgColor = self.props.any.BgColor;
        if (widgetRC.bounds.?.asFRect().containsPos(etch.mouse.pos.x, etch.mouse.pos.y) or self.scratch.dragOffs != null) {
            widgetRC.state = .Hovered;
            widgetRC.BgColor.?.r = 20;
        }
        if (widgetRC.state == .Hovered and etch.mouse.state.left != 0 and self.scratch.dragOffs == null) {
            self.scratch.dragOffs = .{ etch.mouse.pos.x - @as(f32, @floatFromInt(widgetRC.bounds.?.x)), etch.mouse.pos.y - @as(f32, @floatFromInt(widgetRC.bounds.?.y)) };
        } else if (widgetRC.state == .Hovered and etch.mouse.state.left == 0 and self.scratch.dragOffs != null) {
            self.scratch.dragOffs = null;
        }

        if (self.scratch.dragOffs) |offsets| {
            const pBounds = parentRC.bounds.?.asFRect();
            self.props.any.bounds.x = @intFromFloat(@max(0, etch.mouse.pos.x - offsets[0] - pBounds.x));
            self.props.any.bounds.y = @intFromFloat(@max(0, etch.mouse.pos.y - offsets[1] - pBounds.y));
        } else if (widgetRC.state == .Hovered) {
            widgetRC.state = .None;
        }
        self.props.any.bounds.x = std.math.clamp(self.props.any.bounds.x, 0, if (parentRC.bounds.?.width > self.props.any.bounds.width) parentRC.bounds.?.width - self.props.any.bounds.width else 0);
        self.props.any.bounds.y = std.math.clamp(self.props.any.bounds.y, 0, if (parentRC.bounds.?.height > self.props.any.bounds.height) parentRC.bounds.?.height - self.props.any.bounds.height else 0);
    }
    pub fn toWidget(self: *Inner, allocator: std.mem.Allocator) !*Common.Widget {
        const w = try allocator.create(Common.Widget);
        w.ptr = self;
        w.vtable = .{
            .deinit = Inner.deinit,
            .render = Inner.render,
            .layout = Inner.layout,
        };
        return w;
    }
};

pub fn Box(self: *Etch, props: BoxProps) !*Inner {
    const root = try self.allocator.create(Inner);
    root.* = .{
        .allocator = self.allocator,
        .props = props,
    };

    const rootWidget = try root.toWidget(self.allocator);
    rootWidget.etch = self;
    _ = try self.items.insertNode(self.items.rootNode, rootWidget);
    return root;
}
