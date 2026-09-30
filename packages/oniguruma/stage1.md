# oniguruma — stage 1 build forecast

- **Package**: oniguruma
- **Version**: 6.9.10 (tag `v6.9.10`, the current `releases/latest`)
- **Upstream URL**: https://github.com/kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz
- **Build system**: autotools, non-recursive enough to matter — top-level
  `SUBDIRS = src test sample` (Makefile.am:5). The release asset ships a
  generated `configure`, `Makefile.in` (top, `src/`, `test/`, `sample/`),
  `src/config.h.in`, and `aclocal.m4`. Top directory in the tarball is
  `onig-6.9.10/`; the recipe strips it.

**These are predictions from reading the source and the recipe, not
measurements. Nothing here has been configured, compiled or run.**

## What it installs

- `lib/libonig.a` — the single library (`lib_LTLIBRARIES = $(libname)`,
  `src/Makefile.am:24`, `libname = libonig.la`).
- `include/oniguruma.h`, `include/oniggnu.h` (`include_HEADERS`,
  `src/Makefile.am:7`). `onigposix.h` only appears with `--enable-posix-api`,
  which is not passed, so it is absent.
- `lib/pkgconfig/oniguruma.pc` (`pkgconfig_DATA`, Makefile.am:37).
- `bin/onig-config` — a shell script (`bin_SCRIPTS`, Makefile.am:12).
- No man pages: nothing in the tree is in `*_MANS`.
- `mktable` is a maintenance tool (Makefile.am:83) and is not built by
  `make all`. `test/` and `sample/` contain only `check_PROGRAMS`, which
  `make all` also does not build, so no host programs are compiled.

## Dependencies

None. `require("oniguruma@source")` only. Configure is a plain
`AC_PROG_CC` + `LT_INIT` with no library and no program checks beyond
`AC_PROG_INSTALL` / `AC_PROG_MAKE_SET` (configure.ac:52-57). `AC_FUNC_ALLOCA`
is the only link probe and it is a *link-only* test in autoconf 2.71+ — the
generated `configure` at line 14117 uses `ac_fn_c_try_link`, never running the
binary, so it is cross-safe.

## Per-system verdicts

armv7a and i686 Android targets match the aarch64 rows unless stated; the
API level, not the architecture, is the variable that matters here, and
oniguruma does not branch on it.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | No Bionic gaps found. The library uses only C89 plus `<ctype.h>` classification (`isalpha`, `isdigit`, …), `strcmp`/`strncpy_s` (its own), `alloca`, `setlocale` in `mktable.c` only, `vsnprintf`. No `nl_langinfo`, no `program_invocation_short_name`, no `get_current_dir_name`, no `fread_unlocked`, no `scandir`/`versionsort`, no `argp_parse`, no `mblen`/`getpass`, no `posix_spawn`, no `process_vm_readv`, no `O_BINARY` — I grepped every `.c`/`.h` in `src/` for all of them and the only hits were a local variable named `mblen` in `regexec.c:450,2468`. The `<locale.h>` include in `regerror.c` is for `setlocale` only. |
| `aarch64-android24` | **WILL BUILD** | Same source, more API available than 21. Nothing in oniguruma needs anything above 21, so raising the level cannot hurt. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | oniguruma is endian-neutral; `src/utf16_be.c` / `utf16_le.c` handle byte order explicitly. No x86-only code path and no arch ifdefs in `src/Makefile.am` — the same object list builds for every host. |
| `x86_64-mingw` | **WILL BUILD (moderate confidence)** | The configure script has an explicit `mingw*` case (configure.ac:73-84) that adds `libonig.def` and `-no-undefined` *only when building shared*. This recipe passes `--disable-shared`, so `enable_shared` is not `yes`, `LIBONIG_DEF_FILE` stays empty and `USE_LIBONIG_DEF_FILE` is false. What remains is plain libtool plus `AC_FUNC_ALLOCA`, which configure resolves for MinGW at line 14105-14116. No POSIX-only call in `src/` is outside `#ifdef`s I saw. This is the one verdict I am least sure of, because it rests on a negative grep rather than a positive finding. |
| `clang-native` | **WILL BUILD** | Native x86_64 glibc, no `--host` in `$AUTOCONF_CONFIGURE_FLAGS` beyond `--build`, and glibc has a superset of everything oniguruma calls. |

## For a reviewer to scrutinise

1. **`--enable-posix-api` is deliberately off.** It is upstream's default
   and it would add `onigposix.h` and two more objects. If a consumer
   wants `regcomp`/`regexec` from oniguruma, that is the switch. I did not
   enable it because the rule is to take the smallest set of flags.
2. **`AC_FUNC_ALLOCA` cross-safety.** I read the generated `configure`
   (lines 14099-14178) and it is link-only, but this is the single check in
   this package that would fail loudly and early if I were wrong. The
   failure mode would be visible in the first ten lines of configure output.
3. **Static + PIC.** Matches the rest of the prefix; every consumer in this
   repo links statically.
4. **The `test/` and `sample/` subdirectories are built by `make all` only
   as far as their `Makefile`s are generated and installed** — and neither
   installs anything (`install-data-am:` is empty in both `Makefile.in`s,
   lines 1087 and 1236). So `make install` walks into them and does nothing.
   That is harmless but it is three extra `make` invocations; if a reviewer
   prefers a narrower `make -j1 -C src install`, that would also drop
   `onig-config` and `oniguruma.pc`, so it is not a drop-in change.
5. **Timestamp guard.** `config.h.in` lives at `src/config.h.in`, not the
   top level, so the guard touches `src/config.h.in` explicitly. The tarball
   ships no `config.status` and no `libtool`, so those are not in the touch
   list — verified by listing the archive.
