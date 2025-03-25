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
        _ = route;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }
};
