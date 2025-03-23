const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");

/// Handler for health check endpoint
pub const HealthCheckEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() HealthCheckEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/api/healthz",
                .get = handleHealthCheck,
                .options = http_utils.handleOptions,
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

    fn handleHealthCheck(route: *zap.Endpoint, request: zap.Request) void {
        _ = route;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }
};
