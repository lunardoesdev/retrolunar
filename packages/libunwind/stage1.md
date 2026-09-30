# libunwind — stage 1 build forecast

- **Package**: libunwind
- **Version**: 1.8.3 (tag `v1.8.3`, the current `releases/latest`)
- **Upstream URL**: https://github.com/libunwind/libunwind/releases/download/v1.8.3/libunwind-1.8.3.tar.gz
- **Build system**: autotools, `SUBDIRS = src` plus `tests` and `doc`
  conditionally (Makefile.am:82-90). Release asset ships `configure`,
  `Makefile.in` (top, `doc/`, `include/`, `src/`, `tests/`) and
  `include/config.h.in`. Top directory is `libunwind-1.8.3/`.

**These are predictions from reading the source and the recipe, not
measurements. Nothing here has been configured, compiled or run.**

## libelf and LLVM: they are not probed at all in 1.8.3

The brief said libunwind "probes for libelf and LLVM; absent in this prefix
it should fall back to its internal unwinder". I checked, and that is not
what 1.8.3 does — there is no such probe. A case-insensitive grep for
`libelf` and `llvm` across the entire extracted tree returns hits only in
`config/config.guess`, `config/config.sub` and `config/ltmain.sh`, i.e. the
stock auxiliary scripts recognising a `*-linux-llvm*` triplet. There is no
`AC_CHECK_LIB([elf])`, no `--with-libelf`, no LLVM option in `configure.ac`.

What is actually there:

- `--enable-minidebuginfo` / `--enable-zlibdebuginfo`, both defaulting to
  `auto`, which do `AC_CHECK_LIB([lzma], ...)` and `AC_CHECK_LIB([z], ...)`
  (configure.ac:459-486). These are *optional compressed symbol tables* for
  minidebuginfo files, not the unwinder. With `auto`, a failed check simply
  leaves `enable_minidebuginfo` at `auto`, which is not `yes`, so
  `AM_CONDITIONAL(HAVE_LZMA/HAVE_ZLIB)` is false and `LIBLZMA`/`LIBZ` stay
  empty. It does not fail the build.
  - On Android: `lzma.h` is **not** in the NDK r28b sysroot, so the lzma
    check fails and minidebuginfo is off. `zlib.h` **is** in the sysroot, so
    the zlib check may well succeed and turn on compressed zlib symbol
    tables. Harmless either way, and it is a property of the sysroot, not a
    flag I hardcoded.
  - On mingw: neither, both off.
- The unwinder itself is libunwind's own DWARF `.eh_frame`/`.debug_frame`
  parser (`dwarf/`, `USE_DWARF=yes` for every arch except ia64). There is no
  alternative to fall back *from*.

So: the internal unwinder is not a fallback, it is the only thing in the
box. The recipe comment says exactly that rather than repeating the
mistaken premise.

## Tests and documentation: both explicitly off

- `--disable-tests` → `CONFIG_TESTS` false, `tests/` drops out of `SUBDIRS`
  and `AC_CONFIG_FILES([tests/Makefile ...])` inside the `AM_COND_IF` block
  never runs, so no `tests/Makefile` is generated. The suite is not merely
  unrun, it is not configured. That matters because `tests/Makefile.am`
  needs `execinfo` and dlopen and, on Android, `-lpthread` (which does not
  exist there — see the libnl-3 note) and it would have to *run* target
  binaries to be useful, which this repo never does.
- `--disable-documentation` → `CONFIG_DOCS` false, `doc/` drops out of
  `SUBDIRS` and `doc/Makefile doc/common.tex` are not generated. Upstream
  would already disable docs by itself (`AC_PATH_PROG([LATEX2MAN])` fails
  and it prints "latex2man not found. Disabling docs."), but only after
  emitting that warning; passing the flag keeps the log clean and makes the
  intent explicit rather than incidental.

## What it installs

For an ELF host (`libunwind.la` + `libunwind-<arch>.la`, from
`src/Makefile.am`), plus:

- `include/libunwind.h`, `include/unwind.h` (the latter because
  `BUILD_UNWIND_HEADER` defaults yes), `include/libunwind-dynamic.h`, and
  `include/libunwind-<arch>.h`.
- `include/libunwind-common.h` (generated, `nodist_include_HEADERS`).
- `lib/pkgconfig/libunwind.pc`, `libunwind-generic.pc`, and — depending on
  the autodetected conditionals — `libunwind-coredump.pc`,
  `libunwind-ptrace.pc`, `libunwind-setjmp.pc`.
