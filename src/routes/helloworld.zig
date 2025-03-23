const std = @import("std");
const zap = @import("zap");
const http_utils = @import("../utils/http.zig");
const notAllowedHandler = @import("common.zig").notAllowedHandler;
const optionsRequestHandler = @import("common.zig").optionsRequestHandler;

/// Response for masked language model prediction
const HelloWorldRepsonse = struct {
    message: []const u8,
};

/// Handler for hello world endpoint
pub const HelloWorldEndpoint = struct {
    route: zap.Endpoint = undefined,

    pub fn init() HelloWorldEndpoint {
        return .{
            .route = zap.Endpoint.init(.{
                .path = "/api/helloworld",
                .get = getRequestHandler,
                .options = optionsRequestHandler,
                .post = notAllowedHandler,
                .put = notAllowedHandler,
                .delete = notAllowedHandler,
                .patch = notAllowedHandler,
            }),
        };
    }

    pub fn getRoute(self: *HelloWorldEndpoint) *zap.Endpoint {
        return &self.route;
    }

    fn getRequestHandler(route: *zap.Endpoint, request: zap.Request) void {
        _ = route;
        const response = HelloWorldRepsonse{ .message = "Hello World!" };
        http_utils.sendJsonResponse(request, response, .ok);
    }
};
