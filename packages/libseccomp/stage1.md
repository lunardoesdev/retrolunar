# libseccomp — stage 1 build forecast

- **Package**: libseccomp
- **Version**: 2.6.1 (tag `v2.6.1`, the current `releases/latest`)
- **Upstream URL**: https://github.com/seccomp/libseccomp/releases/download/v2.6.1/libseccomp-2.6.1.tar.gz
- **Build system**: autotools. Non-recursive in the sense that it is one
  `Makefile.am` with `SUBDIRS = include src tools tests doc` and generated
  subdir Makefiles; the release asset ships `configure`, `Makefile.in` in
  seven places (top, `doc/`, `include/`, `src/`, `src/python/`, `tests/`,
  `tools/`) and `configure.h.in` (note: `configure.h.in`, not
  `config.h.in` — `AC_CONFIG_HEADERS([configure.h])`, configure.ac:22).
  Top directory is `libseccomp-2.6.1/`.

**These are predictions from reading the source and the recipe, not
measurements. Nothing here has been configured, compiled or run.**

## gperf: the hard requirement, and why the native prefix is enough

`configure.ac` has, immediately after the cython/python block:

```m4
AC_CHECK_TOOL(GPERF, gperf)
if test -z "$GPERF"; then
	AC_MSG_ERROR([please install gperf])
fi
```

This is `AC_MSG_ERROR`, not a warning: with no gperf on `PATH`, configure
aborts. It is needed at *two* different times:

1. Configure time — `AC_CHECK_TOOL` searches `PATH` for `gperf` (or
   `$host_alias-gperf`, which will not exist; it falls back to the plain
   name). It is a build-time host tool, never a target binary.
2. Build time — `src/Makefile.am:73-77` runs
   `${srcdir}/arch-gperf-generate syscalls.csv syscalls.perf.template` and
   then `${GPERF} -m 100 --null-strings --pic -tCEG -T -S1`. **Expect this
   regeneration to actually run.** The generated `syscalls.perf.c` and
   `syscalls.perf` are in the tarball and in `EXTRA_DIST`, but both are also
   in `CLEANFILES`, and the deciding factor is deterministic rather than
   incidental: `cp -r $NESTDIR/source/libseccomp/* .` copies in sorted glob
   order, so `src/syscalls.perf.template` lands **after** `src/syscalls.perf`
   and is strictly newer, and the recipe touches nothing under `src/`. Make
   therefore sees `syscalls.perf` older than its prerequisite and re-runs the
   rule. An earlier version of this file said "the rule may or may not fire";
   **that hedging was wrong** and it has cost nothing to remove now that the
   ordering is settled.

   So the build needs four host programs from the build machine's `/usr/bin`
   — `bash` (the `arch-gperf-generate` shebang), `sed`, `nl` and `mktemp`, all
   of which it uses — plus **gperf 3.3 from `$NATIVE_PREFIX/bin`**, which is
   the one `${GPERF}` invokes. If the build dies in that step, the missing
   piece is one of those host tools, not the recipe's flag handling.

