const std = @import("std");
const zap = @import("zap");

const log = std.log.scoped(.http);

/// Error response structure
pub const ErrorResponse = struct {
    error_message: []const u8,
    code: u32,
};

/// Send JSON response helper
pub fn sendJsonResponse(request: zap.Request, data: anytype, status: zap.StatusCode) void {
    var json_buffer: [2048]u8 = undefined;
    const json_data = zap.stringifyBuf(&json_buffer, data, .{});

    if (json_data) |response| {
        request.setStatus(status);
        request.setContentType(.JSON) catch return;
        request.sendBody(response) catch return;
    } else {
        log.err("Error serializing JSON response", .{});
        request.setStatus(.internal_server_error);
        request.sendBody("Error serializing JSON response") catch return;
    }
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
