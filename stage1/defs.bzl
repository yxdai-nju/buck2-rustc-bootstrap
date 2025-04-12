load("@prelude//linking:link_info.bzl", "LinkStrategy")
load("@prelude//rust:build_params.bzl", "MetadataKind")
load("@prelude//rust:context.bzl", "DepCollectionContext")
load("@prelude//rust:link_info.bzl", "RustDependency", "RustLinkInfo", "resolve_deps")
load("@prelude//rust:rust_toolchain.bzl", "PanicRuntime", "RustToolchainInfo")

SYSROOT_CRATES = [
    "alloc",
    "compiler_builtins",
    "core",
    "panic_abort",
    "panic_unwind",
    "proc_macro",
    "std",
    "test",
]

def _rust_tool_impl(ctx: AnalysisContext) -> list[Provider]:
    llvm = ctx.actions.symlinked_dir(
        "llvm",
        {
            "lib": ctx.attrs.llvm[DefaultInfo].default_outputs[0].project("lib"),
        },
    )

    bin_path = "bin/{}".format(ctx.label.name)
    dist = ctx.actions.copied_dir(
        "toolchain",
        {
            bin_path: ctx.attrs.exe[DefaultInfo].default_outputs[0],
            "lib": llvm.project("lib"),
        },
    )

    tool = dist.project(bin_path)

    return [
        DefaultInfo(
            default_output = tool,
            sub_targets = {
                name: [providers[DefaultInfo]]
                for name, providers in ctx.attrs.exe[DefaultInfo].sub_targets.items()
            },
        ),
        RunInfo(tool),
    ]

rust_tool = rule(
    impl = _rust_tool_impl,
    attrs = {
        "exe": attrs.dep(),
        "llvm": attrs.dep(),
    },
    supports_incoming_transition = True,
)

def _sysroot_impl(ctx: AnalysisContext) -> list[Provider]:
    dep_ctx = DepCollectionContext(
        advanced_unstable_linking = True,
        include_doc_deps = False,
        is_proc_macro = False,
        explicit_sysroot_deps = None,
        panic_runtime = PanicRuntime("unwind"),
    )

    all_deps = resolve_deps(ctx = ctx, dep_ctx = dep_ctx)

    rust_deps = []
    for crate in all_deps:
        rust_deps.append(RustDependency(
            info = crate.dep[RustLinkInfo],
            label = crate.dep.label,
            dep = crate.dep,
            name = crate.name,
            flags = crate.flags,
            proc_macro_marker = None,
        ))

    rustc_target_triple = ctx.attrs.rust_toolchain[RustToolchainInfo].rustc_target_triple

    sysroot = {}
    for dep in rust_deps:
        strategy = dep.info.strategies[LinkStrategy("static_pic")]
        dep_metadata_kind = MetadataKind("full")
        artifact = strategy.outputs[dep_metadata_kind]
        path = "lib/rustlib/{}/lib/{}".format(rustc_target_triple, artifact.basename)
        sysroot[path] = artifact

        for artifact in strategy.transitive_deps[dep_metadata_kind].keys():
            path = "lib/rustlib/{}/lib/{}".format(rustc_target_triple, artifact.basename)
            sysroot[path] = artifact

    sysroot = ctx.actions.symlinked_dir("sysroot", sysroot)
    return [DefaultInfo(default_output = sysroot)]

sysroot = rule(
    impl = _sysroot_impl,
    attrs = {
        "deps": attrs.list(attrs.dep()),
        "named_deps": attrs.default_only(attrs.dict(key = attrs.string(), value = attrs.dep(), default = {})),
        "flagged_deps": attrs.default_only(attrs.list(attrs.tuple(attrs.dep(), attrs.list(attrs.string())), default = [])),
        "rust_toolchain": attrs.default_only(attrs.toolchain_dep(providers = [RustToolchainInfo], default = "toolchains//:rust")),
    },
    supports_incoming_transition = True,
)
