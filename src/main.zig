const asynk = @import("async");
const zml = @import("zml");
const zap = @import("zap");
const std = @import("std");
const config = @import("config.zig");
const http_utils = @import("utils/http.zig");
const HealthCheckEndpoint = @import("routes/healthz.zig").HealthCheckEndpoint;
const EmbeddingsEndpoint = @import("routes/embeddings.zig").EmbeddingsEndpoint;
const ModernBertModel = @import("models/modernbert.zig").ModernBertModel;
const ModernBertOptions = @import("models/modernbert.zig").ModernBertOptions;

const log = std.log.scoped(.app);

pub const std_options: std.Options = .{
    .log_level = .info,
    .logFn = asynk.logFn(std.log.defaultLog),
};

// TODO: Remove hardcoded modernbert options
// Model configuration (config.json)
const modernbert_options = ModernBertOptions{
    .pad_token_id = 50283,
    .num_attention_heads = 12,
    .tie_word_embeddings = true,
    .local_attention = 128,
};

/// Entry point
pub fn main() !void {
    try asynk.AsyncThread.main(std.heap.c_allocator, asyncMain);
}

/// Main async function
pub fn asyncMain() !void {
    const allocator = std.heap.c_allocator;
    log.info("🚀 Starting zig text embeddings server", .{});

    // Parse configuration from command line args
    const app_config = config.parseConfig(allocator) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };

    // Ensure cache directory exists
    const tmp = try std.fs.openDirAbsolute("/tmp", .{});
    try tmp.makePath("zml/embeddings/cache");

    // Initialize ZML context
    var context = try zml.Context.init();
    defer context.deinit();

    // Auto-select acceleration_platform
    const acceleration_platform = context.autoPlatform(.{});
    context.printAvailablePlatforms(acceleration_platform);

    // Create arena memory for model resources (shapes and weights)
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const model_allocator = arena_state.allocator();

    // Load tokenizer config from tokenizer.json
    var tokenizer = try zml.tokenizer.Tokenizer.fromFile(model_allocator, app_config.tokenizer_path);
    defer tokenizer.deinit();
    log.info("✅\tLoaded tokenizer from {s}", .{app_config.tokenizer_path});

    // Step 1 - Open the model file and detect its format (here .safetensors)
    var model_tensor_store = try zml.aio.detectFormatAndOpen(allocator, app_config.safetensors_path);
    defer model_tensor_store.deinit();

    // Step 2 - Initialize model struct with Tensors using model_tensor_store
    var model_instance = try zml.aio.populateModel(ModernBertModel, model_allocator, model_tensor_store);
    model_instance.init(modernbert_options);

    // Step 3 - Transfer model weights from host to accelerator (acceleration_platform) memory
    log.info("\tLoading weights to {s} memory", .{@tagName(acceleration_platform.target)});
    var model_buffers = try zml.aio.loadBuffers(ModernBertModel, .{modernbert_options}, model_tensor_store, model_allocator, acceleration_platform);
    defer zml.aio.unloadBuffers(&model_buffers);

    // Define the expected input tensors dimensiosn for the model
    const input_shape = zml.Shape.init(.{ .b = 1, .s = app_config.seq_len }, .u32);

    // Compile the model to platform-specific executable
    log.info("\tCompiling ModernBERT model...", .{});
    var fut_mod = try asynk.asyncc(zml.compile, .{
        allocator,
        ModernBertModel.forward,
        .{modernbert_options},
        .{input_shape},
        model_tensor_store,
        acceleration_platform,
    });
    var bert_module = (try fut_mod.awaitt()).prepare(model_buffers);
    defer bert_module.deinit();

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
    log.info("✅\tServer listening on http://localhost:{d}", .{app_config.port});
    log.info("📝\tExample usage: curl -X POST http://localhost:{d}/v1/embeddings -H \"Content-Type: application/json\" -d '{{\"input\": \"Here is a sentence to embed as a vector\"}}'", .{app_config.port});

    // Start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
