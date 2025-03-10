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
Windows installation :
</summary>

```bash
choco install bazelisk
```
</details>


### Build and run the server
```bash
bazel run -c opt //:server
```

## Project structure
```
.
├── MODULE.bazel        # Bazel module definition with dependencies (ZML, Zap, rules_zig)
├── server
│   ├── BUILD.bazel     # Server build configuration using zig_binary rule
│   └── main.zig        # Server implementation with Zap HTTP server
└── third_party         # Contains Zig modules (e.g. Zap, ZML)
```