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
const ModernBertForMaskedLM = @import("models/modernbert.zig").ModernBertForMaskedLM;

const log = std.log.scoped(.app);

pub const std_options: std.Options = .{
    .log_level = .info,
    //    .log_scope_levels = &[_]std.log.ScopeLevel{
    //        .{ .scope = .zml, .level = .warn },
    //        .{ .scope = .@"zml/module", .level = .warn },
    //    },
    .logFn = asynk.logFn(std.log.defaultLog),
};

// TODO: Remove hardcoded modernbert options
// Model configuration (config.json)
const modernbert_options = ModernBertOptions{
    .pad_token_id = 50283,
    .num_attention_heads = 16,
    .tie_word_embeddings = false,
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

    // Auto-select platform (cpu, cuda, rocm..)
    const platform = context.autoPlatform(.{});
    context.printAvailablePlatforms(platform);

    // Create arena memory allocator for model resources (shapes and weights)
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const model_allocator = arena_state.allocator();

    // Load tokenizer config from tokenizer.json
    log.info("\tLoading tokenizer from {s}", .{app_config.tokenizer_path});
    var tokenizer = try zml.tokenizer.Tokenizer.fromFile(model_allocator, app_config.tokenizer_path);
    defer tokenizer.deinit();

    // Step 1 - Detect the model file format (here .safetensors) and open it. It creates a buffers store (with shapes ?)
    var load_timer = try std.time.Timer.start();
    var model_buffers_store = try zml.aio.detectFormatAndOpen(allocator, app_config.safetensors_path);
    defer model_buffers_store.deinit();

    // Step 2 - Initialize model struct with Tensors
    // It creates a Model struct with Tensor fields from BufferStore loaded shapes ?
    var model_instance = try zml.aio.populateModelWithPrefix(ModernBertModel, model_allocator, model_buffers_store, "model");
    model_instance.init(modernbert_options);

    // Define the expected input tensors dimensiosn for the model (this is metadata only, no memory yet allocated)
    const input_shape = zml.Shape.init(.{ .b = 1, .s = app_config.seq_len }, .u32);

    // Step 3 - Compile the model to a platform-specific executable
    log.info("\tCompiling model for {s}", .{@tagName(platform.target)});
    var compile_timer = try std.time.Timer.start();

    // Start asynchronous compilation
    var fut_mod = try asynk.asyncc(zml.compileWithPrefix, .{
        allocator,
        ModernBertModel.forwardEmbeddings,
        .{modernbert_options},
        .{input_shape},
        model_buffers_store,
        platform,
        "model",
    });

    // Step 4 - Transfer model weights from host to platform/accelerator memory (in parallel to compilation)
    log.info("\tLoading weights to {s} memory", .{@tagName(platform.target)});
    var model_buffers = try zml.aio.loadBuffersWithPrefix(ModernBertModel, .{modernbert_options}, model_buffers_store, model_allocator, platform, "model");
    defer zml.aio.unloadBuffers(&model_buffers);

    // Step 5 - Wait for compilation + bind weights (model_buffers)
    var compiled_model = try fut_mod.awaitt();
    var model_executable = compiled_model.prepare(model_buffers);
    defer model_executable.deinit();

    log.info("\tSequence length: {d}", .{app_config.seq_len});
    log.info("\tPooling method: {s}", .{@tagName(app_config.pooling)});
    log.info("✅\tModel ready: weights loaded in {d:.3}s, model compiled in {d:.3}s", .{
        load_timer.read() / std.time.ns_per_ms,
        compile_timer.read() / std.time.ns_per_ms,
    });

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
    var embeddings_endpoint = try EmbeddingsEndpoint.init(
        allocator,
        tokenizer,
        model_executable,
        app_config.seq_len,
        app_config.pooling,
    );
    defer embeddings_endpoint.deinit();
    try server.register(embeddings_endpoint.getRoute());

    // Start HTTP server
    try server.listen();
    log.info("✅\tServer listening on http://localhost:{d}", .{app_config.port});
    log.info("📝\tExample usage: curl -X POST http://localhost:{d}/v1/embeddings -H \"Content-Type: application/json\" -d '{{\"input\": \"What is Deep Learning?\"}}'", .{app_config.port});

    // Start worker threads
    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
