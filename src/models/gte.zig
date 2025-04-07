const std = @import("std");
const log = std.log.scoped(.gte);

const asynk = @import("async");
const zml = @import("zml");

const Tensor = zml.Tensor;

pub const GTEConfig = struct {
    layer_norm_eps: f32 = 1e-12,
    num_attention_heads: i64 = 16,
    pad_token_id: u32 = 0,
};

/// Reference models uses 3 inputs, but implementation uses 1
/// Reference models produces 4 outputs, but implementation produces 1
/// Which is fine for inference
pub const GTEEmbeddings = struct {
    word_embeddings: zml.nn.TokenEmbedding,
    token_type_embeddings: zml.nn.TokenEmbedding,
    LayerNorm: zml.nn.LayerNorm,

    pub fn forward(self: GTEEmbeddings, input_ids: Tensor) Tensor {
        const word_embeds: Tensor = zml.call(self.word_embeddings, .forward, .{input_ids});

        // Create stoken type IDs (all zeros for inference)
        const token_type_ids = Tensor.constant(input_ids.shape(), input_ids.dtype().zero());

        // Get token type embeddings
        const type_embeds = zml.call(self.token_type_embeddings, .forward, .{token_type_ids});

        // Sum the embeddings
        const embeddings = word_embeds.add(type_embeds);

        // Apply layer normalization
        return zml.call(self.LayerNorm, .forward, .{embeddings});
    }
};

// https://github.com/huggingface/text-embeddings-inference/blob/main/backends/candle/src/models/gte.rs#L214
pub const GTEMLP = struct {
    up_gate_proj: zml.nn.Linear,
    down_proj: zml.nn.Linear,

    pub fn forward(self: GTEMLP, hidden_states: Tensor) Tensor {
        // Perform up_gate_proj
        const up_gate_states: Tensor = zml.call(self.up_gate_proj, .forward, .{hidden_states});

        // Split into up_states and gate_states (modulator) tensors along the last dimension
        const up_states, const gate_states = up_gate_states.chunkExact(-1, 2);
        // const up_states = up_gate_states.slice1d(-1, .{ .end = 4096 });
        // const gate_states = up_gate_states.slice1d(-1, .{ .start = 4096 });

        // Apply activation
        const activated_input = up_states.mul(gate_states.gelu());

        // Perform down projection
        return zml.call(self.down_proj, .forward, .{activated_input});
    }
};

// https://github.com/huggingface/text-embeddings-inference/blob/main/backends/candle/src/models/gte.rs
pub const GTEAttention = struct {
    o_proj: zml.nn.Linear,
    qkv_proj: zml.nn.Linear,
    num_attention_heads: i64 = undefined,

    pub fn forward(self: GTEAttention, hidden_states: Tensor, attention_mask: Tensor, cos: Tensor, sin: Tensor) Tensor {
        const batch_size = hidden_states.shape().dim(0);
        const seq_length = hidden_states.shape().dim(1);
        const hidden_size = hidden_states.shape().dim(2);
        const attention_head_size = @divExact(hidden_size, self.num_attention_heads);
        const softmax_scale = 1.0 / @sqrt(@as(f32, @floatFromInt(attention_head_size)));

        // Project to query, key, value - {batch_size, seq_len, 3 * hidden_size}
        var qkv: Tensor = zml.call(self.qkv_proj, .forward, .{hidden_states});

        // Reshape qkv from {batch_size, seq_len, 3 * hidden_size} to {batch_size, seq_len, 3, num_attention_heads, attention_head_size}
        qkv = qkv.reshape(.{ batch_size, seq_length, 3, self.num_attention_heads, attention_head_size }).withTags(.{ .b, .s, .chunk, .h, .hd });

        // Split into query, key, value tensors - each { batch_size, seq_length, num_attention_heads, attention_head_size }
        var q, var k, var v = qkv.chunkExact(.chunk, 3);
        q = q.squeeze(.chunk);
        k = k.squeeze(.chunk);
        v = v.squeeze(.chunk);

        // Transpose to match Rust implementation shape
        q = q.transpose(.{ .b, .h, .s, .hd });
        k = k.transpose(.{ .b, .h, .s, .hd });
        v = v.transpose(.{ .b, .h, .s, .hd });

        // Prepare cos/sin for rotary embedding
        const cos_reshaped = cos.transpose(.{ 0, 2, 1, 3 }); // (1, 1, 7, 64)
        const sin_reshaped = sin.transpose(.{ 0, 2, 1, 3 }); // (1, 1, 7, 64)

        // Apply rotary
        q = applyRotaryCosAndSin(q, cos_reshaped, sin_reshaped);
        k = applyRotaryCosAndSin(k, cos_reshaped, sin_reshaped);

        // Transpose back for attention calculation
        q = q.transpose(.{ .b, .s, .h, .hd }).rename(.{ .s = .q });
        k = k.transpose(.{ .b, .s, .h, .hd }).rename(.{ .s = .k });
        v = v.transpose(.{ .b, .s, .h, .hd }).rename(.{ .s = .k });

        // Calculate attention scores with scaling
        var attn_output = zml.nn.sdpa(q, k, v, .{
            .attn_mask = attention_mask,
            .scale = Tensor.scalar(softmax_scale, hidden_states.dtype()),
        });

        // Merge heads and prepare for output projection
        const context_layer = attn_output.merge(.{ .d = .{ .h, .hd } }).rename(.{ .q = .s });

        // Apply output projection
        return zml.call(self.o_proj, .forward, .{context_layer});
    }
};

