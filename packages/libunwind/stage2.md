REJECT

# libunwind — stage 2 review

Reviewed against `AGENTS.md`, `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`, and
the real 1.8.3 tarball (downloaded, listed, files read — nothing built).

## What the recipe gets right

- **The adder's headline claim is TRUE and it is the most valuable thing in
  this package: 1.8.3 has no libelf probe and no LLVM probe.** I grepped
  `configure.ac` case-insensitively for `libelf` and `llvm`: **zero hits**. A
  grep across the whole tree returns hits only in `config/config.guess`,
  `config/config.sub`, `config/ltmain.sh` and `m4/libtool.m4` — the stock
  auxiliary scripts recognising a `*-linux-llvm*` triplet. There is no
  `AC_CHECK_LIB([elf])`, no `--with-libelf`, no LLVM option. The brief the
  adder was given was wrong and the adder said so in the recipe comment
  (`generic.lua:6-9`) rather than inventing a `--without-libelf`. Correct.
- **The only optional probes are the ones the adder named.**
  `configure.ac:442-486`: `--enable-minidebuginfo` → `AC_CHECK_LIB([lzma],
  [lzma_mf_is_supported])`, and `--enable-zlibdebuginfo` → `AC_CHECK_LIB([z],
  [uncompress])`. Both default `auto`, both are non-fatal
  (`AC_MSG_FAILURE` only fires when explicitly set to `yes`). Correct.
- **`--disable-tests` and `--disable-documentation` are both real options in
  1.8.3.** `configure.ac:242` (`AC_ARG_ENABLE([tests], AS_HELP_STRING([--disable-tests], …))`)
  and `configure.ac:315` (`AC_ARG_ENABLE([documentation], …)`). And the
  suppression is real, not cosmetic: `AM_COND_IF([CONFIG_DOCS],
  [AC_CONFIG_FILES([doc/Makefile doc/common.tex])])` at `:327` means `doc/Makefile`
  is never generated, and `Makefile.am:63-70` gates `SUBDIRS += tests` / `+= doc`
  on the same conditionals. Verified. Note the help text for `--disable-tests`
  says `@<:@default=no@:>@` but the action-if-not-given is `[enable_tests=yes]`
  — i.e. upstream's help string lies and tests default to **on**. Passing
  `--disable-tests` is therefore necessary, not cosmetic.
- **Config template name is the real one**: `include/config.h.in` exists,
  `generic.lua:13` names it. Guard position correct; `find . -name 'Makefile.in'`
  covers the 4 shipped files (top, `doc/`, `src/`, `tests/`). No `config.status`
  / `libtool` shipped (verified), so omitting them is right.
- **`make all` builds no programs at all.** `src/Makefile.am` contains no
  `_PROGRAMS` variable whatsoever (grepped), and `tests/` drops out of `SUBDIRS`.
  There is nothing to exclude.
- **`--with-pic` is a real libtool option** here (`configure:11002` handles
  `pic_mode`), not an unrecognised option that would only warn.
- **Source recipe correct.** 1.8.3 is current (`releases/latest`). URL 200.
  Top dir `libunwind-1.8.3/`, stripped. `dl/` guard + `curl -C -`. Lands in
  `$OUT/libunwind/`.
- **Android "moderate confidence" has a stated reason** (the `.S` files), so
  it is not the bare "moderate confidence with no reason" that would itself be
  a finding.

## Required changes

