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

⚠️ WIP ⚠️
```bash
bazel run -c opt //:ModernBERT-large
```

```bash
bazel run -c opt --@zml//runtimes:cuda=true //:ModernBERT-large
```