# xxhash build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.8.2 (`github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.2.tar.gz`)
- Build system: **CMake**, and **not at the top level** — `generic.lua:9` passes
  `-S cmake_unofficial`
- Installs: `lib/libxxhash.a`, `include/xxhash.h`,
  `lib/pkgconfig/libxxhash.pc`, plus the `bin/xxhsum` tool
- Requires: `xxhash@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library is `xxhash.c`, a single self-contained C file using only `<stdint.h>`, `<string.h>`, `<stdlib.h>` and `<stdio.h>`. `XXH_VECTOR` autodetects from the compiler macros (`__SSE2__`/`__ARM_NEON`) and falls back to the scalar path when none applies — so no arch-specific source list and no missing-ISA wall. Nothing API-24+. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; the SSE2 path is selected by the compiler, not by a CMake option. |
| x86_64-mingw | WILL BUILD | As above. xxhash's CMake has no WIN32 source split. |
| clang-native | WILL BUILD | Native; same single file. |

**API level notes.** **No new wall.** xxhash's entire libc surface is
`malloc`/`free` (only in the one-shot streaming helpers) and `memcpy`/
`memset`. There is no file I/O in the library at all — that is `xxhsum`'s job —
so nothing can reach a POSIX or API-gated symbol. The API level is inert.

**Risks / what a reviewer should check.**
1. **`-S cmake_unofficial` is the recipe's most important line** and the
   comment at `generic.lua:6-8` says why: upstream's CMake build lives in
   `cmake_unofficial/`, not at the top level. Anyone "simplifying" this to
   `cmake -S . -B build` gets a configure error, because the tag archive's
   root has no `CMakeLists.txt` — it has a hand-written `Makefile` and the
   subdirectory. Preserve the `-S`.
2. **`xxhsum` is installed and is a target binary** (`generic.lua:8` calls this
   out as acceptable: "nothing here ever runs a target binary"). That is the
   right call — the tool is the only practical way to exercise the library from
   the target side, and it costs one small executable.
3. **`-DBUILD_SHARED_LIBS=OFF`** is the load-bearing flag; xxhash's CMake honours
   it and would otherwise install `libxxhash.so.0.8.2` with a versioned soname.
4. **No tests or benchmarks are turned off**, unlike most cmake recipes here.
   That is correct for xxhash: `cmake_unofficial/CMakeLists.txt` builds the
   library and `xxhsum` only — the test suite lives in the root `Makefile` and
   the `tests/` directory, which this build system never adds. Worth recording
   so nobody adds a flag that does nothing.
5. **The `.pc` name is `libxxhash`**, not `xxhash`. Easy to get wrong in a
   consumer's `pkg-config` line.
6. 0.8.2 is the current release line.

**How to verify once built.**
- `lib/libxxhash.a`, `include/xxhash.h`, `lib/pkgconfig/libxxhash.pc`,
  `bin/xxhsum`
- `pkg-config --modversion libxxhash` → `0.8.2` (note the `lib` prefix — risk 5)
- `llvm-objdump -f lib/libxxhash.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libxxhash.a | grep -c XXH64_` → non-zero
- `file bin/xxhsum` → `ELF 64-bit LSB pie executable, ARM aarch64`. It **cannot
  be run** on the build host (no emulation); check the version statically with
  `strings bin/xxhsum | grep -m1 0.8.2`
- `find $PREFIX/lib -name 'libxxhash.so*'` must be **empty**