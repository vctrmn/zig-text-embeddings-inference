const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");

/// Response for hello world
const HelloResponse = struct {
    message: []const u8,
};

/// Handler for hello world endpoint
pub const HelloWorldEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() HelloWorldEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/api/hello",
                .get = handleHelloWorld,
                .options = http_utils.handleOptions,
                .post = http_utils.handleMethodNotAllowed,
                .put = http_utils.handleMethodNotAllowed,
                .delete = http_utils.handleMethodNotAllowed,
                .patch = http_utils.handleMethodNotAllowed,
            }),
        };
    }

    pub fn getRoute(self: *HelloWorldEndpoint) *zap.Endpoint {
        return &self.route;
    }

    fn handleHelloWorld(route: *zap.Endpoint, request: zap.Request) void {
        _ = route;
        const response = HelloResponse{ .message = "Hello World!" };
        http_utils.sendJsonResponse(request, response, .ok);
    }
};
