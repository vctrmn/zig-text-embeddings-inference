const std = @import("std");
const zap = @import("zap");
const notAllowedHandler = @import("common.zig").notAllowedHandler;
const optionsRequestHandler = @import("common.zig").optionsRequestHandler;

/// Handler for health check endpoint
pub const HealthCheckEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() HealthCheckEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/api/healthz",
                .get = getRequestHandler,
                .options = optionsRequestHandler,
                .post = notAllowedHandler,
                .put = notAllowedHandler,
                .delete = notAllowedHandler,
                .patch = notAllowedHandler,
            }),
        };
    }

    pub fn getRoute(self: *HealthCheckEndpoint) *zap.Endpoint {
        return &self.route;
    }

    fn getRequestHandler(route: *zap.Endpoint, request: zap.Request) void {
        _ = route;
        request.setStatus(.no_content);
        request.markAsFinished(true);
    }
};
