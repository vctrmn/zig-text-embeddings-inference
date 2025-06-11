# Zig Text Embeddings Inference

A text embeddings inference server built with Zig, leveraging the power of Zig, ZML, and Zap for blazing fast HTTP serving capabilities.

## Getting Started

### Prerequisites

The project uses `bazel` as its build system, primarily because ZML is built with Bazel. This ensures compatibility and reproducible builds.

<details><summary>
MacOS installation :
</summary>

```bash
brew install bazelisk
```
</details>

<details><summary>
Linux installation (amd64) :
</summary>

```bash
curl -L -o /usr/local/bin/bazel 'https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-linux-amd64'
chmod +x /usr/local/bin/bazel
```
</details>


### Build and run the server

```bash
bazel run --config=release //:ModernBERT-large
```

```bash
bazel run --config=release --@zml//runtimes:cuda=true //:ModernBERT-large
```

## Available Models

| Model ID | Description | Status |
|----------|-------------|--------|
| `ModernBERT-large` | Answer.AI's ModernBERT large model | ✅ Available |
| `nomic-ai/modernbert-embed-base` | A ModernBERT-based embedding model from Nomic AI | ⚠️ In Progress |
| `Alibaba-NLP/gte-modernbert-base` | An improved GTE (General Text Embeddings) variant based on ModernBERT | ⚠️ In Progress |
