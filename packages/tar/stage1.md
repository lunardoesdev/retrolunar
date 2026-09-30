# tar build forecast — BLOCKED on Android below API 35

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.35 (`ftp.gnu.org/gnu/tar/tar-1.35.tar.xz`)
- Build system: **autotools** — `./configure` at `generic.lua:6`, with the
  timestamp guard at `:7-8`
- Would install: `bin/tar`, `lib/libgnu.a` (tar's own gnulib archive, not a
  public library), `share/info/tar.info`. **No pkg-config file.**
- Requires: `tar@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `mktime_z` is undeclared at this API level. See the evidence below. |
| aarch64-android24 | **WILL NOT BUILD** | Same symbol, same wall. |
| aarch64-android35 | WILL BUILD | `mktime_z` is declared (`__INTRODUCED_IN(35)`), so the call compiles. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | mingw-w64 provides `mktime_z` in its `time.h`/libc; no Bionic gate applies. |
| clang-native | WILL BUILD | glibc has had `mktime_z` since 2.27. |

**API level notes — the blocker, in full.**

`topackage.md:78` records "Tar 1.35 (blocked: Bionic guards mktime_z until API
35; target API24 cannot compile it)". I confirmed that against the NDK 28.2
sysroot and I can now be precise about *where* it breaks, which the backlog
entry does not say:

- `sysroot/usr/include/time.h:171` reads
  `time_t mktime_z(timezone_t, struct tm*) __INTRODUCED_IN(35);` — so at API
  21 and 24 the declaration exists but is not callable.
- The failure is a **call**, not a link and not a definition. gnulib's
  `gnu/nstrftime.c:36` does `#include <time.h>` (angle brackets — Bionic's
  header, not a gnulib replacement; there is no top-level `time.h` in the
  tarball) and then calls `mktime_z` at `nstrftime.c:1189` and `:1453`. The
  `#define mktime_z(tz, tm) mktime(tm)` shim at `nstrftime.c:120` is inside
  `#ifdef _LIBC`, which tar does not define, so it does not apply.
- I compiled a two-line reduction both ways against the real NDK wrappers:
  *calling* `mktime_z` at API 24 fails with
    `error: call to undeclared function 'mktime_z'; ISO C99 and later do not
    support implicit function declarations`;
  *defining* `mktime_z` compiles cleanly at API 21, 24 and 35.
- The definition half matters because it rules out an easy reading of the
  problem: `gnu/time_rz.c:285` **does** define its own `mktime_z`, and
  `gnu/Makefile.am:3604` compiles that file unconditionally under
  `GL_COND_OBJ_TIME_RZ`. So there is no missing symbol to link and no
  configure switch to flip — `grep -c mktime_z configure` is **0**, i.e. the
  generated `configure` contains no check for it at all. tar simply assumes
  the platform has it.

**This matches the recorded blocker, and the recipe matches the blocker**: the
recipe is a bare `./configure $AUTOCONF_CONFIGURE_FLAGS` with nothing papered
over, which is exactly right — there is no legitimate flag to add, since
`mktime_z` is not an optional feature but an unconditional gnulib dependency.
Adding a cache answer would be a lie, and AGENTS.md forbids patching upstream.

**Risks / what a reviewer should check.**
1. **Do not add `ac_cv_func_mktime_z=yes`.** That would make configure *believe*
   the function exists and push the failure from compile time to link time,
   where it is harder to read. The honest state is: blocked.
2. `make` at `generic.lua:9` is bare, which serialises by default. Same
   cosmetic observation as `packages/sed/stage1.md`.
3. If the project ever gains an Android API-35 minimum, this recipe should
   start working with no change at all — that is worth knowing, because the
   fix is a *system* change, not a recipe change.

**How to verify once built (valid for the rows that can build).**
- `bin/tar`, `share/info/tar.info`; no `lib/lib*.a` public library and no `.pc`
- `file bin/tar` → `ELF 64-bit LSB pie executable, ARM aarch64, ...`
- `llvm-objdump -f bin/tar | head` → `elf64-littleaarch64` on aarch64
- `strings bin/tar | grep -m1 'GNU tar'` for the version; the target binary
  cannot be run (no emulation)