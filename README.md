https://github.com/user-attachments/assets/78b9050a-dd2a-406b-9c5f-748d41f66ef4

## Example commands

These do not need to be run in any particular order.

```console
  # Download crates.io dependencies
$ buck2 uquery 'kind(crate_download, ...)' | xargs buck2 build

  # Check standard library and rustc using bootstrap compiler in #[cfg(bootstrap)]
$ buck2 build stage1:std[check]
$ buck2 build stage1:rustc[check]

  # Build and run stage1 compiler
$ buck2 build stage1:rustc
$ buck2 run stage1:rustc -- --version --verbose

  # Build and run stage2 compiler in #[cfg(not(bootstrap))] using stage1 compiler
$ buck2 build stage2:rustc
$ buck2 run stage2:rustc -- --version --verbose

  # Build various intermediate crates (stage1 by default)
$ buck2 build :rustc_ast
$ buck2 build :rustc_ast -m=stage2
$ buck2 build :syn-2.0.101 --target-platforms //platforms/stage1:compiler

  # Document a crate using stage0 or stage1 rustdoc
$ buck2 build :rustc_ast[doc] --show-simple-output
$ buck2 build :rustc_ast[doc] -m=stage2 --show-simple-output

  # Print rustc warnings in rendered or JSON format
$ buck2 build :rustc_ast[diag.txt] --out=-
$ buck2 build :rustc_ast[diag.json] --out=-

  # Run clippy on a crate using stage0 or stage1 clippy
$ buck2 build :rustc_ast[clippy.txt] --out=-
$ buck2 build :rustc_ast[clippy.txt] -m=stage2 --out=-

  # Expand macros
$ buck2 build :rustc_ast[expand] --out=-

  # Report documentation coverage (percentage of public APIs documented)
$ buck2 build :rustc_ast[doc-coverage] --out=- | jq

  # Produce rustc and LLVM profiling data
$ buck2 build :rustc_ast[profile][rustc_stages][raw] --show-output
$ buck2 build :rustc_ast[profile][llvm_passes] --show-output
```

## Configurations

The following execution platforms are available for use with `--target-platforms`:

- `//platforms/stage1:library`
- `//platforms/stage1:library-build-script`
- `//platforms/stage1:compiler`
- `//platforms/stage1:compiler-build-script`
- `//platforms/stage2:library`
- `//platforms/stage2:library-build-script`
- `//platforms/stage2:compiler`
- `//platforms/stage2:compiler-build-script`

The "stage1" platforms compile Rust code using stage0 downloaded rustc and
rustdoc and clippy. The "stage2" platforms use the stage1 built-from-source
tools.

The "build-script" platforms compile without optimization. These are used for
procedural macros and build.rs. The non-build-script platforms compile with a
high level of optimization.

The "build-script" and "compiler" platforms provide implicit sysroot
dependencies so that `extern crate std` is available without declaring an
explicit dependency on a crate called `std`. The non-build-script "library"
platforms require explicit specification of dependencies.

Most targets have a `default_target_platform` set so `--target-platforms` should
usually not need to be specified. Use the modifier `-m=stage2` to replace the
default stage1 target platform with the corresponding stage2 one.

## Cross-compilation

This project is set up with a bare-bones C++ toolchain that relies on a system
linker, which usually does not support linking for a different platform. But we
do support type-checking, rustdoc, and clippy for different platforms, including
both stage1 and stage2.

Use the modifiers `aarch64`, `x86_64`, `riscv64`, `linux`, `macos`, `windows`, or use
target platforms like `//platforms/cross:aarch64-unknown-linux-gnu`.

```console
  # Typecheck rustc in stage1 for aarch64 linux (two equivalent ways)
$ buck2 build stage1:rustc[check] --target-platforms //platforms/cross:aarch64-unknown-linux-gnu
$ buck2 build stage1:rustc[check] -m=aarch64 -m=linux

  # Typecheck rustc in stage2 using stage1 rustc built for the host
$ buck2 build stage2:rustc[check] -m=aarch64 -m=linux

  # Build documentation for a different platform
$ buck2 build :rustc_ast[doc] -m=aarch64 -m=linux

  # Perform clippy checks for a different platform
$ buck2 build :rustc_ast[clippy.txt] -m=aarch64 -m=linux --out=-
```

## Whole-repo checks

The commands above like `buck2 build :rustc_ast[clippy.txt]` report rustc
warnings and clippy lints from just a single crate, not its transitive
dependency graph like Cargo usually does. There is a [BXL] script for producing
warnings for a whole dependency graph of a set of targets:

