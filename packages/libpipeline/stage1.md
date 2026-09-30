# libpipeline forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.5.8
- Build system: autotools
- Installs: `libpipeline.so` **and** `libpipeline.a` (the recipe passes no
  `--enable-shared`/`--disable-shared`, so both), the `libpipeline/` headers,
  and `libpipeline.pc`.
- Requires: `libpipeline@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe is a bare `./configure $AUTOCONF_CONFIGURE_FLAGS` (`:7`) with no switches, plus the timestamp guard. libpipeline is a shell-pipeline library that uses `pipe`, `fork`, `dup2`, `execvp` and `waitpid` — all of which Bionic has at every API level, and none of which the recipe's own program (if any) would need. The *library* builds; what is worth noting is below. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | **WILL NOT BUILD** | libpipeline is POSIX `fork`/`exec`/`pipe` code with no Windows port and no `HAVE_*` fallback for it. mingw-w64 provides a `fork()` emulation, but libpipeline also needs `sigaction`, `sigprocmask`, `setpgid` and process-group semantics that mingw does not offer. The configure would likely succeed and the link or the semantics would not. |
| clang-native | WILL BUILD | As above; the host is the platform libpipeline targets. |

**API level notes.** The `fork`/`exec` family is present at every Bionic level,
so the API level is not a variable for the *library*. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The real question is whether this package belongs in this prefix at
   all.** libpipeline's entire purpose is to run shell pipelines. Android has
   no shell, no `/bin/sh` in the app sandbox, and no use for
   `execvp("/bin/cat", …)`. The library will *build* on every Android system
   and *link*, and nothing on the target will ever call it. This is worth
   saying before anyone treats a green build as validation.
2. **It builds a shared library here** — `topackage.md:49` records
   *"libpipeline.so is 'ELF 64-bit LSB shared object, ARM aarch64, for Android
   24, built by NDK r28c'"*. So the recipe's lack of a `--disable-shared`
   means this package is one of the few in the tree producing a `.so`, with
   the versioned-soname and loader-path implications that carries. A consumer
   must know which to ask for; `pkg-config --libs libpipeline` prefers the
   shared one.
3. **The source URL comment is worth keeping.** `topackage.md:49` records that
   `rctg.com` (upstream's historical host) now serves a parked-domain page,
   which is why the recipe uses the Savannah mirror. If anyone "simplifies"
   the URL back to rctg, the fetch dies with a confusing HTTP 200 and an HTML
   body.
4. **A latent platform trap the recipe does not address:** libpipeline's
   `filter-*` modules and its `libpipeline` core reference `/bin/sh` paths
   (`SHELL` macro) and use `PATH` lookups. Those are *string* constants, so
   they compile; they only fail at runtime. Nothing here can detect that, and
   nothing should try — the point is only that a green build is not a
   functional result for this package.
5. `make` at `:11` is not `make -j1` — the same rule deviation as kbd, less,
   libffi and others.
6. `topackage.md:49` is accurate: version, build result and the URL note all
   match the recipe.

**How to verify once built.**

- `lib/libpipeline.a` and `lib/libpipeline.so` both exist;
  `include/libpipeline.h` exists.
- `pkg-config --modversion libpipeline` reports 1.5.8.
- `file lib/libpipeline.so` reports `ELF 64-bit LSB shared object, ARM
  aarch64, for Android 24, built by NDK r28c` — the exact string
  `topackage.md:49` already recorded.
- `llvm-nm -D --defined-only lib/libpipeline.so | grep -cw pipeline_new` must be
  non-zero.
- `grep -rn '/bin/sh' lib/` will match: that is upstream's shell path, and it
  is a reminder that this library is not functional on the target.
