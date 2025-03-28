const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");

/// Handler for health check endpoint
pub const HealthCheckEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() HealthCheckEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/v1/healthz",
                .get = handleHealthCheck,
                .options = handleOptions,
                .post = http_utils.handleMethodNotAllowed,
                .put = http_utils.handleMethodNotAllowed,
                .delete = http_utils.handleMethodNotAllowed,
                .patch = http_utils.handleMethodNotAllowed,
            }),
        };
    }

    pub fn getRoute(self: *HealthCheckEndpoint) *zap.Endpoint {
        return &self.route;
    }

    fn handleOptions(endpoint: *zap.Endpoint, request: zap.Request) void {
        _ = endpoint;
        request.setHeader("Access-Control-Allow-Origin", "*") catch return;
        request.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS") catch return;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }

    fn handleHealthCheck(route: *zap.Endpoint, request: zap.Request) void {
        _ = route;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }
};
