const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");

/// Default handler for requests that don't match any route
pub fn notFoundHandler(request: zap.Request) void {
    request.setStatus(.not_found);
    http_utils.sendErrorResponse(request, "Resource not found", .not_found);
}

/// Not allowed reponse for endpoint
pub fn notAllowedHandler(route: *zap.Endpoint, request: zap.Request) void {
    _ = route;
    http_utils.sendErrorResponse(request, "Method not allowed", .method_not_allowed);
}

/// Options method for endpoint
pub fn optionsRequestHandler(route: *zap.Endpoint, request: zap.Request) void {
    _ = route;
    request.setHeader("Access-Control-Allow-Origin", "*") catch return;
    request.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS") catch return;
    request.setStatus(.no_content);
    request.markAsFinished(true);
}
