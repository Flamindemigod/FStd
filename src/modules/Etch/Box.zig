const std = @import("std");
const Common = @import("./Common.zig");
const Etch = @import("../Etch.zig");
pub const BoxProps = struct {
    any: Common.AnyProps,
    styling: Common.Style = .{},
    draggable: bool = false,
    border: ?u8 = null,
};

pub const Inner = struct {
    allocator: std.mem.Allocator,
    props: BoxProps,
    scratch: struct {
        state: Common.State = .None,
        dragOffs: ?@Vector(2, f32) = null,
    } = .{},
    pub fn render(etch: *Etch, ctx: *anyopaque, renderContext: *const Common.RenderContext) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        _ = self;
        std.debug.assert(renderContext.bounds != null);
        var shrink: u8 = 0;
        if (renderContext.border) |border| {
            etch.primitives.drawRect(renderContext.bounds.?, border.color);
            shrink = border.size;
        }
        if (renderContext.BgColor) |color| etch.primitives.drawRect(Common.Rect{
            .x = renderContext.bounds.?.x + shrink,
            .y = renderContext.bounds.?.y + shrink,
            .width = renderContext.bounds.?.width - shrink * 2,
            .height = renderContext.bounds.?.height - shrink * 2,
        }, color);
    }

    pub fn deinit(ctx: *anyopaque) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        self.allocator.destroy(self);
    }

    pub fn handle_events(etch: *Etch, ctx: *anyopaque) bool {
        var ret = false;
        const self: *Inner = @alignCast(@ptrCast(ctx));
        self.scratch.state = .None;
        if (self.props.any.bounds.asFRect().containsPos(etch.mouse.pos.x, etch.mouse.pos.y) or self.scratch.dragOffs != null) {
            self.scratch.state = .Hovered;
            ret = true;
        }

        //Check Drag State
        //HACK: Currently I'm just using the hovered state and checking if i should be dragging or not based on that. Maybe Dragging needs to be its own state?
        if (self.props.draggable) {
            if (self.scratch.state == .Hovered and etch.mouse.state.left != 0 and self.scratch.dragOffs == null) {
                self.scratch.dragOffs = .{ etch.mouse.pos.x - @as(f32, @floatFromInt(self.props.any.bounds.x)), etch.mouse.pos.y - @as(f32, @floatFromInt(self.props.any.bounds.y)) };
                ret = true;
            } else if (self.scratch.state == .Hovered and etch.mouse.state.left == 0 and self.scratch.dragOffs != null) {
                self.scratch.dragOffs = null;
                ret = true;
            }
        }
        return ret;
    }

    pub fn layout(etch: *Etch, ctx: *anyopaque, parentRC: *const Common.RenderContext, widgetRC: *Common.RenderContext) void {
        const self: *Inner = @alignCast(@ptrCast(ctx));
        widgetRC.state = self.scratch.state;
        //Calc Bounds
        widgetRC.bounds = parentRC.bounds;
        widgetRC.bounds = widgetRC.bounds.?.addPos(&self.props.any.bounds).*;
        widgetRC.bounds.?.width = self.props.any.bounds.width;
        widgetRC.bounds.?.height = self.props.any.bounds.height;

        //Calc New Offsets Through Drag State
        if (self.scratch.dragOffs) |offsets| {
            const pBounds = parentRC.bounds.?.asFRect();
            self.props.any.bounds.x = @intFromFloat(@max(0, etch.mouse.pos.x - offsets[0] - pBounds.x));
            self.props.any.bounds.y = @intFromFloat(@max(0, etch.mouse.pos.y - offsets[1] - pBounds.y));
        }

        //Settle Any Offsets (Needs to be done at all times incase of window resize)
        //FIXME: There needs to be a Update so that these relayout calcs are only done when they're needed.
        //Probs move them to their own function at some point and explictly store that the widget and its children require relayouting
        //This prop most likely can live within the widget itself
        self.props.any.bounds.x = std.math.clamp(self.props.any.bounds.x, 0, if (parentRC.bounds.?.width > self.props.any.bounds.width) parentRC.bounds.?.width - self.props.any.bounds.width else 0);
        self.props.any.bounds.y = std.math.clamp(self.props.any.bounds.y, 0, if (parentRC.bounds.?.height > self.props.any.bounds.height) parentRC.bounds.?.height - self.props.any.bounds.height else 0);

        //Set Render Context Styles
        //FIXME: The state of the widget should probs not be within the Render Context.
        //It should live in the Widget itself or within the Inner Structure
        //Because the render step shouldnt care about the state of the widget
        //as the layouting is supposed to calc the context before the rendering is done anyways
        //The only reason to perhaps keep the state within the RC is to allow passing the state of the parent to the children
        //Because sometimes when a element is hovered or focused. all the children also need to get that state?
        //Not entirely sure if that is even worth it.
        switch (widgetRC.state) {
            .None => {
                widgetRC.BgColor = self.props.styling.none.bgColor;
                widgetRC.FgColor = self.props.styling.none.fgColor;
                if (self.props.border) |b| widgetRC.border = .{ .size = b, .color = self.props.styling.none.borderColor };
            },
            .Hovered => {
                widgetRC.BgColor = self.props.styling.hovered.bgColor;
                widgetRC.FgColor = self.props.styling.hovered.fgColor;
                if (self.props.border) |b| widgetRC.border = .{ .size = b, .color = self.props.styling.hovered.borderColor };
            },
            else => {
                std.debug.print("State: {any}\n", .{widgetRC.state});
                //@compileLog(widgetRC.state);
            },
        }
    }
    pub fn toWidget(self: *Inner, allocator: std.mem.Allocator) !*Common.Widget {
        const w = try allocator.create(Common.Widget);
        w.ptr = self;
        w.vtable = .{
            .handle_events = Inner.handle_events,
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
