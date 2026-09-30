ACCEPT

# zopfli 1.0.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`zopfli-1.0.3` tree. I did not build anything.

## What the recipe does right

- `source.lua`: the tag is `zopfli-1.0.3` (not `v1.0.3`) and the recipe has it
  right. I re-queried the tags API: `zopfli-1.0.3, zopfli-1.0.2, zopfli-1.0.1,
  zopfli-1.0.0` — there is genuinely no newer zopfli release; the "1.0.4-1.0.8"
  versions people cite are Chromium-internal copies. URL 200, 195 227 B, top dir
  `zopfli-zopfli-1.0.3/` (the doubled name is real; `--strip-components=1`
  absorbs it). Guarded download, `curl -C -` resume, `rm -rf src`,
  `mkdir -p $OUT/zopfli`.
- `generic.lua` requires only `zopfli@source`. No missing package, no
  `@native` host tool needed.
- Every build-system flag comes from `$CMAKE_FLAGS`; `-DZOPFLI_BUILD_SHARED=OFF`
  is a package choice (this prefix is static), not a target fact. No `export`,
  no hardcoded architecture/triplet/API level, no `-I`/`-L`, no `sed`, no
  patch, no `/dev/null`, serial build, install into `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `cmake_minimum_required(VERSION 2.8.11)` (`CMakeLists.txt:1`) is below cmake
  4's floor, and the recipe relies on `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` from
  `$CMAKE_FLAGS` rather than hardcoding a floor — which is exactly the division
  of labour AGENTS.md prescribes. I confirmed that flag is present in all three
  systems I checked (`aarch64-android24:128`, `x86_64-mingw:69`,
  `clang-native:57`).
- zopfli's CMake has **no `check_*`, no `try_run`, no `find_package`**, so
  `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` is never exercised and no
  target binary is ever run. The recipe never runs `$OUT/bin/*`.
- `stage1.md` is the most honest document in my ten: it names the six-year-old
  upstream, the missing release assets, the doubled top-level directory, the
  deliberate decision to ship two unrunnable target executables, and — crucially
  — it says outright which row is "the least-proven of the six" and what single
  compile would settle it. That is a forecast telling the truth about its own
  confidence, which is what I want.

## The one thing a reviewer must accept rather than "fix"

`CMakeLists.txt:136` and `:145` are unconditional
`add_executable(zopfli ...)` / `add_executable(zopflipng ...)`. There is **no
upstream option that turns them off**, and they share one `install(TARGETS
libzopfli libzopflipng zopfli zopflipng EXPORT ZopfliTargets ...)` at `:167`.
AGENTS.md's "a cross build must not compile [tests, benchmarks, examples, CLI
tools]" is about *host* programs; these two are the package's own target
deliverables, and they are never run. So building them is correct, and
suppressing them would need a patch, which AGENTS.md forbids. The recipe's
comment says exactly this. Correct as written.

## Non-blocking observation

- `ZOPFLI_DEFAULT_RELEASE` is ON (`CMakeLists.txt:46-53`), so an empty
  `CMAKE_BUILD_TYPE` becomes `Release` and `-O3` applies. That coexists fine
  with the `-O2 -fPIC` in `$CFLAGS`; `stage1.md` covers it. No change wanted.

## Carried to the build

Expected under `$NESTDIR/<sys>/`:

| Artifact | The one check that proves it |
| --- | --- |
| `lib/libzopfli.a` | `llvm-objdump -f lib/libzopfli.a \| head -3` shows `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw) |
| `lib/libzopflipng.a` | same; also `llvm-nm --defined-only lib/libzopflipng.a` shows the C++ (mangled) symbols, proving the C++ half really compiled |
| `include/zopfli.h`, `include/zopflipng_lib.h` | `[ -f include/zopfli.h ] && [ -f include/zopflipng_lib.h ]` |
| `bin/zopfli`, `bin/zopflipng` | `[ -x bin/zopfli ]` — **target binaries, never to be run** (no QEMU, no emulator, per AGENTS.md). Their presence is expected; executing them is forbidden. |
| `lib/cmake/Zopfli/ZopfliConfig.cmake`, `ZopfliConfigVersion.cmake` | `[ -f lib/cmake/Zopfli/ZopfliConfig.cmake ]` |

**There is no pkg-config file and there must not be one** — zopfli ships no
`*.pc.in` anywhere in the tarball (I checked). A missing
`pkg-config --modversion zopfli` is correct, not a failure.

**On `x86_64-mingw`:** `target_link_libraries(libzopfli m)` at `:99` is gated on
`if(UNIX AND NOT (BEOS OR HAIKU))`, and `UNIX` is unset with
`CMAKE_SYSTEM_NAME Windows`, so no `-lm` is added — correct for that target.
The C++ risk on mingw is the compiler default dialect (`gnu++17`) applied to
2015-vintage lodepng; if the build fails there, that file set
(`src/zopflipng/lodepng/*.cpp`) is where to look, and the fallback is
`-DCMAKE_CXX_STANDARD=11`, not a patch.

Rerun should print `skip ... (fresh)`.
