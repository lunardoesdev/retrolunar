# zstd build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.5.7
  (`github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz`)
- Build system: **plain make** — `generic.lua:9-12` runs four `make -C`
  invocations against `lib/` and `programs/`. No configure, no cmake.
- Installs: `lib/libzstd.a`, `include/zstd.h`, `lib/pkgconfig/libzstd.pc`,
  `bin/zstd`, `bin/zstdgrep`, `bin/zstdless`, `bin/zstdcat`,
  `bin/zstdlessless`
- Requires: `zstd@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `HAVE_LZMA=0 HAVE_ZLIB=0` (`generic.lua:9`) removes the only two optional library dependencies, so nothing outside libc is linked. `bin/zstdgrep` is compiled with `HAVE_GREP_LOCALE=0` by default in the `programs/` Makefile for exactly this reason (it would otherwise need `iconv_l`/GNU grep emulation that Bionic lacks, and Bionic has no separate `-liconv` at all). The `lib/` sources use only `mmap`, `malloc`, `pthread_create` (optional, off by default) and stdio. **Bionic keeps pthreads in libc with no `-lpthread`**, which matters here: with `ZSTD_MULTITHREAD` off, the build never asks for a thread library, so there is no `-lpthread` to fail on. Nothing API-24+. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; zstd's x86-64 assembly is selected by `__x86_64__` and needs no runtime support. |
| x86_64-mingw | WILL BUILD | As above. zstd's `lib/Makefile` and `programs/Makefile` both have a Windows branch using `$(WINDRES)` if set; the recipe does not pass one, and zstd's default is to skip the icon, so no resource compiler is required. |
| clang-native | WILL BUILD | Native; same flags. |

**API level notes.** **No new wall.** zstd's libc surface is `mmap`/`munmap`,
`fopen`/`fread`/`fwrite`/`read`/`write`, `malloc`/`calloc`/`realloc`/`free`,
`memcpy`/`memcmp`, and — only in the CLI, not the library —
`isatty`, `readlink`, `utimensat`/`futimens`. All present at API 21. It does not
use `mktime_z` (API 35), `nl_langinfo` (API 26) or `posix_spawn` (API 28). The
API level is inert.

**Risks / what a reviewer should check.**
1. **`HAVE_LZMA=0`/`HAVE_ZLIB=0` on all four invocations is load-bearing and is
   almost certainly a Bionic-driven workaround.** zstd's `programs/Makefile`
   links `liblzma` and `libz` by default when it finds them. Leaving them on
   would work on `clang-native` but not on a bare prefix. Passing them on the
   **command line rather than exporting** is also the right call — AGENTS.md
   forbids `export CPPFLAGS/LDFLAGS/CFLAGS` in a recipe, and these are
   make-variables, not compiler flags, so no rule is stretched.
2. **`ZLIB_PREFIX="$PREFIX"` is passed even with `HAVE_ZLIB=0`.** That looks
   redundant. It is harmless (the variable is simply unused when the feature is
   off) but a reviewer may want it removed for clarity, or kept as a belt-and-
   braces measure in case a future zstd ignores `HAVE_ZLIB=0`.
3. **The recipe's purpose in the tree is recorded at `topackage.md:89`**: it
   "also unblocks Kmod's zstd compression backend". That means this package is a
   *dependency* of `packages/kmod`, so a regression here is not cosmetic.
4. **The comment at `generic.lua:6-8` records the reason the recipe compiles
   from source** — the release tarball ships prebuilt object files for common
   targets, which is a genuine upstream packaging choice that would otherwise
   silently give you an x86-64 `.o` in an aarch64 archive. **This is the single
   most valuable line in the file** and it is exactly the kind of "someone hit
   a wall" documentation AGENTS.md asks for. The `make -C lib` without a target
   is what recompiles rather than reuses `lib/objdeps`.
5. **`PREFIX="$OUT"` and `LIBDIR="$OUT/lib"`** are passed because zstd's
   hand-written Makefiles use those exact variable names for their install
   rules — they are not autoconf and know nothing about `$AUTOCONF_CONFIGURE_FLAGS`.
   Correct per AGENTS.md:213-217.
6. **`-j1` is absent.** `make -C lib` serialises by default, satisfying
   AGENTS.md, but again by default rather than by intent.

**How to verify once built.**
- `lib/libzstd.a`, `include/zstd.h`, `lib/pkgconfig/libzstd.pc`, `bin/zstd`
- `pkg-config --modversion libzstd` → `1.5.7`; `topackage.md:89` records this
  exact check succeeding, so it is the known-good verification
- `llvm-objdump -f bin/zstd | head` → `elf64-littleaarch64`; `file bin/zstd`
  should match the string in `topackage.md:89`
- **Check risk 4 concretely:** `llvm-objdump -f lib/libzstd.a | head` must show
  `elf64-littleaarch64`, and `llvm-objdump -f lib/libzstd.a | grep -c
  elf64-x86-64` must be **0**. A prebuilt-object leak shows up here and nowhere
  else — and it would be a *silently* wrong archive, not a build failure.
- `llvm-nm -u lib/libzstd.a | grep -cE 'lzma|deflate'` must be **0**, proving
  `HAVE_LZMA=0 HAVE_ZLIB=0` took effect (risk 1)
- `llvm-nm -u lib/libzstd.a | grep -c pthread_create` must be **0** unless
  multithreading was explicitly enabled — Bionic has no `-lpthread`
- `strings bin/zstd | grep -m1 'v1.5.7'` — the binary cannot be run (no
  emulation)