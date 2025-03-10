"""Defines non-module dependencies required by the project.

Non-module dependencies are external dependencies that are not managed 
through Bazel's bzlmod module system (i.e., they do not have a MODULE.bazel file). 
These dependencies must be fetched manually using repository rules like 
new_git_repository.

This file ensures that such dependencies are available for the build process.
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def _non_module_deps_impl(mctx):
    new_git_repository(
        name = "com_github_zigzap_zap",
        remote = "https://github.com/zigzap/zap.git",
        tag = "v0.9.1",
        build_file = "//:third_party/com_github_zigzap_zap/zap.bazel",
    )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

non_module_deps = module_extension(
    implementation = _non_module_deps_impl,
)
