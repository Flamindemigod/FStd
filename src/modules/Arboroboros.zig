//A really weird tree implementation hallucinated by my brain to try and make kyoto futures be able to describe dependencies
//Loops might be allowed in this implementation
//So this is no longer a tree. It's a donut
//https://www.youtube.com/watch?v=9NlqYr6-TpA
//I would have called the module a donut. but i found someone calling it a Arboroboros
//and i cant get it out of my head
//I would credit them but their account no longer exists

const std = @import("std");

pub const ParentHandling = enum {
    AtleastOne,
    All,
};

pub fn Node(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        //TODO: add a field to hold refrences to the parents. Mostly used to check if previous depenencidies have been satisfied
        //In the context of kyoto, To check if the previous futures are finished. as a node in Arbororoboros can have multiple parents
        //hence kyoto should be able to await multiple futures
        parents: std.ArrayList(*Node(T)),
        node: T,
        branches: std.ArrayList(*Node(T)),
        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, node: T) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .node = node,
                .parents = .init(allocator),
                .branches = .init(allocator),
            };
            return self;
        }
        pub fn deinit(self: *Self) void {
            self.branches.deinit();
            self.parents.deinit();
            self.allocator.destroy(self);
        }
        pub fn insertParent(self: *Self, branch: *Node(T)) !void {
            try branch.parents.append(self);
        }
        pub fn insertBranch(self: *Self, branch: *Node(T)) !void {
            try self.branches.append(branch);
        }
    };
}

