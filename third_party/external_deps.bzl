"""Repository rules for fetching third-party dependencies."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def _external_deps_impl(mctx):
    new_git_repository(
        name = "com_github_zigzap_zap",
        remote = "https://github.com/zigzap/zap.git",
        commit = "3b06a336ef27e5ffe04075109d67e309b83a337a",
        build_file = "//:third_party/com_github_zigzap_zap/zap.BUILD",
        patch_cmds = [
            """sed -i'.bak' 's/inline static uint8_t seek2ch/inline static uint8_t facil_seek2ch/g' facil.io/lib/facil/redis/resp_parser.h""",
            """sed -i'.bak' 's/static ws_s \\*new_websocket();/static ws_s \\*new_websocket(intptr_t uuid);/g' facil.io/lib/facil/http/websockets.c""",
        ],
    )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

external_deps = module_extension(
    implementation = _external_deps_impl,
)
