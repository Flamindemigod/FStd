//TODO: Need to Do Z-indexing;
//Not Entirely sure how to handle this
//I can easily hack it for input events
//But in terms of rendering
//Arb does all that
//And Arb doesnt have any context of z-indexing or priority or anything such
//esp when the items are floating
//I really dont want to swap the backing structure but honestly might need to
//Not entirely sure what would work best
//Because i need a structure that allows me to have
//Z-indexing / A stack of some sorts
// A Stack of Stacks?
// A sort of recursive structure?
// Sounds like a pain in the ass to manage memory
// But realistically the best option but we'd also need a union into the widget type
// urgh sounds ass. Maybe theres a way to coerce the stack into a widget?
// That doesnt sounds too crazy xD
// Okay might be a bit too crazy. I dont think we have a great way of managing the obects if we cooerce them to widgets
// I might actually end up writing a window manager of sorts to handle these things
// Actually maybe we try hackin Arb to reorder the z-indexing?

//TODO: Widgets Consume Events
//Widgets should consume events based on its z-index

//TODO: Tiling/Floating Mode?
//If Tiling Mode then how are we tiling?
//It would need some sort of tiling rules
//but not entirely sure how much i like it
//Feels like it adds too much complexity
//and essentially would leak abstractions which i take as
//it shouldnt be abstracted then

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

//We Manually traverse the nodes because we dont really care too much about loops and stuff
//TBH we can also do this for sketch
fn twistNode(node: *Arboroboros.Node(*Common.Widget)) bool {
    for (node.branches.items, 0..) |branch, idx| {
        if (branch.node.handle_events()) {
            const a = node.branches.orderedRemove(idx);
            node.branches.insertAssumeCapacity(0, a);
            _ = twistNode(branch);
            return true;
        }
    }
    return false;
}

pub fn twist(self: *Etch) void {
    const root = self.items.rootNode;
    _ = twistNode(root);
}

fn sketchNode(node: *Arboroboros.Node(*Common.Widget)) void {
    if (node.branches.items.len <= 0) return;
    var i: usize = node.branches.items.len - 1;
    while (i < node.branches.items.len) : (i -%= 1) {
        const branch = node.branches.items[i];
        std.debug.assert(branch.parents.items.len == 1);
        branch.node.layout(&branch.parents.items[0].node.renderContext);
        branch.node.render();
        sketchNode(branch);
    }
}

pub fn sketch(self: *Etch) void {
    const root = self.items.rootNode;
    sketchNode(root);
}
