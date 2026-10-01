# samurai build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub release asset)
- Version pinned: **1.3** (tag `1.3`, released 05 Apr 2026, the current
  `releases/latest`)
- Upstream: **`https://github.com/michaelforney/samurai`**
- Build system: **a hand-written `.POSIX` makefile.** No `configure`, no
  `aclocal.m4`, no `Makefile.in`, no `CMakeLists.txt`, no `meson.build`.
  `Makefile:1` is `.POSIX:` and `Makefile:2` is
  `.PHONY: all install clean` — the three targets, all written by hand.
- **Config template: none.** The autotools timestamp guard does not apply
  and is correctly absent from `generic.lua`. There is no `configure` to
  guard, and no `AC_CONFIG_HEADERS` anywhere.
- Installs: **`bin/samu`** and **`share/man/man1/samu.1`**
  (`Makefile:49-53`). No library, no headers, no `.pc`.

## Two corrections to the brief, both verified from the tarballs

**1. samurai is not C++ and has no cmake options.** The assignment described
it as "a C++ rewrite of ninja whose cmake options matter". There is no
cmake build in this release at all. `README.md:6` reads "samurai is a
ninja-compatible build tool written in C99", and the tree is 13 `.c` and
13 `.h` files with no `.cc`/`.cpp` anywhere. I also downloaded 0.7 and 1.2 to
check whether the C++ implementation existed at some earlier point: both are
*already* this same C99 codebase producing the same `samu` binary. There is
no C++ samurai at any reachable release, so there were no cmake options to
read and nothing was guessed.

**2. `samu` and `samurai` are one project. The backlog lists them twice.**

The program samurai builds is named `samu`: `Makefile:39` `all: samu`,
`Makefile:44` `samu: $(OBJ)`, and `Makefile:49-53` install `samu` and
`samu.1`. The man page in the tarball is `samu.1`, not `samurai.1`.

The standalone `samu` project no longer exists anywhere reachable:

| probe | result |
|---|---|
| `github.com/michaelfaith/samu` | HTTP 404 |
| `github.com/michaelforney/samu` | HTTP 404 |
| `git.sr.ht/~mcf/samu` | HTTP 404 (`~mcf/samurai` → 200) |
| Software Heritage origin `github.com/michaelfaith/samu` | `{"exception":"NotFoundExc"}` — never archived |
| Gentoo `dev-build/samu` | no ebuild at any path (Gentoo *does* carry `dev-build/samurai` 1.2-r3 and 1.3) |
| nixpkgs / Debian / Alpine | no samu package |

Michael Forney's account lists `samurai` and no `samu`. So **`samu` was
absorbed into `samurai`**, this source *is* the samu codebase, and
`packages/samurai` is the single package to keep. A separate
`packages/samu` pinned to the same 1.3 tarball would install a byte-identical
`bin/samu` into the same prefix — a duplicate by any reading. It was
deliberately not created.

## Native tool, not a target library

samurai reads `build.ninja` and spawns compilers, so it must run where the
compilers are. **The only system that actually consumes this package is
`clang-native`**, via `require("samurai@native")`. `@native` resolves to
`clang-native` and then falls back to this `generic.lua`, so no
`clang-native.lua` is written: it would be a byte-identical copy of this
file, which is the duplicate that got `packages/bison/android.lua` deleted.
`packages/ninja` is the counter-example that shows target build tools are
still legitimate here — it is a target package with per-system verdicts —
so the Android rows below are real build answers, not dismissals.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `build.c:348` calls `posix_spawn` **unconditionally** — `if ((errno = posix_spawn(&j->pid, argv[0], &actions, NULL, argv, environ)))` — and `build.c:7` includes `<spawn.h>`. Bionic gates that declaration at API 28. Verified on this machine against the installed NDK 28.2.13676358: `sysroot/usr/include/spawn.h:60` reads `int posix_spawn(...) __INTRODUCED_IN(28);`. There is no `#ifdef` and no configure switch around the call, so no recipe-level flag avoids it. This is the same wall, and the same conclusion, as `packages/ninja/stage1.md` records for ninja. |
| aarch64-android24 | **WILL NOT BUILD** | Same. Still below 28. |
| aarch64-android35 | **WILL BUILD** | At API 35 the declaration is visible and the symbol is in libc. Nothing else in the tree is gated: `getloadavg` (`build.c:538`) is behind `#ifdef HAVE_GETLOADAVG` (`build.c:535`) and the Makefile never defines it, which is the documented opt-in at `README.md:21-25`, so the `return 0` branch at `build.c:545` compiles. No `mblen`, `getpass`, `O_BINARY`, `process_vm_readv`, `POSIX_MADV_*`, `nl_langinfo` or `mktime_z` appears in any `.c` or `.h`. `-lrt` (`Makefile:9`) is a Bionic stub and links. |
| x86_64-android35 | **WILL BUILD** | As above; no arch-conditional code in the tree. |
| x86_64-mingw | **WILL NOT BUILD** | Two independent reasons, either sufficient. (1) `build.c:348` needs `posix_spawn` and `build.c:7` needs `<spawn.h>`; mingw-w64 has neither. (2) `Makefile:9` hardcodes `LDLIBS=-lrt` for `clock_gettime(CLOCK_MONOTONIC)` (`build.c:240,247,589`) and mingw-w64 ships no `librt`. The README calls the project POSIX.1-2008 (`README.md:20`) and `os-posix.c` is the only OS layer in 1.3, with no Windows counterpart in the tarball. |
| clang-native | **WILL BUILD** | **The row that matters** — this is the build the package exists for. Native glibc has `posix_spawn` unconditionally, and `-lrt` is a no-op stub there since glibc 2.17 put `clock_gettime` in libc. |

