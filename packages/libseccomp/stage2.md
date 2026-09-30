REJECT

# libseccomp — stage 2 review

Reviewed against `AGENTS.md`, `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`, and
the real 2.6.1 tarball (downloaded, listed, files read — nothing built).

## What the recipe gets right

- **The gperf requirement is real and is met correctly.**
  `configure.ac:126-129` is exactly as stage1 quotes:
  `AC_CHECK_TOOL(GPERF, gperf)` + `AC_MSG_ERROR([please install gperf])`.
  `require("gperf@native")` names a package that exists (`packages/gperf/`),
  uses the correct `@native` spelling, and resolves to `packages/gperf/generic.lua`.
- **Relying on `PATH` for gperf is acceptable here, and I checked the mechanism
  rather than assuming it.** `src/loader.lua:412-415` emits, for **every**
  package block including cross ones, and **after** the system `setup` fragment:
  `NATIVE_PREFIX="$NESTDIR"/clang-native`, `PATH="$NATIVE_PREFIX/bin:$PATH"`,
  `export`. So both `AC_CHECK_TOOL`'s `PATH` search and any `${GPERF}` in
  `make` find the native gperf. Precedent is established: `packages/bison/generic.lua:1`
  already does `require("gperf@native")` for the same reason. **No change needed
  to name the tool** — the recipe comment at `generic.lua:1-3` already explains
  exactly this, which is the bar AGENTS.md sets.
- **Config template name is the real one.** `generic.lua:13` touches
  `configure.h.in`; `configure.ac:28` is `AC_CONFIG_HEADERS([configure.h])`,
  so `config.h.in` would not exist. Verified by listing the archive. This is the
  single most likely thing to get wrong on this package and the adder got it right.
- **Guard position correct**; `find . -name 'Makefile.in' | xargs touch` covers
  all 7 shipped `Makefile.in` files (top, `doc/`, `include/`, `src/`,
  `src/python/`, `tests/`, `tools/` — verified).
- **No `config.status` / `libtool` shipped** (verified by listing), so omitting
  them from the touch list is correct.
- **Source recipe correct.** 2.6.1 is current (`releases/latest`, published
  2026-07-01). URL 200. Top dir `libseccomp-2.6.1/`, stripped. `dl/` guard,
  `curl -C -`. Lands in `$OUT/libseccomp/`.
- **`make -j1`**, no `sed`, no patch, no `/dev/null`, no `export` of search
  flags. Flags come from `$AUTOCONF_CONFIGURE_FLAGS`; `--enable-static
  --disable-shared` is package-local with a comment.

## Required changes

1. **`packages/libseccomp/generic.lua:12` — `make -j1` builds host tools, and
   that is not what the recipe should do.**
   `SUBDIRS = include src tools tests doc` (`Makefile.am:28`), so `make -j1`
   descends into all five. In `tools/Makefile.am:23-29`:
   `bin_PROGRAMS = scmp_sys_resolver` and `noinst_PROGRAMS = scmp_arch_detect
   scmp_bpf_disasm scmp_bpf_sim scmp_api_level`. Those are **target** binaries,
   so they are not an AGENTS.md violation as such — but they are five extra
   links of a library the prefix does not otherwise need, and
   `scmp_sys_resolver` then gets **installed** into `$OUT/bin` by the plain
   `make install` on line 16. `tests/` and `doc/` are genuinely harmless
   (`check_PROGRAMS` only; the 35 `.3` and 1 `.1` man pages ship pre-generated
   in `doc/man/`, verified). Replace lines 12-16 with:

   ```sh
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared
        touch aclocal.m4 configure configure.h.in
        find . -name 'Makefile.in' | xargs touch
        # tools/ has one bin_PROGRAM (scmp_sys_resolver) and four noinst
        # programs; they are target binaries nothing in this prefix runs, so
        # build the library and install only what a consumer needs.
        make -j1 -C src
        make -j1 -C include install-includeHEADERS
        make -j1 -C doc install-man
        make -j1 -C . install-pkgconfDATA
   ```

   The target names are verified in the shipped Makefiles:
   `include/Makefile.in:377 install-includeHEADERS`; `doc/Makefile.in:594
   install-man: install-man1 install-man3`; `Makefile.in:494
   install-pkgconfDATA` at the **top level** (`pkgconfdir = ${libdir}/pkgconfig`,
   `Makefile.am:30-31`). `libseccomp.pc` is produced by `config.status`
   (`configure.ac:147`), so the `.pc` needs no build step.
   `make -j1 -C src` builds only `libseccomp.la`: `src/Makefile.in:1181` is
   `all-am: Makefile $(LTLIBRARIES)`, and `check_PROGRAMS = arch-syscall-dump`
   (`src/Makefile.am:56`) is not in it.
   This keeps the two headers, the `.pc` and all 36 man pages, and drops the
   five programs. Do **not** use `make -j1 -C src install` alone: that drops
   the headers, the `.pc` and the man pages, which is the `elfutils` shape
   stage1 item 2 correctly warns about.

2. **`packages/libseccomp/generic.lua:1-3` — the comment says gperf is needed
   only "to turn src/syscalls.csv into src/syscalls.perf", which understates
   it and will mislead the next reader.** `AC_CHECK_TOOL` at configure time is
   the fatal one; the make-time rule is the second. Replace those three comment
   lines with:

   ```lua
   -- configure hard-requires gperf (configure.ac: "please install gperf"),
   -- and src/Makefile.am also regenerates src/syscalls.perf{,.c} through
   -- ${GPERF}. Both are build-time host executables, so gperf must come from
   -- the native prefix; the loader puts $NATIVE_PREFIX/bin on PATH for every
   -- block, cross blocks included.
   ```

