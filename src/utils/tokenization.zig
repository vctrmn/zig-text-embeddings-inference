const std = @import("std");
const zml = @import("zml");
const stdx = @import("stdx");

const log = std.log.scoped(.tokenization);

pub fn loadTokenizer(allocator: std.mem.Allocator, tokenizer_path: []const u8) !zml.tokenizer.Tokenizer {
    log.info("\tLoading tokenizer from {s}", .{tokenizer_path});
    var timer = try stdx.time.Timer.start();
    const tokenizer = try zml.tokenizer.Tokenizer.fromFile(allocator, tokenizer_path);
    log.info("✅\tLoaded tokenizer from {s} [{}]", .{ tokenizer_path, timer.read() });
    return tokenizer;
}