**Yes, the native prefix is enough for both cases.** The loader's generated
script exports `NATIVE_PREFIX="$NESTDIR/<DEFAULT_SYSTEM>"` and prepends
`$NATIVE_PREFIX/bin` to `PATH` *before* the system `setup` fragment's own
`PATH` handling, for every package block including cross ones. So
`require("gperf@native")` builds gperf into `$NESTDIR/clang-native/bin`,
and both the `AC_CHECK_TOOL` probe and any `${GPERF}` invocation in `make`
find it. This is the same mechanism `packages/bison/generic.lua` already
uses (`require("gperf@native")`, comment "Bison generates build-time tables
with a native gperf executable"), so it is established in this repo, not a
new claim. gperf itself is a C++ program with no target-specific content, so
`clang-native` is the correct identity for it in every case.

If the `syscalls.perf` rule *does* fire, `arch-gperf-generate` is a bash
script (shebang `#!/bin/bash`, uses `[[ ]]`, `mktemp -t`, `sed -e`, `nl`),
and those are host tools from `/usr/bin`, not from the prefix. The build
machine has them; this is the same situation as any bash-using autotools
package here.

## What it installs

- `lib/libseccomp.a` (`lib_LTLIBRARIES = libseccomp.la`, `src/Makefile.am:52`).
  The `pic-only` argument to `LT_INIT` (configure.ac:53) means the objects
  are always `-fPIC`; `--disable-shared` in the recipe still gives a static
  archive.
- `include/seccomp.h`, `include/seccomp-syscalls.h`
  (`include_HEADERS`, `include/Makefile.am`).
- `lib/pkgconfig/libseccomp.pc` (`pkgconf_DATA`, `Makefile.am`, using the
  `pkgconfdir` variable name but installing to `${libdir}/pkgconfig`).
- `man/man1/scmp_sys_resolver.1` and 33 `man/man3/*.3` pages
  (`doc/Makefile.am` `dist_man1_MANS` / `dist_man3_MANS`).
- `bin/scmp_sys_resolver` (`bin_PROGRAMS`, `tools/Makefile.am`). It is a
  *target* binary, cross-built like any other and installed into the
  target prefix. The `noinst_PROGRAMS` beside it (`scmp_arch_detect`,
  `scmp_bpf_disasm`, `scmp_bpf_sim`, `scmp_api_level`) are built by
  `make all` (they are `noinst`, not `check_`) but not installed.
- The regression suite (65 `check_PROGRAMS` in `tests/`) is not built by
  `make all` and is not installed.
- Python bindings: off. They are gated on `--enable-python` plus cython and
  are not requested.

## Dependencies

- `gperf@native` — hard requirement, see above. Resolved to
  `packages/gperf/generic.lua`; the package exists in this repo.
- `libseccomp@source`.
- Nothing else. `configure.ac` checks `linux/seccomp.h` (present in the NDK
  sysroot — I looked) and probes for `cython` and `cov-build` with
  `AC_CHECK_PROG`, both of which default to "not found" and are harmless.
  `AX_CODE_COVERAGE` adds no probe by default.

## Per-system verdicts

armv7a and i686 Android targets match the aarch64 rows unless stated; the
API level is the real variable, and libseccomp is a pure
`prctl`/`seccomp`-syscall library with no API-level branches — it talks to
the kernel, not to libc.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | `src/system.c` and `src/api.c` call `prctl`, `syscall`/`__NR_seccomp` and `fork`. `prctl` and `syscall` are both exported by Bionic's `libc.so` at API 21 — I checked `llvm-nm -D` on `usr/lib/aarch64-linux-android/21/libc.so` and `ptrace`/`syscall`/`newlocale` are all `T ...@@LIBC`. The library itself includes only `<errno.h>`, `<stdio.h>`, `<string.h>`, `<unistd.h>`, `<linux/audit.h>`, `<linux/filter.h>`, `<linux/seccomp.h>` and its own headers; there is no `pthread_`, no `nl_langinfo`, no `argp_parse`, no `dlopen`, no `scandir`. Grep for every known-absent symbol across `src/*.c` and `tools/*.c` came back empty (the `process_vm_readv` and `sigaltstack` hits are gperf-generated *syscall name strings* in `syscalls.perf.c`, not calls). |
| `aarch64-android24` | **WILL BUILD** | Identical reasoning; strictly more API available. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | libseccomp is explicitly multi-arch: `src/arch-aarch64.c`, `arch-x86_64.c`, `arch-x86.c`, `arch-arm.c` all build unconditionally into the same `SOURCES_ALL` (src/Makefile.am:24-42) and the arch-specific tables are selected at *runtime* by `seccomp_arch_native()`. So there is no configure-time arch branch to get wrong. `arch-loongarch64.c` also compiles unconditionally; it is plain C with the same shape as the others. |
| `x86_64-mingw` | **WILL NOT BUILD** | The whole library is a Linux kernel facility. Concretely: `configure.ac:69` is `AC_CHECK_HEADERS_ONCE([linux/seccomp.h])`, which is non-fatal, but the *code* is not. `src/api.c` and `src/system.c` `#include <linux/seccomp.h>` and `<linux/filter.h>` and call `prctl(PR_SET_SECCOMP, ...)`; `src/arch-*.c` all `#include <linux/audit.h>`. None of those headers exist in a mingw-w64 sysroot, and `prctl` does not exist in msvcrt/winnt. The MinGW target has no kernel seccomp ABI to talk to. This is a real gap, not a flag I could fix. |
| `clang-native` | **WILL BUILD** | Native glibc has every header and function; the gperf requirement is satisfied the same way as on the cross targets, since `NATIVE_PREFIX` is this system itself. |

## For a reviewer to scrutinise

1. **The gperf requirement is the thing most likely to surprise.** If
   `require("gperf@native")` were dropped, configure fails immediately with
   "please install gperf" — a clean, loud failure, not a subtle one. On the
   other side, the `syscalls.perf` regeneration **will** fire (see the gperf
   section above for why that is deterministic), so `arch-gperf-generate`
   needs `bash`, `sed`, `nl` and `mktemp` from the build machine's `/usr/bin`
   in addition to gperf from the prefix. Expect that step to run; if it dies,
   the missing piece is a host tool.
2. **`bin/scmp_sys_resolver` gets installed.** It is a target binary that
   nothing in this prefix runs. I left it in because `make install` is the
   ordinary upstream step and there is no configure flag to suppress just
   the tools directory. If the reviewer wants the prefix to carry no
   libseccomp executables, that needs either `make -j1 -C src install`
   plus a manual `.pc` and header copy (the shape `packages/elfutils` uses
   for libelf) or accepting the tool. Flagging rather than deciding.
3. **`--enable-static --disable-shared` against `LT_INIT([shared pic-only])`.**
   `pic-only` tells libtool to build PIC objects unconditionally; it does
   not force shared. I have not run this combination, so it is the second
   most likely thing to surprise.
4. **Timestamp guard.** `configure.h.in` is at the top level but is spelled
   `configure.h.in`, not `config.h.in` — the standard guard line would touch
   a file that does not exist and `touch` would fail, so the recipe names
   it explicitly. No `config.status` or `libtool` is shipped in the tarball
   (checked), so neither is in the touch list.
5. **The `tests/` directory would be a problem if anything ever built it.**
   `tests/Makefile.am` sets `AM_LDFLAGS = ${DBG_STATIC} -lpthread` and
   `DBG_STATIC = -static`; Bionic has no `libpthread` at all, so `make
   check` could not link there. Nothing in this recipe runs `make check`,
   and `check_PROGRAMS` are not in the `all` target, so this is inert — but
   it is why the tests directory must stay unbuilt.
