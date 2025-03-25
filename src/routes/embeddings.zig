const std = @import("std");
const zap = @import("zap");
const zml = @import("zml");
const http_utils = @import("../utils/http.zig");
const ModernBertModel = @import("../models/modernbert.zig").ModernBertModel;

const log = std.log.scoped(.embeddings);

/// Request structure for embeddings API
const EmbeddingsRequest = struct {
    input: []const u8,
};

/// Embedding data structure for response
const EmbeddingData = struct {
    embedding: []const f32,
    index: usize = 0,
};

/// Response structure for embeddings API
const EmbeddingsResponse = struct {
    data: []const EmbeddingData,
    model: []const u8,
    usage: UsageOutput,
};

/// Usage statistics for embeddings API
const UsageOutput = struct {
    prompt_tokens: usize,
    total_tokens: usize,
    processing_time_ms: u64,
};

const EmbeddingResult = struct {
    embedding: []f32,
    token_count: usize,
};

/// Handler for embeddings endpoint
pub const EmbeddingsEndpoint = struct {
    allocator: std.mem.Allocator,
    tokenizer: zml.tokenizer.Tokenizer,
    model_instance: zml.ModuleExe(ModernBertModel.forward),
    seq_len: i64,
    route: zap.Endpoint = undefined,
    // I am not sure to understand this mutex thing :
    // https://github.com/zigzap/zap/blob/3b06a336ef27e5ffe04075109d67e309b83a337a/examples/endpoint/users.zig#
    mutex: std.Thread.Mutex = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        tokenizer: zml.tokenizer.Tokenizer,
        model_instance: zml.ModuleExe(ModernBertModel.forward),
        seq_len: i64,
    ) !*EmbeddingsEndpoint {
        const handler = try allocator.create(EmbeddingsEndpoint);
        handler.* = .{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .model_instance = model_instance,
            .seq_len = seq_len,
            .mutex = .{},
        };

        handler.route = zap.Endpoint.init(.{
            .path = "/v1/embeddings",
            .get = http_utils.handleMethodNotAllowed,
            .options = handleOptions,
            .post = handlePostRequest,
            .put = http_utils.handleMethodNotAllowed,
            .delete = http_utils.handleMethodNotAllowed,
            .patch = http_utils.handleMethodNotAllowed,
        });

        return handler;
    }

    pub fn deinit(self: *EmbeddingsEndpoint) void {
        self.allocator.destroy(self);
    }

    pub fn getRoute(self: *EmbeddingsEndpoint) *zap.Endpoint {
        return &self.route;
    }

    fn handleOptions(endpoint: *zap.Endpoint, request: zap.Request) void {
        _ = endpoint;
        request.setHeader("Access-Control-Allow-Origin", "*") catch return;
        request.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS") catch return;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }

    fn handlePostRequest(route: *zap.Endpoint, request: zap.Request) void {
        // Get our handler instance from the endpoint
        const self: *EmbeddingsEndpoint = @fieldParentPtr("route", route);

        // Create a new arena for this specific request
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const request_allocator = arena.allocator();

        // Check request body
        if (request.body == null) {
            http_utils.sendErrorResponse(request, "Missing request body", .bad_request);
            return;
        }

        // Parse JSON request
        const embeddings_request = parseEmbeddingsRequest(request_allocator, request.body.?) catch {
            http_utils.sendErrorResponse(request, "Invalid JSON request", .bad_request);
            return;
        };

        const start_time = std.time.milliTimestamp();

        // wtf here, thread safety ?
        // https://github.com/zigzap/zap/blob/3b06a336ef27e5ffe04075109d67e309b83a337a/examples/endpoint/users.zig#L69
        self.mutex.lock();
        defer self.mutex.unlock();

        // Generate embedding
        self.generateEmbedding(request_allocator, embeddings_request) catch |err| {
            log.err("Error generating embedding: {}", .{err});
            http_utils.sendErrorResponse(request, "Error generating embedding", .internal_server_error);
            return;
        };

        const processing_time = std.time.milliTimestamp() - start_time;

        _ = processing_time;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }

    /// Generate embedding for input text
    fn generateEmbedding(self: *EmbeddingsEndpoint, allocator: std.mem.Allocator, request: EmbeddingsRequest) !void {
        var input_text: []const u8 = undefined;
        var prefixed_text: []u8 = undefined;

        if (!std.mem.startsWith(u8, request.input, "search_query:") and
            !std.mem.startsWith(u8, request.input, "search_document:"))
        {
            // Create prefixed text
            prefixed_text = try std.fmt.allocPrint(allocator, "search_query: {s}", .{request.input});
            input_text = prefixed_text;
        } else {
            input_text = request.input;
        }
        log.info("Tokenizing text: '{s}'", .{input_text});

        // Tokenize input
        var encoder = try self.tokenizer.encoder();
        defer encoder.deinit();

        const pad_token = self.tokenizer.tokenToId("[PAD]") orelse return error.NoSuchToken;

        // Tokenize input text
        const tokens = try encoder.encode(input_text);
        log.info("Toknenized text: {any}", .{tokens});

        // Prepare input tensors
        const input_tokens = try prepareModelInputs(allocator, tokens, self.seq_len, pad_token);
        defer allocator.free(input_tokens);

        // Create input tensors (on the accelerator)
        const input_shape = zml.Shape.init(.{ .b = 1, .s = self.seq_len }, .u32);
        const input_ids_tensor = try zml.Buffer.fromSlice(self.model_instance.platform(), input_shape.dims(), input_tokens);
        defer input_ids_tensor.deinit();
        log.info("input_ids_tensor: {}", .{input_ids_tensor});
    }
};

/// Parse JSON request for embeddings
fn parseEmbeddingsRequest(allocator: std.mem.Allocator, body: []const u8) !EmbeddingsRequest {
    const result = try std.json.parseFromSlice(EmbeddingsRequest, allocator, body, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
    return result.value;
}

/// Prepare input tokens for the model
fn prepareModelInputs(allocator: std.mem.Allocator, tokens: []const u32, seq_len: i64, pad_token: u32) ![]u32 {
    const input_ids = try allocator.alloc(u32, @intCast(seq_len));

    // Fill with padding tokens
    @memset(input_ids, pad_token);

    // Copy tokens into the padded array
    for (tokens, 0..) |token, i| {
        input_ids[i] = @intCast(token);
    }

    return input_ids;
}
