const asynk = @import("async");
const zml = @import("zml");
const zap = @import("zap");
const std = @import("std");
const http_utils = @import("utils/http.zig");
const HealthCheckEndpoint = @import("routes/healthz.zig").HealthCheckEndpoint;
const HelloWorldEndpoint = @import("routes/hello.zig").HelloWorldEndpoint;

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
    const allocator = std.heap.c_allocator;

    // Initialize ZML context
    var context = try zml.Context.init();
    defer context.deinit();

    // Auto-select platform
    const platform = context.autoPlatform(.{});
    context.printAvailablePlatforms(platform);

    // Create HTTP server with default 404 handler
    var server = zap.Endpoint.Listener.init(allocator, .{
        .port = PORT,
        .on_request = http_utils.handleNotFound,
        .log = true,
    });
    defer server.deinit();

    // Register routes
    var healthcheck_endpoint = HealthCheckEndpoint.init();
    try server.register(healthcheck_endpoint.getRoute());
    var helloworld_endpoint = HelloWorldEndpoint.init();
    try server.register(helloworld_endpoint.getRoute());

    // Start HTTP server
    try server.listen();
    log.info("✅\tServer listening on localhost:{d}", .{PORT});
    log.info("📝\tExample usage: curl http://localhost:{d}/api/hello", .{PORT});

    // Start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}

fn on_request(r: zap.Request) void {
    r.sendBody("Hello World !") catch return;
}
