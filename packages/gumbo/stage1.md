# gumbo build forecast

- Recipe: `generic.lua`, source `source.lua` (no `android.lua`)
- Version pinned: 0.14.0
- Build system: **meson** (`meson.build`, `meson_options.txt`)
- Header-only: **no.** A real C99 parser library.
- Installs: `lib/libgumbo.a`, `include/gumbo.h`, `include/tag_enum.h`
  (`meson.build:66`), `lib/pkgconfig/gumbo.pc` (`:68-69`). No CMake package
  config — this project ships no `CMakeLists.txt` at all.
- Requires: `gumbo@source` only. No library dependencies (the project vendors
  its own gzip/inflate in `src/physfs_miniz.h`-style form: `src/miniz.h`).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `tests=false` removes the only C++ and the only `dependency()` in the file. What remains is 13 C sources (`meson.build:14-27`) compiled as C99 with `-Ddefault_library=static`. gumbo parses bytes; it touches no libc facility that API 21 lacks. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `meson.build` has no per-platform branch at all, and static-only removes any DLL question. |
| clang-native | **WILL NOT BUILD** | Not a compile failure — an **install-target failure**. `packages/clang-native/generic.lua` exports no `MESON_FLAGS` and there is no native meson cross file, so `meson setup build $MESON_FLAGS` expands to no `--prefix` and meson falls back to its default `/usr/local`. The build succeeds but nothing lands in `$OUT`, so the package is not installed where the nest expects it and `cp -rf "$OUT"/. "$NESTDIR/<sys>/"` publishes an empty tree. See "The clang-native blocker" below. |

`armv7a-*` and `i686-*` match the `aarch64-*` rows.

## Two premises in the brief that do not hold

**1. There is no CMake build.** I checked both candidates. `google/gumbo-parser`
v0.10.1 has no `CMakeLists.txt` anywhere in the tree (`find` over the
extracted tarball returned nothing) — only `Makefile.am`/`configure.ac`, a
`.gyp`, and MSVC project files. `GerHobbelt/gumbo-parser` master likewise has
no `CMakeLists.txt` (`raw.githubusercontent.com/.../CMakeLists.txt` → 404);
it adds `meson.build` alongside the autotools files. **meson is the real,
supported build**, so that is what the recipe uses.

**2. Upstream is archived; the recipe pins a fork.** `google/gumbo-parser`
displays "This repository was archived by the owner on **Jan 21, 2026**. It
is now read-only." and has had no development since 2016; its newest tag is
`v0.10.1` from 2015. Two further reasons not to use it: it ships **no
generated `configure`** (only `configure.ac` + `autogen.sh`, which runs
`libtoolize`, `aclocal -I m4`, `autoconf` and `automake --add-missing` —
host autotools inside a cross build, and no recipe in this tree does that),
and its tarball has **empty `testdata/` and `third_party/gtest/` directories**
because both are git submodules (`.gitmodules`) that GitHub's archive
excludes. `GerHobbelt/gumbo-parser` is the maintained successor — its README
states it "adheres to all the original ideas of the archived GitHub
repository, which has not seen any development since 2016" — and carries
releases through 0.14.0. Recorded in `source.lua`.

**On the config template:** neither candidate has one, and the reason is
explicit, not an oversight — `configure.ac:8` reads
`#AC_CONFIG_HEADERS([config.h])`, commented out. There is no
`AC_CONFIG_HEADERS` anywhere, so per AGENTS.md the correct move is to **drop
the template from the touch list rather than relocate it**, and since this
recipe uses meson there is no autotools timestamp guard to write at all.

## The clang-native blocker

`meson setup build $MESON_FLAGS …` is correct on all four cross systems,
which set `MESON_FLAGS="--prefix=$OUT --cross-file $MESON_CROSS_FILE"`. But
`packages/clang-native/generic.lua` exports **no `MESON_FLAGS` and no
`MESON_CROSS_FILE`** — I grepped the whole directory; there is no meson
support in the native system at all.

This is a **system-level gap, not a recipe defect**, and per AGENTS.md it
belongs in `packages/clang-native/generic.lua` (a `MESON_FLAGS="--prefix=$OUT"`
line alongside the existing `CMAKE_FLAGS` section). I have not made that
change: it is outside my five packages and other agents are working in this
tree. The recipe is deliberately left system-neutral — hardcoding
`--prefix=$OUT` in `generic.lua` would duplicate a system fact and break the
moment the system file grows the variable.

Note this is a pre-existing condition, not something gumbo introduces:
`packages/fribidi/generic.lua` and `packages/kmod/generic.lua` have exactly
the same `$MESON_FLAGS` pattern and would hit the same wall, yet fribidi's
`stage1.md` records clang-native as WILL BUILD. A reviewer should treat that
row as unverified.

## Risks / what a reviewer should check

1. **`-Dtests=false` is load-bearing.** `meson_options.txt` defaults `tests`
   to **true**, and `meson.build:87-118` then does `add_languages('cpp')`,
   `dependency('gtest_main')` and builds an 11-file C++17 test executable,
   plus `test('gumbo_test', …)` at `:117` which **runs it**. A missing
   `gtest_main` is a hard configure error; running a target binary on a cross
   build is forbidden outright.
2. **`default_library=static` is required, not cosmetic.** `meson.build:5`
   sets `default_options: ['c_std=c99', 'default_library=both']` and meson
   defaults to shared anyway. The library carries `version: '4.0.0'`
   (`:61`), so a shared build would install `libgumbo.so.4.0.0` with a
   soname a target prefix has no loader path for.
3. **`-Dpython=false` is not redundant with `-Ddefault_library=static`** —
   `meson.build:72-74` *errors out* if `python` is on and
   `default_library == 'static'`. It already defaults false, but passing it
   makes the constraint legible. `examples` and `fuzz` likewise already
   default false (`:120`, `:138`); `fuzz` additionally requires clang and
   libFuzzer and injects `-fsanitize=…` project-wide (`:29-56`).
4. **Install layout is minimal and correct.** `install_headers('src/gumbo.h',
   'src/tag_enum.h')` at `:66` puts both public headers *flat* in
   `include/` — `tag_enum.h` is a second public header that a hand-written
   file list would miss, since it lives beside the sources, not in a
   subdirectory. There is no `include/gumbo/` subdirectory.
5. **`gumbo.pc` is generated, not templated.** `pkg.generate(...)` at
   `:68-69` writes `$OUT/lib/pkgconfig/gumbo.pc`; upstream's `gumbo.pc.in`
   (autotools path) is never used on the meson path. The loader's
   `$OUT`→`$PREFIX` staged-`.pc` rewrite therefore applies to a file meson
   wrote, which is exactly the intended case.

## How to verify once built

- `lib/libgumbo.a` exists. **No `libgumbo.so*`** anywhere — that is the check
  that `-Ddefault_library=static` took.
- `include/gumbo.h` **and `include/tag_enum.h`** both exist.
- `pkg-config --modversion gumbo` reports 0.14.0 — **the module name is
  `gumbo`**, from `filebase: 'gumbo'` at `:69`.
- **`find $OUT -name 'gumbo_test*'` must return nothing**, and no `gumbo.pc`
  should carry `Requires: gtest`. Both are the positive proof that
  `-Dtests=false` took effect (risk 1).
- No executables at all under `$OUT/bin` — examples and the test binary are
  all `install: false` (`meson.build:114`, `:134`, `:146`), and nothing else
  in the project installs a program.
