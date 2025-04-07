const std = @import("std");
const zap = @import("zap");

const log = std.log.scoped(.http);

/// Maximum size allowed for JSON responses in bytes
pub const MAX_JSON_RESPONSE_SIZE = 64 * 1024; // 64KB should be enough for most embeddings sscenarios

/// Error response structure
pub const ErrorResponse = struct {
    error_message: []const u8,
    code: u32,
};

/// Send JSON response helper with fixed-size buffer
pub fn sendJsonResponse(request: zap.Request, data: anytype, status: zap.StatusCode) void {
    // Use a thread-local buffer to avoid stack allocation for large buffers
    const buffer = getJsonBuffer();
    const json_data = zap.stringifyBuf(buffer, data, .{});

    if (json_data) |response| {
        request.setStatus(status);
        request.setContentType(.JSON) catch return;
        request.sendBody(response) catch |err| {
            log.err("Failed to send response body: {}", .{err});
        };
    } else {
        log.err("JSON serialization failed - buffer size might be too small (current: {})", .{MAX_JSON_RESPONSE_SIZE});

        // Send a generic error response
        request.setStatus(.internal_server_error);
        request.sendBody("Error serializing JSON response: buffer too small") catch {};
    }
}

/// I am totally unsure of this.
/// the previous content is overwritten on each call ?
fn getJsonBuffer() *[MAX_JSON_RESPONSE_SIZE]u8 {
    const T = struct {
        var buffer: [MAX_JSON_RESPONSE_SIZE]u8 = undefined;
    };
    return &T.buffer;
}

/// Error response helper
pub fn sendErrorResponse(request: zap.Request, error_message: []const u8, status: zap.StatusCode) void {
    log.warn("{s} (status: {})", .{ error_message, @intFromEnum(status) });

    const error_response = ErrorResponse{
        .error_message = error_message,
        .code = @intFromEnum(status),
    };

    sendJsonResponse(request, error_response, status);
}

/// Default handler for requests that don't match any route
pub fn handleNotFound(request: zap.Request) void {
    request.setStatus(.not_found);
    sendErrorResponse(request, "Resource not found", .not_found);
}

/// Not allowed response for endpoint
pub fn handleMethodNotAllowed(endpoint: *zap.Endpoint, request: zap.Request) void {
    _ = endpoint;
    sendErrorResponse(request, "Method not allowed", .method_not_allowed);
}