[BXL]: https://buck2.build/docs/bxl

```console
  # Report warnings from every dependency of rustc:
$ buck2 bxl scripts/check.bxl:main -- --target stage1:rustc | xargs cat

  # Run clippy on every dependency of rustc:
$ buck2 bxl scripts/check.bxl:main -- --target stage1:rustc --output clippy.txt | xargs cat

  # Run clippy on every dependency of rustc and report lints in JSON:
$ buck2 bxl scripts/check.bxl:main -- --target stage1:rustc --output clippy.json | xargs cat
```

## Build speed

Several factors add to make Buck-based bootstrap consistently faster than the
Rust repo's custom x.py Cargo-based bootstrap system.

On my machine, building stage2 rustc takes about 6.5 minutes with `buck2 clean;
time buck2 build stage2:rustc` and about 8 minutes with `x.py clean && time x.py
build compiler --stage=2`. The Buck build is **20%** faster.

The difference widens when building multiple tools, not only rustc. Buck will
build an arbitrary dependency graph concurrently while x.py is limited to
building each different tool serially. `buck2 build stage2:rustc stage2:rustdoc
stage2:clippy-driver` takes +46 seconds longer than building rustc alone, because
Clippy is the long pole and takes exactly that much longer to build than
rustc\_driver, which it depends on. But the equivalent `x.py build compiler
src/tools/rustdoc src/tools/clippy --stage=2` takes +153 seconds longer than
building rustc alone, because rustdoc takes +69 seconds and clippy takes +84
seconds, and all three tools build serially. Altogether Buck is **32%** faster
at building this group of tools.

Some less significant factors that also make the Buck build faster:

- x.py builds multiple copies of many crates. For example the `tracing` crate
  and its nontrivial dependency graph are built separately when rustc depends on
  tracing versus when rustdoc depends on tracing. In the Buck build, there is
  just one build of `tracing` that both rustc and rustdoc use.

- In x.py, C++ dependencies (like the `llvm-wrapper` built by rustc\_llvm's
  build.rs) build pretty late in the build process, after a stage1 standard
  library is finished compiling, after rustc\_llvm's build-dependencies and
  build script are finished compiling. In Buck the llvm-wrapper build is one of
  the first things to build because it does not depend on any Rust code or
  anything else other than the unpack of downloaded LLVM headers.

- The previous item is exacerbated by the fact that x.py builds llvm-wrapper
  multiple times, separately for stage1 and stage2, because there is no facility
  for the stage2 compiler build's build scripts to share such artifacts with the
  stage1 build. Buck builds llvm-wrapper once because the sources are all the
  same, the same C++ compiler is used by stage1 and stage2, and the flags to the
  C++ compiler are the same, so we are really talking about one build action.
  Stage1 and stage2 differ only in what Rust compiler is used and whether
  `--cfg=bootstrap` is passed to Rust compilations, neither of which is relevant
  to a C++ compilation.

Incremental builds are faster in Buck too. After already having built it,
rebuilding rustc\_ast with a small change in its lib.rs takes 1.625 seconds with
`buck2 build :rustc_ast[check]` and 2.6 seconds with `x.py check
compiler/rustc_ast`. The actual underlying rustc command to typecheck rustc\_ast
used by both build systems takes 1.575 seconds, so Buck's overhead for this is
50 milliseconds (0.05 seconds) while x.py's and Cargo's is about 1 second, an
order of magnitude larger.

At least 2 factors contribute to x.py's overhead:

- x.py does not have a granular view of the dependency graph. At a high level it
  knows that building the compiler requires building the standard library first,
  but within the standard library or compiler it does not manage what crate
  depends on which others, and which source files go into which crate. Even when
  local changes definitely do not require rebuilding the standard library, x.py
  must still delegate to a sequence of slow serial Cargo invocations whereby
  Cargo could choose to rebuild the standard library if it were necessary (which
  it isn't), adding latency. In contrast, a single Buck process coordinates the
  entire dependency graph from top-level targets to build actions to input files
  which those actions operate on. If is quick to map from a file change to
  exactly which build actions need to be kicked off right away.

- The state of the Buck build graph is preserved in memory across CLI commands.
  Like how IDEs rely on a long-running language server (LSP) that preserves
  facts about the user's program in complex data structures in memory to serve
  IDE features with low latency, Buck does this for build graphs. In contrast,
  Cargo reloads the world each time it runs, including parsing Cargo.toml files
  and lockfiles and Cargo config files. And as mentioned, x.py will do multiple
  of these Cargo invocations serially.
