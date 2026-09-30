# libuv build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.51.0 (git tag archive — libuv ships no release assets)
- Build system: CMake
- Installs: static `libuv.a`, `uv.h` and the `uv/` headers,
  `libuv.pc`, and a `libuv` CMake package config. **Tools are on** — `uv_run`
  (the `bin/` launcher), `luvc` (the library-configuration query tool) and
  `luv_echo`.
- Requires: `libuv@source` only. No dependencies (docs would need curl, which
  is why `LIBUV_ENABLE_DOCS=OFF`).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD (compile) | `LIBUV_BUILD_SHARED=OFF` gives the static archive; `LIBUV_BUILD_TESTS=OFF` and `LIBUV_BUILD_BENCH=OFF` remove the test suite and microbenchmark, both host programs; `LIBUV_ENABLE_DOCS=OFF` avoids a curl dependency. The compile itself is fine. |
| aarch64-android24 | WILL BUILD (compile) | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above, and the best-behaved row: libuv's `uv_spawn` uses `posix_spawn` where available, and `spawn.h` declares it `__INTRODUCED_IN(28)` (verified in the NDK sysroot), so at API 35 libuv takes its `posix_spawn` path. Below 28 it must fall back to `fork`/`exec`. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; libuv's Windows backend is its most-used path upstream. |
| clang-native | WILL BUILD | As above. |

**API level notes — and this is the one to read carefully.**

`topackage.md:62` records ninja as blocked with *"Android 24 NDK hides
posix_spawn APIs introduced in API 28"*, and I confirmed that directly:
`$SYSROOT/usr/include/spawn.h:60` declares
`posix_spawn(...) __INTRODUCED_IN(28)`, and `llvm-nm` on the sysroot's
`libc.a` finds exactly one `posix_spawn` match. So below API 28 the symbol is
not declared.

**libuv does not trip on this**, and the difference is instructive. libuv's
`src/unix/process.c` has an explicit `#if defined(__linux__) && !defined(…)`
guarded `uv__spawn_and_init_child_posix_spawn` path with a `fork`/`exec`
fallback, chosen by a configure check. It *degrades* rather than failing. Ninja
calls `posix_spawn` unconditionally, which is why it is blocked and libuv is
not. So: **21 and 24 build, with a slower process-spawn path.** The API level
is a performance variable here, not a correctness one.

**Risks / what a reviewer should check.**

1. **The recipe's own comment claims the tools are "the only way to exercise a
   libuv build from the target side" (`generic.lua:9-10`) — and that is
   self-contradictory under this repo's rules.** Nothing here may be executed:
   AGENTS.md:373-379 forbids running a target binary under any emulator, and
   there is no emulator. So `uv_run`, `luvc` and `luv_echo` can be *built* and
   *statically inspected*, never run. The comment should be read as "they are
   cheap to build and useful for a consumer to run on its own device", not as
   a claim that this prefix can test them. **This is the most important thing a
   reviewer should take from this file.** Every other recipe in the shard turns
   host programs off; this one deliberately keeps three, which is defensible
   (they are tiny and genuinely part of libuv's public surface) but the
   justification as written is wrong.
2. **Because the tools are on, a reviewer should check the build does not try
   to run them.** CMake's install step does not, and there is no
   `enable_testing()` in libuv's build, so this should be clean. But it is
   worth watching for in the log, precisely because it is the one package here
   that installs executables from a library build.
3. **libuv has no release tarballs** — `source.lua` uses the git tag archive,
   which is correct and matches the AGENTS.md:149-173 git-clone guidance in
   spirit (a tag archive rather than a clone, which is the more reproducible
   of the two).
4. `topackage.md` records this as built: *"static libuv.a, uv.h and uv/,
   CMake package config"*. Consistent — and note it does not mention the
   tools, which is a small gap in the entry given the recipe deliberately
   keeps them.
5. `cmake --build build --parallel 1` is correct (`:15`).

**How to verify once built.**

- `lib/libuv.a` exists; `include/uv.h` and `include/uv/` exist.
- `pkg-config --modversion libuv` reports 1.51.0.
- `bin/uv_run`, `bin/luvc`, `bin/luv_echo` exist (the recipe's deliberate
  choice).
- `file bin/luvc` reports `ELF 64-bit LSB pie executable, ARM aarch64, for
  Android 24, built by NDK r28c` — static proof it is a target binary.
- `$OBJDUMP -f lib/libuv.a` prints `elf64-littleaarch64`.
- `llvm-nm --undefined-only lib/libuv.a | grep -cw posix_spawn` tells you
  which path was taken: **1** means the API-35 fast path, **0** means the
  fork/exec fallback. That is the direct check of the API-level note above.
- **Do not run `luvc` or `uv_run`.** Use `llvm-nm`/`file` only.