- `lib/libunwind-generic.a` as a symlink to `libunwind-<arch>.a`, created by
  an `install-exec-hook` in `src/Makefile.am` that explicitly handles the
  static case (`if test -f .../libunwind-$(arch).a`). Worth knowing because
  the hook `cd`s into `$DESTDIR$(libdir)`, and `$DESTDIR` is unset in this
  repo (autotools writes straight to `$OUT`), so it lands in `$OUT/lib`.
  That is correct here.
- No man pages (docs disabled). No tools — libunwind installs no programs.

Which extra libraries get built, and why:

- **coredump**: `AM_CONDITIONAL(BUILD_COREDUMP)` defaults to *yes* on
  aarch64/arm/mips/sh/x86/riscv/loongarch64. So it builds on every target
  in this repo except mingw. `libunwind-coredump.la` reads a core file
  through `lseek`/`read`/`mmap` (`coredump/_UCD_access_mem.c:75-85`) — it
  does *not* use `process_vm_readv` or ptrace, so it has no API-level floor.
- **ptrace**: autodetected from the presence of `sys/ptrace.h`, which
  **exists** in the NDK sysroot, so `BUILD_PTRACE` is true. It calls
  `ptrace(PTRACE_PEEKDATA/POKEDATA/...)`; I confirmed `PTRACE_POKEUSER`,
  `PTRACE_POKEDATA`, `PTRACE_PEEKDATA`, `PTRACE_SETREGSET` and `PTRACE_CONT`
  are all defined, in the NDK's `sys/ptrace.h` **including the
  `linux/ptrace.h` it pulls in** (`sys/ptrace.h:39` is
  `#define PTRACE_POKEUSER PTRACE_POKEUSR`; `PTRACE_POKEUSR` itself is
  `linux/ptrace.h:16`). `PTRACE_GETREGSET` — which
  `ptrace/_UPT_access_reg.c:66` uses — is in `linux/ptrace.h`, not
  `sys/ptrace.h`; `PTRACE_CONT` (`ptrace/_UPT_resume.c:38`) and
  `PTRACE_POKEUSER` (`ptrace/_UPT_access_fpreg.c:29`, the one that file
  actually tests) come from `sys/ptrace.h`. `NT_PRSTATUS`, which
  `_UPT_access_reg.c` needs, reaches the sources through `elf.h` ->
  `bits/elf_common.h`. And `ptrace` is exported by `libc.so` at API 21
  (`T ptrace@@LIBC`). So it compiles and links. Whether it is *useful* on
  Android is a different question and not one this recipe can answer.

  An earlier version of this file listed `PTRACE_POKEUSR` among the symbols
  "defined in the NDK's `sys/ptrace.h`". `PTRACE_POKEUSR` is the
  `linux/ptrace.h` name; the `sys/ptrace.h` spelling is `PTRACE_POKEUSER`,
  and that is the one libunwind tests.
- **setjmp**: autodetected as `yes` when `target_arch == host_arch`. In a
  cross build `--host` is set and `--target` is not, so autoconf's
  `AC_CANONICAL_TARGET` makes target default to host and this stays enabled.
  `libunwind-setjmp.la` is just `longjmp`/`siglongjmp` wrappers.

## Dependencies

None in this prefix. `require("libunwind@source")` only.

configure.ac does three `AC_SEARCH_LIBS`/`AC_CHECK_LIB` probes, all
`auto`-by-default and none fatal:

- `AC_SEARCH_LIBS([__uc_get_grs], [uca])` — hppa only, "none required"
  elsewhere.
- `AC_SEARCH_LIBS([dlopen], [dl])` and
  `AC_SEARCH_LIBS([pthread_create], [pthread])` — both inside
  `AM_COND_IF([CONFIG_TESTS])`, which we disable, so they never run.
  (Worth noting: the pthread one would have *found* pthread in Bionic's libc
  anyway, since `pthread_create@@LIBC` is exported, and `AC_SEARCH_LIBS`
  reports "none required" in that case rather than demanding `-lpthread`.)
- `AC_SEARCH_LIBS([_Unwind_Resume], [gcc_s gcc])` — only under
  `SUPPORT_CXX_EXCEPTIONS`, which is `no` on aarch64/arm/mips/x86/s390x/
  loongarch64 (configure.ac:296-304), i.e. every Android target in this
  repo.