3. **`packages/libseccomp/stage1.md:36` — a wrong sentence that will cost the
   builder time.** It says the shipped `syscalls.perf.c` "has mtime
   `2026-07-02 05:06` while `syscalls.csv` has `01:40`, so ... The rule may or
   may not fire." It *will* fire, deterministically. `cp -r $NESTDIR/source/libseccomp/* .`
   copies in sorted glob order, so `syscalls.perf.template` lands **after**
   `syscalls.perf` and is strictly newer; the recipe touches nothing in `src/`.
   Rewrite stage1.md:37-42 to say the regeneration is expected, that
   `arch-gperf-generate` needs `bash`, `sed`, `nl`, `mktemp` from the build
   machine's `/usr/bin` (all present), and that gperf 3.3 from
   `$NATIVE_PREFIX/bin` is the one that runs. Then delete the "may or may not
   fire" hedging from item 1 at stage1.md:113-119.

4. **`packages/libseccomp/stage1.md:103` — the `aarch64-android21` cell is
   truncated mid-sentence** (it ends `... in syscalls.perf…` with no closing
   backtick and no period). Finish the cell so the row is readable; the claim
   itself I verified independently and it holds: `src/system.c:24` is
   `#include <sys/prctl.h>` and `src/system.c:388,438` call `prctl`, and
   `llvm-nm -D` on `sysroot/usr/lib/aarch64-linux-android/21/libc.so` shows
   `T prctl@@LIBC`, `T syscall@@LIBC`, `T fork@@LIBC`, `T ptrace@@LIBC`.

## Is the mingw `WILL NOT BUILD` verdict justified? — YES, and the reason given is the real one

Not a rationalisation. I checked the actual includes rather than accepting the
forecast:

- `include/seccomp.h.in:26-32` unconditionally includes `<elf.h>`,
  `<asm/unistd.h>`, `<linux/audit.h>`, `<linux/types.h>` and
  `<linux/seccomp.h>`. `src/api.c:23` and `src/api.c:31` include `seccomp.h`.
  None of those Linux UAPI headers exist in a mingw-w64 sysroot.
- `src/system.c:24` includes `<sys/prctl.h>` and `src/system.c:388,438` call
  `prctl(PR_SET_NO_NEW_PRIVS, …)` / `prctl(PR_SET_SECCOMP, …)`. There is no
  `prctl` in msvcrt/winnt.
- Every `src/arch-*.c` includes `<linux/audit.h>` (`arch-aarch64.c:24`,
  `arch-arm.c:24`, `arch-loongarch64.c:23`, and so on).
- `configure.ac:69`'s `AC_CHECK_HEADERS_ONCE([linux/seccomp.h])` is indeed
  non-fatal, so configure will *succeed* on mingw and the build will fail at
  compile time. Worth telling the builder that explicitly: **mingw fails in the
  compiler, not in configure**, so the log will look like a successful configure
  followed by a wall of missing-header errors.

The reasoning is the correct one (missing kernel ABI, not a fixable flag).
**No change required to the verdict.**

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libseccomp.a` | `llvm-nm --defined-only $PREFIX/lib/libseccomp.a` shows `T seccomp_init` |
| `$PREFIX/include/seccomp.h`, `$PREFIX/include/seccomp-syscalls.h` | `test -f` both (`include/Makefile.am:19`) |
| `$PREFIX/lib/pkgconfig/libseccomp.pc` | `pkg-config --modversion libseccomp` → `2.6.1` |
| `$PREFIX/share/man/man3/*.3` (35 pages) + `man1/scmp_sys_resolver.1` | `ls $PREFIX/share/man/man3 \| wc -l` → `35` |
| `$PREFIX/bin/scmp_sys_resolver` **only if you keep line 16 as-is** | `test -x`. Required change 1 removes it; do not treat its absence as a failure after that change. |

## Where the builder is most likely to be wrong

1. **The gperf regeneration firing.** Expect `arch-gperf-generate` and
   `gperf -m 100 --null-strings --pic -tCEG -T -S1` to actually run during
   `make -C src`. That needs `bash`, `sed`, `nl`, `mktemp` from the build
   machine's `/usr/bin` plus native gperf. If the build dies there, the missing
   piece is one of those host tools, not the recipe's flag handling.
2. **`tools/`.** If you build before applying required change 1, five
   cross-compiled programs are built and one installed. `util.la` in
   `tools/Makefile.am:19-21` is `noinst_LTLIBRARIES` with `util_la_LDFLAGS =
   -module`, i.e. a libtool *module* built under `--disable-shared`. That is the
   most likely place for an unexpected libtool complaint on this package.
   `-module` + static-only is libtool's `build_old_libs`/`build_libtool_libs`
   interaction; if it errors, the fix is to keep the tools subdir out of the
   build (required change 1), not to add a flag.
3. **`LT_INIT([shared pic-only])` (`configure.ac:59`) against
   `--disable-shared`.** stage1 item 3 flags this as untested. `pic-only` only
   forces PIC objects unconditionally; it does not force a shared library.
   Low risk, but this is the second thing to look at if `configure` complains.
4. **`AM_LDFLAGS="-Wl,-z -Wl,relro"` (`configure.ac:65`).** ELF-only, and inert
   for a static-only libtool archive (no link step). If it ever surfaces, it is
   on a shared build, which this recipe does not do.
5. **Man pages.** `doc/` ships pre-generated `.1`/`.3`; there is no xsltproc or
   xmlto step. If a man page is missing, the cause is the install target you
   asked for, not a missing doc tool.