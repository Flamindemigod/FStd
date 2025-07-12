const std = @import("std");
const Etch = @This();
const Common = @import("./Etch/Common.zig");
const Arboroboros = @import("Arboroboros.zig");

pub const Rect = Common.Rect;
pub const Color = Common.Color;
pub const RenderContext = Common.RenderContext;
pub const Mouse = Common.Mouse;

const BoxModule = @import("./Etch/Box.zig");
pub const Box = BoxModule.Box;
pub const BoxProps = BoxModule.BoxProps;

const Primitives = struct {
    drawRect: *const fn (rect: Common.Rect, color: Common.Color) void,
};

allocator: std.mem.Allocator,
items: Arboroboros.Arboroboros(*Common.Widget),
primitives: Primitives,
mouse: Mouse = .{},

pub fn init(allocator: std.mem.Allocator, bounds: Common.Rect, primitives: Primitives) !*Etch {
    const etch = try allocator.create(Etch);
    const root = try allocator.create(BoxModule.Inner);

    root.* = .{
        .allocator = allocator,
        .props = .{
            .any = .{ .bounds = bounds },
        },
    };
    const rootWidget = try root.toWidget(allocator);
    rootWidget.etch = etch;
    rootWidget.renderContext.bounds = bounds;
    etch.* = .{
        .allocator = allocator,
        .items = try .init(allocator, rootWidget),
        .primitives = primitives,
    };
    return etch;
}

pub fn updateRootBounds(self: *Etch, bounds: Common.Rect) void {
    self.items.rootNode.node.renderContext.bounds = bounds;
}

pub fn deinit(self: *Etch) void {
    for (self.items.nodes.items) |w| {
        w.node.deinit();
        self.allocator.destroy(w.node);
    }
    self.items.deinit();
    self.allocator.destroy(self);
}

pub fn sketch(self: *Etch) !void {
    while (try self.items.nextNode()) |node| {
        std.debug.assert(node.parents.items.len == 1);
        node.node.layout(&node.parents.items[0].node.renderContext);
        node.node.render();
    }
    self.items.visitedNodes.clearRetainingCapacity();
}

// pub fn Box(self: *Etch, props: BoxProps, events: anytype, children: []Widget) Widget {
//
//     return .{};
// }

//const etch = Etch{};
//
//etch.Box(
//  props: draggable,
//  eventHandlers: ...
//  children: etch.Box(
//      props: Flex Col | Grow | Justify Center | Items Center,
//      eventHandlers: ...
//      children: Text(
//          props: draggable,
//          eventHandlers: ...
//          children: null
//      );
//  );
//);