fn applyRotaryCosAndSin(x: Tensor, cos: Tensor, sin: Tensor) Tensor {
    // Split the head dimension in half
    const half_dim = @divExact(x.dim(.hd), 2);

    // Extract real and imaginary parts (first half and second half)
    const x_real = x.slice1d(.hd, .{ .end = half_dim });
    const x_imag = x.slice1d(.hd, .{ .start = half_dim, .end = x.dim(.hd) });

    // Need to reshape cos and sin to be broadcastable with x_real and x_imag
    // We need to slice cos and sin to match the half_dim
    const cos_sliced = cos.slice1d(-1, .{ .end = half_dim });
    const sin_sliced = sin.slice1d(-1, .{ .end = half_dim });

    // Now broadcast to match x_real and x_imag shapes
    const cos_b = cos_sliced.broad(x_real.shape());
    const sin_b = sin_sliced.broad(x_imag.shape());

    // Apply rotation using cos and sin
    const real_rotated = x_real.mul(cos_b).sub(x_imag.mul(sin_b));
    const imag_rotated = x_real.mul(sin_b).add(x_imag.mul(cos_b));

    // Concatenate the rotated parts back together
    return Tensor.concatenate(&.{ real_rotated, imag_rotated }, .hd);
}

pub const GTELayer = struct {
    attn_ln: zml.nn.LayerNorm,
    attention: GTEAttention,
    mlp_ln: zml.nn.LayerNorm,
    mlp: GTEMLP,

    pub fn forward(self: GTELayer, hidden_states: Tensor, attention_mask: Tensor, cos: Tensor, sin: Tensor) Tensor {
        // First apply attention with the input
        const attn_output: Tensor = zml.call(self.attention, .forward, .{ hidden_states, attention_mask, cos, sin });

        // Add residual connection
        const attn_output_with_residual = attn_output.add(hidden_states);

        // Apply layer norm
        const normed_hidden_states: Tensor = zml.call(self.attn_ln, .forward, .{attn_output_with_residual});

        // Apply MLP
        const mlp_output: Tensor = zml.call(self.mlp, .forward, .{normed_hidden_states});

        // Add another residual connection
        const mlp_output_with_residual = mlp_output.add(normed_hidden_states);

        // Final layer norm
        return zml.call(self.mlp_ln, .forward, .{mlp_output_with_residual});
    }
};

pub const GTEEncoder = struct {
    layer: []GTELayer,

    pub fn forward(self: GTEEncoder, hidden_states: Tensor, attention_mask: ?Tensor, cos: Tensor, sin: Tensor) Tensor {
        var output = hidden_states;

        // Process through all encoder layers
        for (self.layer) |layer| {
            output = zml.call(layer, .forward, .{ output, attention_mask, cos, sin });
        }

        return output;
    }
};

pub const GTEModel = struct {
    config: GTEConfig,
    embeddings: GTEEmbeddings,
    encoder: GTEEncoder,

    pub fn init(self: *GTEModel, config: GTEConfig) void {
        self.config = config;
        for (self.encoder.layer) |*layer| {
            // Set up sharding optimizations
            layer.attention.qkv_proj.weight = layer.attention.qkv_proj.weight.withSharding(.{0});
            layer.attention.o_proj.weight = layer.attention.o_proj.weight.withSharding(.{1});

            layer.mlp.up_gate_proj.weight = layer.mlp.up_gate_proj.weight.withSharding(.{0});
            layer.mlp.down_proj.weight = layer.mlp.down_proj.weight.withSharding(.{1});

            // Set layer norm epsilon values
            layer.attn_ln.eps = config.layer_norm_eps;
            layer.mlp_ln.eps = config.layer_norm_eps;

            // Set number of attention heads
            layer.attention.num_attention_heads = config.num_attention_heads;
        }
    }

    pub fn forward(self: GTEModel, input_ids: Tensor) Tensor {
        _ = self;
        return input_ids;
    }
};
