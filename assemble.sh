#!/bin/bash
rm -rf ./sysroot

cp -rL $(buck2 build stage2:sysroot --show-simple-output) ./sysroot
mkdir -p ./sysroot/bin
cp $(buck2 build stage2:rustc --show-simple-output) ./sysroot/bin/rustc
cp $(buck2 build //stage0:ci_llvm --show-simple-output)/lib/libLLVM.so.20.1-rust-1.87.0-nightly ./sysroot/lib/libLLVM.so.20.1-rust-1.87.0-nightly

./sysroot/bin/rustc --version --verbose
