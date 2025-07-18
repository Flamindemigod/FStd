//Really basic Iterator implementation heavily inspired by the iterrators in Rust.
//There are bits and pieces of rust that i really hate. But there are def things
//that i absolutely adore. This wont be exactly how Rust's iterrators work.
//Implementing all that would be a right pain.
//I just want to implement the subset of functions that i actually need
const std = @import("std");

pub fn Iterator(comptime Inner: type) type {
    return struct {
        const Iter = @This();
        cursor: usize = 0,
        dir: enum (i2){
            forwards = 1,
            backwards = -1,
        } = .forwards,
        data: []Inner,

        pub fn init(data: []Inner) Iter{
            return .{
                .data = data
            };
        }
        pub fn rev(self: *Iter) *Iter {
            self.dir *= -1;
            return self;
        }

        //next Returns the item itself.
        //This a copy of the item in the slice. not the pointer to it.
        //so any changes wont affect the slice.
        //If you want a pointer to the item then use `nextRef` instead;
        pub fn next(self: *Iter) ?Inner {
            defer self.cursor += 1;
            if(self.cursor < self.data.len) return self.data[self.cursor];
            return null;
        }

        //nextRef Returns the pointer item.
        //If you want a copy of the item then use `next` instead;
        pub fn nextRef(self: *Iter) ?*Inner {
            defer self.cursor += 1;
            if(self.cursor < self.data.len) return &self.data[self.cursor];
            return null;
        }
    };
}

test "BasicIter" {
    const testing = std.testing;
    {
        var arr = [_]usize{0, 1, 2, 3, 4, 5 ,6, 7, 8, 9};
        var iter = Iterator(usize).init(&arr);
        while(iter.next()) |val| {
            try testing.expectEqual(arr[iter.cursor - 1], val);
        }
        iter.cursor = 0;
        while(iter.nextRef()) |val| {
            val.* *= val.*;
        }
        iter.cursor = 0;
        while(iter.next()) |val| {
            try testing.expectEqual(std.math.pow(usize, iter.cursor - 1, 2) , val);
        }
    }
}