## API level notes

**The divider here is exactly API 28, and it is clean.** 21 and 24 fail to
compile, 35 compiles. This is the `posix_spawn` family, same as `ninja`, and
different from the `nl_langinfo` (26) and `mktime_z` (35) families: a
compile-time availability property with no partial success.

The `LDLIBS=-lrt` hardcode is the one thing a recipe cannot fix, because
`Makefile:9` assigns it unconditionally and the target line (`Makefile:45`)
appends `$(LDLIBS)` — a recipe would have to rewrite the Makefile, which
AGENTS.md forbids. It is harmless on both Linux targets and fatal only on
mingw.

## Risks / what a reviewer should check

1. **`PREFIX="$OUT"`, not `DESTDIR`.** `Makefile:5-7` derive
   `BINDIR=$(PREFIX)/bin` and `MANDIR=$(PREFIX)/share/man` from `PREFIX`, and
   `Makefile:50-53` mkdir them under `$(DESTDIR)`. Passing `PREFIX=$OUT`
   alone is correct and matches how `packages/meson` avoids the
   `$OUT$OUT` trap AGENTS.md warns about for `DESTDIR`.
2. **The toolchain really does come from the environment here.** I checked
   this rather than assuming, because `libcap`'s `Make.Rules` hard-assigns
   and would have needed the toolchain on the make line instead:
   `Makefile:42` is `$(CC) $(ALL_CFLAGS) -c -o $@ $<` and `Makefile:45` is
   `$(CC) $(LDFLAGS) -o $@ $(OBJ) $(LDLIBS)`. No assignment to `CC` exists
   in the Makefile, so plain `make` picks up the system's `$CC`/`$CFLAGS`/
   `$LDFLAGS`.
3. **`-std=c99` is forced, and it is safe.** `Makefile:8` computes
   `ALL_CFLAGS=$(CFLAGS) -std=c99 ...`, putting `-std=c99` last so it wins
   over anything the system asked for — strict ISO mode, where glibc would
   otherwise hide the POSIX declarations. `build.c:1` and `os-posix.c:1`
   both `#define _POSIX_C_SOURCE 200809L` ahead of every include, which is
   exactly what keeps `<spawn.h>`/`posix_spawn` declared. Worth a look
   because it is the kind of thing that breaks silently on a libc change.
4. **The installed name is `samu`, so expect it.** A verification step
   looking for `bin/samurai` will report a false failure. Check `bin/samu`.
5. **No cmake options were invented**, because the build is not cmake. If a
   reviewer expected `-D*` switches, that expectation is what
   `packages/make`'s recipe is for, not this one.
6. **No autotools guard is present, correctly.** There is no `configure` and
   no config template, so `touch aclocal.m4 configure config.h.in` would be
   the inert-guard mistake AGENTS.md:305-309 describes — and worse, the
   `configure` touch would create a stray empty file in `$WORK`.

## How to verify once built

- **`bin/samu`** — the program is named `samu`; a missing `bin/samurai` is
  not a defect
- `share/man/man1/samu.1`
- no `lib/`, no headers, no `.pc` — samurai links `libfsm`-style nothing;
  it is one executable
- `file bin/samu` → host x86_64 ELF on `clang-native`
- `bin/samu --version` is safe to run **on `clang-native` only**
- a `strace`-free check that it is the samurai build and not a stray ninja:
  `bin/samu --help` lists the `graph` subtool added in 1.3