1. **`packages/libunwind/stage1.md:148` — the mingw row's reason (2) is
   factually wrong and must be corrected, because it is the kind of wrong the
   builder will act on.** It claims: "The `AC_CASE` at configure.ac:335
   computes the ELF helper width and `AC_MSG_ERROR([Unknown ELF target: …])`
   for anything unrecognised; `x86_64` is recognised, so it would pick
   `elf64`, but there is no PE/COFF reader in the tree." The first half is
   self-contradictory as written. The truth: `configure.ac:369-377`'s
   `AS_CASE` lists `x86_64` explicitly and sets `use_elf64=yes`, so
   **no error fires on mingw**. The real blockers are reason (1) —
   `AM_CONDITIONAL(OS_LINUX, expr x$target_os : xlinux)` (`configure.ac:362`) is
   false for `x86_64-pc-windows-gnu`/`mingw32`, so `src/Makefile.am:351-367`'s
   `if OS_LINUX` block never runs and `libunwind_la_SOURCES_os` is empty, i.e.
   **no OS layer at all** — and reason (3), `LDFLAGS_NOSTARTFILES="-XCClinker
   -nostartfiles"` (`configure.ac:511`) reaching the PE linker through
   `COMMON_SO_LDFLAGS`.
   Replace that cell with:
   "| `x86_64-mingw` | **WILL NOT BUILD** | libunwind is ELF-only and says so.
   Three concrete blockers. (1) `AM_CONDITIONAL(OS_LINUX, expr x$target_os :
   xlinux >/dev/null)` (configure.ac:362) is false for `mingw32`, and
   `src/Makefile.am:351-367` fills `libunwind_la_SOURCES_os` only under
   `OS_LINUX`/`OS_HPUX`/`OS_FREEBSD`/`OS_SOLARIS`/`OS_QNX` — so for `mingw32`
   none of them fire and `libunwind_la_SOURCES_os` is empty: the library has
   no OS layer (`os-linux.c`/`os-freebsd.c`/`Gos-*.c` are all inside that
   block). (2) `configure.ac:369-377`'s `AS_CASE` *does* recognise `x86_64` and
   sets `use_elf64=yes`, so it does **not** `AC_MSG_ERROR` here — but the ELF
   helper it then configures (`libunwind-elf64.la`) reads ELF core notes, and
   there is no PE/COFF reader anywhere in the tree. (3)
   `LDFLAGS_NOSTARTFILES="-XCClinker -nostartfiles"` (configure.ac:511) is in
   `COMMON_SO_LDFLAGS` (`src/Makefile.am:31`) and so in `libunwind_la_LDFLAGS`
   (`src/Makefile.am:1247`); mingw-w64 gcc has no `-nostartfiles` and its
   `ld` is PE-targeted. This is a real platform gap, not a flag I could fix. |"
   **The `WILL NOT BUILD` verdict itself is unchanged and correct.**

2. **`packages/libunwind/stage1.md:148` — the `x86_64-android35` row asserts
   `x86_64/getcontext.S` is "ordinary" and lists only `Gos-linux.c`,
   `Los-linux.c`, `getcontext.S`, `setcontext.S`.** That list is wrong.
   `src/Makefile.am:351-367` puts `x86_64_64_os = x86_64/Gos-linux.c` and
   `x86_64_64_os_local = x86_64/Los-linux.c` — **no `.S` file at all**; the
   `x86_64/getcontext-linux.S` assembly is attached to `x86`, not `x86_64`
   (`src/Makefile.am:361`). So on x86_64 Android the `.S` concern that drives
   the "moderate confidence" does not even apply. Replace that cell with:
   "| `x86_64-android35` | **WILL BUILD (high confidence)** | Same headers and
   same libraries as aarch64. `OS_LINUX` is satisfied: `configure.ac:362`
   tests `expr x$target_os : xlinux` and `$target_os` is `linux-android` (I
   confirmed `config/config.sub aarch64-linux-android` →
   `aarch64-unknown-linux-android`, and the triplet split at `configure:3573-3582`
   puts `linux-android` in `$target_os`), so the `src/Makefile.am:351-367`
   block fires and supplies `os-linux.c`, `dl-iterate-phdr.c`,
   `x86_64/Gos-linux.c` and `x86_64/Los-linux.c`. **No `.S` file is involved
   on x86_64** — `x86_64/getcontext-linux.S` belongs to `x86`
   (`src/Makefile.am:361`), not `x86_64`. `dl_iterate_phdr` resolves out of
   Bionic's static `libc.a` (I confirmed with `llvm-nm`). |"