`AC_CHECK_FUNCS(dl_iterate_phdr dl_phdr_removals_counter dlmodinfo getunwind
ttrace mincore pipe2 sigaltstack execvpe)` are link-only tests under
autoconf 2.71+, never run, so cross-safe. `dl_iterate_phdr` — which the
library genuinely calls, e.g. `x86/Ginit.c:187` — lives in Android's
`libdl.so` *and* in the static `libc.a` (I checked both with `llvm-nm`:
one `T dl_iterate_phdr` in `libdl.so`, two matches in `libc.a`). Since the
recipe builds a static archive, the static libc copy is what matters and it
is there.

## Per-system verdicts

armv7a and i686 Android targets match the aarch64 rows unless stated. The
API level is the real variable: libunwind's own code needs only `lseek`,
`read`, `mmap`, `syscall` and — for the ptrace library — `ptrace`, and all
of those are in Bionic's libc at API 21. Nothing here needs `process_vm_readv`,
`mblen`, `getpass`, `O_BINARY`, `posix_spawn`, `nl_langinfo`,
`program_invocation_short_name`, `get_current_dir_name`, `fread_unlocked` or
`scandir`/`versionsort`.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD (high confidence)** | Every header and constant the library needs is in the NDK sysroot, and I resolved the two things that could have failed. **`OS_LINUX` does fire**: `$target_os` is `linux-android`, which matches `expr x$target_os : xlinux` at `configure.ac:362`, so the `src/Makefile.am:351-367` block fires and supplies `os-linux.c`, `dl-iterate-phdr.c`, `aarch64/Gos-linux.c` and `aarch64/Los-linux.c` — the library does get its OS layer. And **`libunwind-ptrace` compiles**, because `sys/ptrace.h` and the `linux/ptrace.h` it includes define every `PTRACE_*` the sources use and `NT_PRSTATUS` reaches `_UPT_access_reg.c` through `elf.h`. **The residual risk is the `src/aarch64/getcontext.S` (and `longjmp.S`/`siglongjmp.S`) assembly, which I cannot settle without assembling it** — if an Android build fails, expect a compile/assemble error naming a `.S` file, not a link error. |
| `aarch64-android24` | **WILL BUILD (high confidence)** | Every header and constant the library needs is in the NDK sysroot, and I resolved the two things that could have failed. **`OS_LINUX` does fire**: `$target_os` is `linux-android`, which matches `expr x$target_os : xlinux` at `configure.ac:362`, so the `src/Makefile.am:351-367` block fires and supplies `os-linux.c`, `dl-iterate-phdr.c`, `aarch64/Gos-linux.c` and `aarch64/Los-linux.c` — the library does get its OS layer. And **`libunwind-ptrace` compiles**, because `sys/ptrace.h` and the `linux/ptrace.h` it includes define every `PTRACE_*` the sources use and `NT_PRSTATUS` reaches `_UPT_access_reg.c` through `elf.h`. **The residual risk is the `src/aarch64/getcontext.S` (and `longjmp.S`/`siglongjmp.S`) assembly, which I cannot settle without assembling it** — if an Android build fails, expect a compile/assemble error naming a `.S` file, not a link error. |
| `aarch64-android35` | **WILL BUILD (high confidence)** | Every header and constant the library needs is in the NDK sysroot, and I resolved the two things that could have failed. **`OS_LINUX` does fire**: `$target_os` is `linux-android`, which matches `expr x$target_os : xlinux` at `configure.ac:362`, so the `src/Makefile.am:351-367` block fires and supplies `os-linux.c`, `dl-iterate-phdr.c`, `aarch64/Gos-linux.c` and `aarch64/Los-linux.c` — the library does get its OS layer. And **`libunwind-ptrace` compiles**, because `sys/ptrace.h` and the `linux/ptrace.h` it includes define every `PTRACE_*` the sources use and `NT_PRSTATUS` reaches `_UPT_access_reg.c` through `elf.h`. **The residual risk is the `src/aarch64/getcontext.S` (and `longjmp.S`/`siglongjmp.S`) assembly, which I cannot settle without assembling it** — if an Android build fails, expect a compile/assemble error naming a `.S` file, not a link error. |
| `x86_64-android35` | **WILL BUILD (high confidence)** | Same headers and same libraries as aarch64. `OS_LINUX` is satisfied: `configure.ac:362` tests `expr x$target_os : xlinux` and `$target_os` is `linux-android` (I confirmed `config/config.sub aarch64-linux-android` → `aarch64-unknown-linux-android`, and the triplet split at `configure:3573-3582` puts `linux-android` in `$target_os`), so the `src/Makefile.am:351-367` block fires and supplies `os-linux.c`, `dl-iterate-phdr.c`, `x86_64/Gos-linux.c` and `x86_64/Los-linux.c`. **No `.S` file is involved on x86_64** — `x86_64/getcontext-linux.S` belongs to `x86` (`src/Makefile.am:361`), not `x86_64`, so the assembly caveat that qualifies the aarch64 rows does not apply here at all. `dl_iterate_phdr` resolves out of Bionic's static `libc.a` (confirmed with `llvm-nm`). An earlier version of this row listed `x86_64/getcontext.S` and `setcontext.S` and hedged at moderate confidence; both were wrong. |
| `x86_64-mingw` | **WILL NOT BUILD** | libunwind is ELF-only and says so. Three concrete blockers. (1) `AM_CONDITIONAL(OS_LINUX, expr x$target_os : xlinux >/dev/null)` (configure.ac:362) is false for `mingw32`, and `src/Makefile.am:351-367` fills `libunwind_la_SOURCES_os` only under `OS_LINUX`/`OS_HPUX`/`OS_FREEBSD`/`OS_SOLARIS`/`OS_QNX` — so for `mingw32` none of them fire and `libunwind_la_SOURCES_os` is empty: the library has no OS layer (`os-linux.c`/`os-freebsd.c`/`Gos-*.c` are all inside that block). (2) `configure.ac:369-377`'s `AS_CASE` *does* recognise `x86_64` and sets `use_elf64=yes`, so it does **not** `AC_MSG_ERROR` here — but the ELF helper it then configures (`libunwind-elf64.la`) reads ELF core notes, and there is no PE/COFF reader anywhere in the tree. (3) `LDFLAGS_NOSTARTFILES="-XCClinker -nostartfiles"` (configure.ac:511) is in `COMMON_SO_LDFLAGS` (`src/Makefile.am:31`) and so in `libunwind_la_LDFLAGS` (`src/Makefile.am:1247`); mingw-w64 gcc has no `-nostartfiles` and its `ld` is PE-targeted. This is a real platform gap, not a flag I could fix. |
| `clang-native` | **WILL BUILD** | Native glibc x86_64, the configuration upstream CI runs most. `dl_iterate_phdr` is in glibc. `--build` is the only triplet in `$AUTOCONF_CONFIGURE_FLAGS` here, so `build == host` and `REMOTE_ONLY` is false, which is the normal local-unwinding path. |

