const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");

/// Request structure for embeddings API
const EmbeddingsRequest = struct {
    input: []const u8,
};

const UsageOutput = struct {
    prompt_tokens: usize,
    total_tokens: usize,
    processing_time_ms: u64,
};

/// Handler for embeddings endpoint
pub const EmbeddingsEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() EmbeddingsEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/v1/embeddings",
                .get = http_utils.handleMethodNotAllowed,
                .options = handleOptions,
                .post = handlePostRequest,
                .put = http_utils.handleMethodNotAllowed,
                .delete = http_utils.handleMethodNotAllowed,
                .patch = http_utils.handleMethodNotAllowed,
            }),
        };
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
