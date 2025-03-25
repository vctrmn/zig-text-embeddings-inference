const std = @import("std");
const clap = @import("clap");

const log = std.log.scoped(.config);

/// Command-line argument parameters definition
const cli_params = clap.parseParamsComptime(
    \\--help                                print this help
    \\--port                    <UINT>      port to listen on (default: 3000)
    \\--tokenizer               <PATH>      tokenizer.json path (required)
    \\--model                   <PATH>      model.safetensors path (required)
    //    \\--config                  <PATH>      config.json path (required)
    \\--seq-len                 <UINT>      sequence length (default: 512, up to 8192)
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
pub const AppConfig = struct {
    port: u16,
    tokenizer_path: []const u8,
    safetensors_path: []const u8,
    seq_len: i64,
};

/// Parse command line arguments into configuration
// TODO: Unit test
pub fn parseConfig(allocator: std.mem.Allocator) !AppConfig {
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

    const tokenizer_path = cli.args.tokenizer orelse {
        log.err("Missing required parameter: --tokenizer\n", .{});
        try printHelp();
        return error.MissingTokenizer;
    };

    const model_path = cli.args.model orelse {
        log.err("Missing required parameter: --model\n", .{});
        try printHelp();
        return error.MissingModel;
    };

    // const config_path = cli.args.config orelse {
    //     log.err("Missing required parameter: --config\n", .{});
    //     try printHelp();
    //     return error.MissingConfig;
    // };

    // Validate file paths
    if (!validateFilePath(tokenizer_path)) {
        log.err("Invalid tokenizer.json path: {s}\n", .{tokenizer_path});
        return error.InvalidTokenizerPath;
    }

    if (!validateFilePath(model_path)) {
        log.err("Invalid model.safetensors path: {s}\n", .{model_path});
        return error.InvalidModelPath;
    }

    // if (!validateFilePath(config_path)) {
    //     log.err("Invalid config.json path: {s}\n", .{config_path});
    //     return error.InvalidConfigPath;
    // }

    return AppConfig{
        .port = @intCast(cli.args.port orelse 3000),
        .tokenizer_path = tokenizer_path,
        .safetensors_path = model_path,
        .seq_len = @as(i64, @intCast(cli.args.@"seq-len" orelse 256)),
    };
}

/// Validate that a file path exists and is accessible
// TODO: Unit test
fn validateFilePath(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        log.err("Error opening file at path {s}: {}", .{ path, err });
        return false;
    };
    defer file.close();

    return true;
}

/// Print CLI usage help
fn printHelp() !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("usage: ", .{});
    try clap.usage(stderr, clap.Help, &cli_params);
    try stderr.print("\n", .{});
}
