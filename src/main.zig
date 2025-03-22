const asynk = @import("async");
const zml = @import("zml");
const zap = @import("zap");
const std = @import("std");
const log = std.log.scoped(.app);

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = asynk.logFn(std.log.defaultLog),
};

const PORT = 3000;

/// Entry point
pub fn main() !void {
    try asynk.AsyncThread.main(std.heap.c_allocator, asyncMain);
}

/// Main async function
pub fn asyncMain() !void {
    // Initialize ZML context
    var context = try zml.Context.init();
    defer context.deinit();

    // Auto-select platform
    const platform = context.autoPlatform(.{});
    context.printAvailablePlatforms(platform);

    var listener = zap.HttpListener.init(.{
        .port = PORT,
        .on_request = on_request,
        .log = true,
    });
    try listener.listen();

    log.info("✅\tHTTP server listening on localhost:{d}", .{PORT});
    log.info("📝\tExample usage: curl http://localhost:{d}", .{PORT});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}

fn on_request(r: zap.Request) void {
    r.sendBody("Hello World !") catch return;
}