3. **`packages/libunwind/stage1.md:145-147` — the three aarch64 rows keep
   "moderate confidence", and with the reasoning now checked the honest
   answer is "high".** The stated reason is `.S` assembly, which is plausible,
   but the two things that could actually fail were both resolvable by
   reading, and I resolved them:
   - **`OS_LINUX` does fire on Android.** This was the real risk — if it had
     not, `libunwind_la_SOURCES_os` would be empty and the library would have
     no OS layer, exactly the mingw failure. `target_os` is `linux-android`
     and `expr xlinux-android : xlinux` matches. `os-linux.c` and
     `dl-iterate-phdr.c` are in.
   - **`libunwind-ptrace` compiles on Android.** `configure.ac:141-146`
     enables it when `ac_cv_header_sys_ptrace_h` is yes, which it is (the NDK
     ships `sys/ptrace.h`, and it `#include`s `linux/ptrace.h` where
     `PTRACE_PEEKDATA`, `PTRACE_POKEDATA`, `PTRACE_SETREGSET`, `PTRACE_TRACEME`,
     `PTRACE_CONT`, `PTRACE_SINGLESTEP` and `PTRACE_SYSCALL` are all `#define`d,
     and `sys/ptrace.h` adds `PTRACE_POKEUSER`). `_UPT_access_mem.c:29` takes
     the `HAVE_DECL_PTRACE_POKEDATA` branch, `_UPT_access_reg.c:37` takes the
     `HAVE_DECL_PTRACE_SETREGSET` branch, and `NT_PRSTATUS` reaches it via
     `elf.h` → `bits/elf_common.h` (I compiled `#include <elf.h>` /
     `int a = NT_PRSTATUS;` with the NDK clang — it resolves). `ptrace` is
     `T ptrace@@LIBC` in `usr/lib/aarch64-linux-android/21/libc.so`.
   Replace the confidence marker and the reason in each of the three cells with
   "**WILL BUILD (high confidence)**" plus: "Every header and constant the
   library needs is in the NDK sysroot, and I resolved the two things that
   could have failed: `OS_LINUX` does fire (`$target_os` is `linux-android`,
   which matches `expr xlinux-android : xlinux` at configure.ac:362, so
   `os-linux.c`/`dl-iterate-phdr.c`/`aarch64/Gos-linux.c` are in the build),
   and `libunwind-ptrace` compiles because `sys/ptrace.h` and `linux/ptrace.h`
   define every `PTRACE_*` the sources use and `NT_PRSTATUS` reaches
   `_UPT_access_reg.c` through `elf.h`. The residual risk is the
   `src/aarch64/getcontext.S` assembly, which I cannot settle without
   assembling it."
   **Keep the residual `.S` caveat — it is real — but do not let an
   already-resolved question keep the row at "moderate".**

4. **`packages/libunwind/stage1.md:91-96` asserts `libunwind-ptrace` "calls
   `ptrace(PTRACE_PEEKDATA/POKEDATA/GETREGSET/...)`; I confirmed
   `PTRACE_PEEKDATA`, `PTRACE_POKEUSR`, `PTRACE_CONT`, `PTRACE_SINGLESTEP`,
   `PTRACE_SYSCALL`, `PTRACE_TRACEME` and `PTRACE_GETREGSET` are all defined".**
   The list mixes two headers and names one macro that does not exist in
   either. In the NDK, `PTRACE_POKEUSER` (not `PTRACE_POKEUSR`) is what
   `sys/ptrace.h` defines, and it is the one `_UPT_access_fpreg.c:29`
   actually tests. Fix the list at stage1.md:92-95 to name
   `PTRACE_POKEUSER`, `PTRACE_POKEDATA`, `PTRACE_PEEKDATA`, `PTRACE_SETREGSET`
   and say they come from `sys/ptrace.h` **including `linux/ptrace.h`**;
   `PTRACE_GETREGSET` is what `_UPT_access_reg.c:66` uses, and
   `PTRACE_CONT` what `_UPT_resume.c:38` uses. Also drop `PTRACE_GETREGSET` from
   the "I confirmed the sysroot's `sys/ptrace.h`" phrasing — it is in
   `linux/ptrace.h`, which `sys/ptrace.h` pulls in.