pub fn Arboroboros(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        rootNode: *Node(T),
        //TODO: Store nodes in a hashmap to make lookups faster.
        //For now just gonna do O(N) lookups
        nodes: std.ArrayList(*Node(T)),
        nodeBuffer: std.ArrayList(*Node(T)),
        visitedNodes: std.ArrayList(*Node(T)),
        parentHandling: ParentHandling = ParentHandling.AtleastOne,

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, root: T) !Self {
            const rootNode = try Node(T).init(allocator, root);
            errdefer rootNode.deinit();
            var NodesAl = std.ArrayList(*Node(T)).init(allocator);
            errdefer NodesAl.deinit();
            try NodesAl.append(rootNode);
            const pb = std.ArrayList(*Node(T)).init(allocator);

            return .{
                .allocator = allocator,
                .nodes = NodesAl,
                .rootNode = rootNode,
                .visitedNodes = pb,
                .nodeBuffer = try pb.clone(),
            };
        }

        pub fn insertNode(self: *Self, baseNode: *Node(T), node: T) !*Node(T) {
            const branch = try Node(T).init(self.allocator, node);
            errdefer branch.deinit();
            try baseNode.insertParent(branch);
            try baseNode.insertBranch(branch);
            try self.nodes.append(branch);
            return branch;
        }

        pub fn deinit(self: *Self) void {
            self.visitedNodes.deinit();
            self.nodeBuffer.deinit();
            for (self.nodes.items) |node| {
                node.deinit();
            }
            self.nodes.deinit();
        }

        pub fn skip(self: *Self, node: *Node(T)) void {
            if (std.mem.indexOf(*Node(T), self.nodeBuffer.items, &.{node})) |idx| {
                const a = self.nodeBuffer.items[idx];
                const b = self.nodeBuffer.getLast();
                self.nodeBuffer.items[idx] = b;
                self.nodeBuffer.items[self.nodeBuffer.items.len - 1] = a;
            }
        }

        //TODO: Need a way to mark a node as skipped or incomplete.
        //AKA to be visted again at a later time.
        //For now just using a swap on the node buffer should serve the same purpose
        pub fn peak(self: *Self) !?*Node(T) {
            if (std.mem.eql(*Node(T), self.nodes.items, self.visitedNodes.items)) return null;
            if (self.nodeBuffer.items.len == 0) {
                self.visitedNodes.clearRetainingCapacity();
                try self.nodeBuffer.appendSlice(self.rootNode.branches.items);
                try self.visitedNodes.append(self.rootNode);
            }

            for (self.nodeBuffer.items) |node| {
                switch (self.parentHandling) {
                    .All => {
                        if (node.parents.items.len == 0) continue;
                        if (!std.mem.containsAtLeast(*Node(T), self.visitedNodes.items, node.parents.items.len, node.parents.items)) {
                            continue;
                        }
                    },
                    .AtleastOne => {},
                }
                if (std.mem.containsAtLeast(*Node(T), self.visitedNodes.items, 1, &.{node})) {
                    //TODO: Make a callback that can be registered to run here to detect a loop
                    self.visitedNodes.clearRetainingCapacity();
                    //break;
                }

                return node;
            }
            self.nodeBuffer.clearRetainingCapacity();
            return null;
        }

        pub fn nextNode(self: *Self) !?*Node(T) {
            if (std.mem.eql(*Node(T), self.nodes.items, self.visitedNodes.items)) return null;
            if (self.nodeBuffer.items.len == 0) {
                self.visitedNodes.clearRetainingCapacity();
                try self.nodeBuffer.appendSlice(self.rootNode.branches.items);
                try self.visitedNodes.append(self.rootNode);
            }
            for (self.nodeBuffer.items, 0..) |node, idx| {
                //if(std.mem.containsAtLeast(*Node(T), self.visitedNodes, 1, &.{node}))
                switch (self.parentHandling) {
                    .All => {
                        if (node.parents.items.len == 0) continue;
                        if (!std.mem.containsAtLeast(*Node(T), self.visitedNodes.items, node.parents.items.len, node.parents.items)) {
                            continue;
                        }
                    },
                    .AtleastOne => {},
                }
                if (std.mem.containsAtLeast(*Node(T), self.visitedNodes.items, 1, &.{node})) {
                    //TODO: Make a callback that can be registered to run here to detect a loop
                    self.visitedNodes.clearRetainingCapacity();
                    //break;
                }

                _ = self.nodeBuffer.swapRemove(idx);
                try self.nodeBuffer.appendSlice(node.branches.items);
                try self.visitedNodes.append(node);
                return node;
            }
            self.nodeBuffer.clearRetainingCapacity();
            return null;
        }

        pub fn findNode(self: *Self, nodeInt: T) ?*Node(T) {
            for (self.nodes.items) |node| {
                if (node.node == nodeInt) return node;
            }
            return null;
        }
    };
}

test "Allocations" {
    const testing = std.testing;
    {
        //Depth 0  1  2  3
        //      0                     //Root Node
        //      |- 1
        //      |- 2 <--------|       //2 -> 3 -> 4        //Loops Back
        //      |  |- 3       |
        //      |     |- 4 -->|
        //      |---- 5               //5 -> 4 -> 2 -> 3   //Loops Back
        //      |- 6
        //      |- 7
        var tree = try Arboroboros(u8).init(testing.allocator, 0);
        _ = try tree.insertNode(tree.rootNode, 1);
        defer tree.deinit();
        const b = try tree.insertNode(tree.rootNode, 2);
        const d = try tree.insertNode(b, 3);
        const c = try tree.insertNode(d, 4);
        try c.insertBranch(b);
        const k = try tree.insertNode(tree.rootNode, 5);
        try k.insertBranch(c);
        _ = try tree.insertNode(tree.rootNode, 6);
        _ = try tree.insertNode(tree.rootNode, 7);
        //need to depth checking otherwise it'll loop forever
        //TODO: Consider a whay to detect looping behaviour for the structure and making that accessible to the user
        var depth: usize = 0;
        while (try tree.nextNode()) |node| {
            if (depth > 10) break;
            depth += 1;
            std.debug.print("{d}\n", .{node.node});
        }
    }
    try testing.expect(!testing.allocator_instance.detectLeaks());
}
