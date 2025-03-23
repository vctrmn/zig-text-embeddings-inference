const std = @import("std");
const clap = @import("clap");

/// Command-line argument parameters definition
const cli_params = clap.parseParamsComptime(
    \\--help                                print this help
    \\--port                    <UINT>      port to listen on (default: 3000)
);

/// CLI parameter parsers
const cli_parsers = .{
    .BOOL = parseBool,
    .UINT = clap.parsers.int(usize, 0),
    .STRING = clap.parsers.string,
    .PATH = clap.parsers.string,
};

/// Parse boolean values from command line arguments
fn parseBool(in: []const u8) error{}!bool {
    return std.mem.indexOfScalar(u8, "tTyY1", in[0]) != null;
}

/// Configuration structure for the application
pub const Config = struct {
    port: u16,
};

/// Parse command line arguments into configuration
pub fn parseConfig(allocator: std.mem.Allocator) !Config {
    const stderr = std.io.getStdErr().writer();

    // Parse command line arguments
    var diag: clap.Diagnostic = .{};
    var cli = clap.parse(clap.Help, &cli_params, cli_parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.report(stderr, err);
        try printHelp();
        return error.InvalidArguments;
    };
    defer cli.deinit();

    // Show help if requested
    if (cli.args.help != 0) {
        try clap.help(stderr, clap.Help, &cli_params, .{});
        return error.HelpRequested;
    }

    const config = Config{
        .port = @intCast(cli.args.port orelse 3000),
    };

    return config;
}

/// Print CLI usage help
pub fn printHelp() !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("usage: ", .{});
    try clap.usage(stderr, clap.Help, &cli_params);
    try stderr.print("\n", .{});
}
