const asynk = @import("async");
const zml = @import("zml");
const zap = @import("zap");
const std = @import("std");
const config = @import("config.zig");
const http_utils = @import("utils/http.zig");
const tokenization_utils = @import("utils/tokenization.zig");
const HealthCheckEndpoint = @import("routes/healthz.zig").HealthCheckEndpoint;
const EmbeddingsEndpoint = @import("routes/embeddings.zig").EmbeddingsEndpoint;

const log = std.log.scoped(.app);

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = asynk.logFn(std.log.defaultLog),
};

/// Entry point
pub fn main() !void {
    try asynk.AsyncThread.main(std.heap.c_allocator, asyncMain);
}

/// Main async function
pub fn asyncMain() !void {
    const allocator = std.heap.c_allocator;

    // Parse configuration from command line
    const app_config = config.parseConfig(allocator) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };

    // Ensure cache directory exists
    const tmp = try std.fs.openDirAbsolute("/tmp", .{});
    try tmp.makePath("zml/embeddings_model/cache");

    // Initialize ZML context
    var context = try zml.Context.init();
    defer context.deinit();

    // Auto-select platform
    const platform = context.autoPlatform(.{});
    context.printAvailablePlatforms(platform);

    // Create memory arena for model shapes and weights
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const model_arena = arena_state.allocator();

    // Load tokenizer
    var tokenizer = try tokenization_utils.loadTokenizer(model_arena, app_config.tokenizer);
    defer tokenizer.deinit();

    // Load model

    // Create HTTP server with default 404 handler
    var server = zap.Endpoint.Listener.init(allocator, .{
        .port = app_config.port,
        .on_request = http_utils.handleNotFound,
        .log = true,
    });
    defer server.deinit();

    // Register routes
    var healthcheck_endpoint = HealthCheckEndpoint.init();
    try server.register(healthcheck_endpoint.getRoute());
    var embeddings_endpoint = EmbeddingsEndpoint.init();
    try server.register(embeddings_endpoint.getRoute());

    // Start HTTP server
    try server.listen();
    log.info("✅\tServer listening on localhost:{d}", .{app_config.port});
    log.info("📝\tExample usage: curl -X POST http://localhost:{d}/v1/embeddings -H \"Content-Type: application/json\" -d '{{\"input\": \"Here is a sentence to embed as a vector\"}}'", .{app_config.port});

    // Start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}

fn on_request(r: zap.Request) void {
    r.sendBody("Hello World !") catch return;
}