## For a reviewer to scrutinise

1. **The premise in the brief was wrong and I wrote it down as wrong.**
   There is no libelf probe and no LLVM probe in 1.8.3. If the reviewer
   expected a `--without-libelf`-style switch in the recipe, it is absent
   because it has nothing to switch. That is the single most useful thing
   in this document.
2. **The `.S` files are the real uncertainty on Android.** Every other
   question here I could settle by reading a header or a symbol table; I
   could not settle the assembly without compiling, and I am not permitted
   to. If the aarch64 or x86_64 Android rows fail, the `.S` files in
   `src/<arch>/` are where I would look first.
3. **`-Wl,-z -Wl,relro`-style flags.** libunwind sets
   `LDFLAGS_NOSTARTFILES` and uses it in `COMMON_SO_LDFLAGS`, which is in
   `libunwind_la_LDFLAGS`. With `--disable-shared` libtool applies LDFLAGS
   only when actually linking a shared object, so for a static build this
   is inert. I have not confirmed that empirically.
4. **`--disable-tests` also removes the two `AC_SEARCH_LIBS` that would have
   touched `-lpthread`.** On Android `AC_CHECK_LIB`-style pthread detection
   is the classic Bionic trap; disabling the tests sidesteps it entirely
   rather than papering over it. Worth knowing that this is *why* the tests
   are off, and not only that they cannot be run.
5. **Timestamp guard.** `include/config.h.in` is not at the top level, so
   the recipe names it. The tarball ships no `config.status` and no
   `libtool` (checked), so neither goes in the touch list. Note that
   libunwind's aux directory is `config/`, not `build-aux/`; nothing in the
   recipe depends on that, but `find . -name 'Makefile.in'` covers both.
