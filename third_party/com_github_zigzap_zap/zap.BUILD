load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_zig//zig:defs.bzl", "zig_library")

cc_library(
    name = "facil_io",
    srcs = glob(
        [
            "facil.io/lib/**/*.c",
        ],
        exclude = [
            "facil.io/lib/facil/legacy/fio_mem.c",
        ],
    ),
    hdrs = glob([
        "facil.io/lib/**/*.h",
    ]),
    includes = [
        "facil.io/lib",
        "facil.io/lib/facil",
        "facil.io/lib/facil/cli",
        "facil.io/lib/facil/fiobj",
        "facil.io/lib/facil/http",
        "facil.io/lib/facil/http/parsers",
        "facil.io/lib/facil/legacy",
        "facil.io/lib/facil/redis",
        "facil.io/lib/facil/tls",
    ],
    linkopts = [
        "-lc",
    ],
    visibility = ["//visibility:public"],
)

zig_library(
    name = "zap",
    srcs = glob([
        "**/*.zig",
    ]),
    import_name = "zap",
    main = "src/zap.zig",
    visibility = ["//visibility:public"],
    deps = [
        ":facil_io",
    ],
)
