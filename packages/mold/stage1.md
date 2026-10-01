# stage1 — mold 2.42.1 (build forecast)

## What it is, and the native/target decision

mold is a **linker**. It is not a library: it is the program the host
compiler driver execs when a link happens. That makes it a compiler adapter
in the same sense `bear` is, and it forces the classification.

**Classified NATIVE. This package is native-only: `packages/mold/` contains
`source.lua`, `clang-native.lua` and this file, and deliberately NO
`generic.lua`.**

Justification: a cross-built mold would be an aarch64-android or
x86_64-mingw ELF sitting in `$PREFIX/bin`. It could never usefully run
during a build here, and running it to find out would be emulation, which
AGENTS.md forbids outright ("No emulation, ever"). The only mold with a use
in this tree is a host one, and the loader already puts `$NATIVE_PREFIX/bin`
first on `PATH` (src/loader.lua:412-415), so `-fuse-ld=mold` resolves to
`$NATIVE_PREFIX/bin/mold` with no further wiring.

This is the `packages/file/` shape (`file/generic.lua` +
`file/clang-native.lua`), except mold has no reason to be cross-built at
all, so only the native half exists.

## The Rust question — answered, and it is stale

The brief asked whether a source build needs a Rust toolchain this repo does
not carry. **For 2.42.1, no: there is no Rust in mold at all.**

Evidence, from the unpacked tree:

- No `Cargo.toml` and no `rust-toolchain*` at top level (`ls` on both: no
  such file).
- `find src lib -type f | sed 's/.*\.//' | sort -u` yields exactly
  `c cc cmake h in py sh`. No `.rs`.
- No `cargo` or `rustc` reference in `CMakeLists.txt` or `docs/*.md`.

The Rust premise comes from older mold releases (1.x, and 2.x up to about
2.3). Upstream migrated to C++20. `CMakeLists.txt:54` sets
`target_compile_features(mold PRIVATE cxx_std_20)`. So this is an ordinary
cmake C/C++ package and needs no cargo, which matters because this repo
carries no Rust toolchain of its own.

## Release artifacts vs source

Checked `https://github.com/rui314/mold/releases/expanded_assets/v2.42.1`.
The release publishes **prebuilt binaries only**: aarch64/arm/loongarch64/
ppc64le/riscv64/s390x/x86_64 `-linux.tar.gz` and `x86_64-windows.zip`.
Every one is a **glibc Linux** or Windows binary. There is no Android
artifact and no mingw artifact, and the linux binaries are dynamically
linked against glibc, which is not the libc in any target prefix here.

So the prebuilt binaries are not usable for any system in this repo. The
**source** tarball (`archive/refs/tags/v2.42.1.tar.gz`) does build, and
that is what `source.lua` fetches. This is therefore NOT the "no buildable
source" finding; it is the opposite — the artifacts are useless and the
source is fine.

Downloaded and verified: 14727377 bytes, matching the server
`content-length`, `tar tf` lists 3902 entries. No truncation.

## Build facts

| | |
|---|---|
| Build system | CMake, `cmake_minimum_required(VERSION 3.14)` (CMakeLists.txt:46) |
| Generated `configure` | n/a — not autotools |
| Config template | n/a; `configure_file(config.h.in)` lives in the source, and `lib/config.h.in` is upstream's own header template, not an autotools one |
| Rust | none (see above) |
| Host-only deps | none at build time; zlib/BLAKE3/zstd are vendored under `third-party/` and only searched for if already present (CMakeLists.txt:148-191) |
| Dependencies in this repo | **none needed** — `zlib`, `blake3`, `zstd`, `mimalloc` all fall back to the bundled `third-party/` copies |

## Verdicts

All six rows are **WILL NOT BUILD** as *target* packages, for one reason:
this package ships no `generic.lua` on purpose, because mold is a linker
and only the native build is meaningful. That is a classification
decision, not a defect.

| System family | Verdict | Basis |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | No `generic.lua`; native-only by design. See header. |
| aarch64-android24 | WILL NOT BUILD | Same. |
| aarch64-android35 | WILL NOT BUILD | Same. |
| x86_64-android35 | WILL NOT BUILD | Same. |
| x86_64-mingw | WILL NOT BUILD | Same, and doubly so: mold's own release assets include a Windows build but this repo's mingw prefix is not where a Linux-built mold could be used. |
| clang-native | **WILL BUILD** | The `clang-native.lua` recipe. cmake + C++20, vendored deps, no host programs, no target binary executed. `MOLD_USE_MIMALLOC=OFF` keeps the vendored mimalloc subproject out (CMakeLists.txt:201-206). |

`armv7a-*` and `i686-*` behave like `aarch64-android*` here.

## Notes for the reviewer

- `cmake --install build` is used rather than `--target install` because
  CMakeLists.txt:484-501 installs relative symlinks (`ld.mold`,
  `libexec/mold/ld`) through `install(CODE)` blocks using
  `file(RELATIVE_PATH)`; that is the supported path and works under
  `-DCMAKE_INSTALL_PREFIX=$OUT`.
- All build-system flags come from the system: `$CMAKE_FLAGS` supplies
  `-DCMAKE_INSTALL_PREFIX=$OUT` and `-DCMAKE_PREFIX_PATH=$PREFIX`
  (`packages/clang-native/generic.lua:55-57`), and `$CC`/`$CFLAGS` come
  from the clang-native setup (`:8`, `:25-26`). The only flag in the recipe
  is `-DMOLD_USE_MIMALLOC=OFF`, a package-local build decision, not a
  target fact.
- Build never fans out: `cmake --build build --parallel 1`.