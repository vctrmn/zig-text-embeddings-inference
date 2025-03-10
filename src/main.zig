const std = @import("std");
const zap = @import("zap");

pub fn main() !void {
    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request,
        .log = true,
    });
    try listener.listen();

    std.debug.print("Listening on port 3000...\n", .{});
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}

fn on_request(r: zap.Request) void {
    r.sendBody("Hello, World!") catch return;
}