None of these four change what gets built. They are required because each one
is a claim the builder would act on, and three of the four are wrong.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libunwind-aarch64.a` (name varies: `-arm`, `-x86_64`, …) | `ls $PREFIX/lib/libunwind-*.a` — the suffix is `$arch` |
| `$PREFIX/lib/libunwind.a` | `llvm-nm --defined-only $PREFIX/lib/libunwind.a` shows `T unw_backtrace` (defined at `src/mi/backtrace.c:59`) |
| `$PREFIX/lib/libunwind-generic.a` | `test -L $PREFIX/lib/libunwind-generic.a` — it is a **symlink** created by `install-exec-hook` (`src/Makefile.am:1233-1240`), not a copy |
| `$PREFIX/lib/libunwind-coredump.a`, `libunwind-ptrace.a`, `libunwind-setjmp.a` | `ls $PREFIX/lib/libunwind-coredump.a` — `BUILD_COREDUMP` defaults yes on aarch64/arm/mips/sh/x86/riscv (`configure.ac:126-130`); `BUILD_PTRACE` and `BUILD_SETJMP` also come out yes |
| `$PREFIX/include/libunwind.h`, `unwind.h`, `libunwind-dynamic.h`, `libunwind-aarch64.h`, `libunwind-common.h` | `test -f` each; the first two require `!REMOTE_ONLY` and `BUILD_UNWIND_HEADER` (`Makefile.am:54-59`), both satisfied because target==host |
| `$PREFIX/lib/pkgconfig/libunwind.pc` + `libunwind-generic.pc` (+ coredump/ptrace/setjmp) | `pkg-config --modversion libunwind` → `1.8.3` |
| **no** man pages, **no** `$PREFIX/bin` | docs are off (`--disable-documentation`); `src/Makefile.am` has no `_PROGRAMS` at all |

Note `include/libunwind.h`, `include/libunwind-common.h` and
`include/tdep/libunwind_i.h` are `config.status` outputs
(`configure.ac:570-572`), not shipped files.

## Where the builder is most likely to be wrong

1. **`src/aarch64/getcontext.S` and friends.** This is now the *only*
   unresolved item, and required change 3 says so plainly. If the Android
   builds fail, this is where to look — it is a compile/assemble error naming
   a `.S` file, not a link error.
2. **`libunwind-generic.a` is a symlink.** `install-exec-hook`
   (`src/Makefile.am:1234-1236`) does `cd $(DESTDIR)$(libdir) && $(LN_S) -f
   libunwind-$(arch).a libunwind-generic.a`. `$DESTDIR` is unset in this repo,
   so it is `$OUT/lib` — correct here, but it means the artifact is a dangling
   risk if the copy into `$PREFIX` does not preserve symlinks. Check it with
   `test -L`, not `test -f`, and if the published copy is a broken link, that
   is the cause.
3. **`LDFLAGS_NOSTARTFILES="-XCClinker -nostartfiles"`** (`configure.ac:511`)
   flows into `COMMON_SO_LDFLAGS` → `libunwind_la_LDFLAGS`. With
   `--disable-shared` libtool satisfies each `.la` from `archive_cmds`
   (`ar cru`) and never invokes the linker, so this is inert. If you ever see
   it in a link line, the build was not static.
4. **`LDFLAGS="$LDFLAGS -Wl,--undefined-version"` on `clang-native`.** That is
   the system's, not the recipe's, and it is inert for a static archive for the
   same reason. Do not "fix" it here.
5. **zlibdebuginfo.** `configure.ac:459-475` does `AC_CHECK_LIB([z],
   [uncompress])`. The NDK ships `libz.so` and `zlib.h` (I confirmed
   `#include <zlib.h>` compiles with the NDK clang), so on Android this probe
   will **succeed**, `LIBZ=-lz` and `HAVE_ZLIB=1`, and `libunwind_la_LIBADD`
   picks up `-lz` (`src/Makefile.am:1251-1253`). For a static archive that is
   recorded, not linked — but it means the Android build differs from the
   stage1:33-37 reading, which said the check "may well succeed". It will.
   Nothing to fix in the recipe; worth knowing before you read a `-lz` in
   `libunwind.la` and think the recipe added it.