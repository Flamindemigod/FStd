const std = @import("std");
pub const Kyoto = @import("./modules/Kyoto.zig");
pub const Arboroboros = @import("./modules/Arboroboros.zig");
pub const Temp = @import("./modules/Temp.zig");
pub const Etch = @import("./modules/Etch.zig");

test "tests" {
    _ = @import("./modules/Arboroboros.zig");
    _ = @import("./modules/Kyoto.zig");
    _ = @import("./modules/Temp.zig");
    _ = @import("./modules/Etch.zig");
}
