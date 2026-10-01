-- mold is a LINKER, not a library: it is the program the host compiler
-- driver execs at the end of a link. A cross-built aarch64-android or
-- x86_64-mingw mold would sit in $PREFIX/bin and could never run here,
-- because running a target binary is emulation and this repo never does it
-- (AGENTS.md, 'Known platform walls'). The only mold with a use in this
-- tree is a host one on $NATIVE_PREFIX/bin, which the loader puts first on
-- PATH (src/loader.lua:412-415) so `-fuse-ld=mold` finds it.
--
-- So this package is NATIVE-ONLY and there is deliberately no generic.lua:
-- clang-native.lua is the whole build. See stage1.md for the per-system
-- verdicts, all of which are WILL NOT BUILD for a target recipe.
--
-- Build-system flags still come from the system, never hardcoded here:
-- $CMAKE_FLAGS carries -DCMAKE_INSTALL_PREFIX=$OUT and
-- -DCMAKE_PREFIX_PATH=$PREFIX (packages/clang-native/generic.lua:55-57),
-- and $CC/$CFLAGS come from the clang-native setup (:8, :25-26).
require("mold@source")

return recipe({
    build = [[
        cp -r $NESTDIR/source/mold/* .
        # CMake, not Autotools, and NOT Rust: mold 2.42.1 is pure C/C++20.
        # There is no Cargo.toml and no rust-toolchain in the tree and no
        # .rs file anywhere; the source files are c, cc, cmake, h, in, py,
        # sh only. Older mold releases were Rust, so "mold needs cargo" is
        # stale for this version: no cargo is required, and this repo
        # carries none.
        #
        # MOLD_USE_MIMALLOC=OFF: CMakeLists.txt:201-206 turns mimalloc ON by
        # default for 64-bit non-Apple/non-Android targets and builds the
        # vendored third-party/mimalloc. That is an allocator choice, not a
        # requirement, so it is off to keep the build to mold itself.
        cmake -S . -B build $CMAKE_FLAGS -DMOLD_USE_MIMALLOC=OFF
        cmake --build build --parallel 1
        # The plain install target, not --target install: CMakeLists.txt:
        # 484-501 installs relative symlinks (ld.mold, libexec/mold/ld)
        # through install(CODE) blocks that call file(RELATIVE_PATH)
        # against $CMAKE_INSTALL_PREFIX, and that is the supported path.
        cmake --install build
    ]]
})