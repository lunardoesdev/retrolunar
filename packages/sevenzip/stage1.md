# 7-Zip build forecast — `sevenzip`

- Recipe: `generic.lua` + `android.lua`, source `source.lua`
- Version pinned: 26.03
- Build system: **hand-written Windows nmake + GNU make**. No `CMakeLists.txt`,
  no `configure`, no `meson.build` anywhere in the tarball (verified by `find`).
  `CPP/Build.mak` is nmake syntax (`!IFNDEF`, `!IF`). The GNU-make entry point is
  `CPP/7zip/Bundles/*/makefile.gcc`, documented at `readme.txt:138-144`.
- Requires: `sevenzip@source` only (`generic.lua:1`, `android.lua:1`)
- Installs: `bin/7zz`, copied by the recipe. There is **no `install` target**
  anywhere in the tree (`grep -rn '^install'` → no match).

## Correction to the previous forecast of this package

An earlier revision of this file claimed the release tarball's root was the
*contents* of upstream's `CPP/` directory flattened, and that every
`../../../../C/...` reference in the makefiles was therefore one level too deep.
**That claim was false, and it was my own error.** `source.lua` had
`--strip-components=1`, and this tarball has no top-level wrapper directory —
its 1292 members sit directly under `Asm/`, `C/`, `CPP/` and `DOC/`. Stripping
one component removed `CPP/`, `C/`, `Asm/` and `DOC/` themselves and pulled the
C++ sources up a level. I then read my own damage as an upstream defect and
graded six WILL NOT BUILD rows on it.

Measured on the real tarball:

```
$ tar tf 7z2603-src.tar.xz | cut -d/ -f1 | sort -u
Asm
C
CPP
DOC
$ tar tf 7z2603-src.tar.xz | grep -c '^CPP/'     →  1092
```

1092 is the count of members **already under** a `CPP/` prefix — the opposite of
what the old forecast claimed it showed. `CPP/`, `CPP/7zip/` and
`CPP/7zip/Bundles/Alone2/makefile.gcc` are all present, and the earlier
citation `7zip/Bundles/Alone2/makefile.gcc` was pointing at the stripped tree,
not at the tarball.

## Per-system verdicts

The corrected entry point reaches real compile lines. Full dry run of the exact
command in `generic.lua`, with the NDK r28 `aarch64-linux-android35` wrappers:

```
$ make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc -j1 \
      CC=…/aarch64-linux-android35-clang CXX=…/aarch64-linux-android35-clang++ \
      CFLAGS_BASE2="-I/prefix/include -DANDROID" \
      CXXFLAGS_BASE2="-I/prefix/include -DANDROID" \
      CFLAGS_WARN_WALL="-Wall -Wextra" -n
exit=0    322 compile lines    0 errors

…/aarch64-linux-android35-clang -I/prefix/include -DANDROID -O2 -c -Wall -Wextra \
  -DNDEBUG -D_REENTRANT -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -fPIC \
  -o _o/7zBuf2.o ../../../../C/7zBuf2.c
…/aarch64-linux-android35-clang++ -I/prefix/include -DANDROID -O2 -c -Wall -Wextra … \
  -o _o/UserInputUtils.o ../../UI/Console/UserInputUtils.cpp
```

Every cross compiler reference is the NDK wrapper (323 lines mention it, 0
mention a host `cc`/`g++`).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The entry point reaches 322 clean compile lines (dry run above). Android is handled explicitly upstream: `CPP/Windows/TimeUtils.cpp:263` guards `#if defined(TIME_UTC) && !defined(__ANDROID__)` — its own comment at `:261` says *"Android NDK defines TIME_UTC but doesn't have the timespec_get()"* — falling through to `clock_gettime`; and `C/Threads.h:16` plus `C/Threads.c:419` both exclude `__ANDROID__` from the `pthread_setaffinity_np` path, so the affinity code that needs `_GNU_SOURCE` is never compiled on Bionic. `C/Threads.c` is in the build (`CPP/7zip/Bundles/Format7zF/Arc_gcc.mak:21`), so that guard is load-bearing. No AGENTS.md API-21 wall is used: `nl_langinfo`, `mktime_z`, `getpass`, `posix_spawn`, `process_vm_readv`, `mblen` all have zero matches, and `O_BINARY` appears only inside `#ifdef O_BINARY` guards. The one real Android wall, `-lpthread`, is handled in `android.lua`. |
| aarch64-android24 | WILL BUILD | As above. Nothing API-24-specific is used (no `nl_langinfo`, which is the API-26 addition). |
| aarch64-android35 | WILL BUILD | As above; this is the system the dry run above was taken on. |
| x86_64-android35 | WILL BUILD | Same reasoning. `android.lua` applies to every Android system via `recipe_fallbacks = {"android"}`, so the `LIB2=` fix covers it. x86 selects no different makefile fragment: `makefile.gcc` is used directly, not `cmpl_*.mak`, so no `USE_ASM` is set and no MASM assembler is wanted. |
| x86_64-mingw | UNCERTAIN | Everything above still applies — the compile side is fine — but the **link** side is not. `IS_MINGW` is auto-detected from a *Windows* environment variable (`CPP/7zip/Bundles/Format7zF/Arc_gcc.mak:6-11` tests `SystemDrive`/`SYSTEMDRIVE`), which is never set when cross-compiling to mingw from Linux, so the build silently takes the POSIX branch. Forcing `IS_MINGW=1` on the make command line selects the correct objects but then requires `windres.exe` (`CPP/7zip/7zip_gcc.mak:18`) to compile `CPP/7zip/Bundles/Alone2/resource.rc` into `$O/resource.o` (`Arc_gcc.mak:27`), and links `-loleaut32 -luuid -ladvapi32 -luser32 -lole32 -lgdi32 -lcomctl32 -lcomdlg32 -lshell32` (`7zip_gcc.mak:146`). Confirmed by dry run with `IS_MINGW=1`: the recipe then names `windres.exe`, and `CPP/7zip/Bundles/Format7zF/makefile.gcc:2` sets `DEF_FILE = ../../Archive/Archive2.def`. This is genuinely uncertain: `windres.exe` has no counterpart in this project's toolchain (only `$STRIP`/`$OBJCOPY` are exported, and the system never exports `RC` or `WINDRES`), and fixing it means either a new system-level export or a name that does not exist here. |
| clang-native | WILL BUILD | The plain case the build system was written for: the dry run with host `cc`/`g++` reaches the same 322 compile lines, `-lpthread` and `-ldl` both resolve on glibc, and `$LDFLAGS` is folded in by `7zip_gcc.mak:254`. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

## Risks / what a reviewer should check

1. **`-Werror` is dropped, deliberately and with the reason recorded.**
   `CPP/7zip/7zip_gcc.mak:27` hardcodes `CFLAGS_WARN_WALL = -Werror -Wall
   -Wextra`, folded into `CFLAGS_BASE` at `:53` and into the compile rule at
   `:172`. Any warning in a 2026 release under a 2026 clang would fail the
   build, and the recipe cannot see the warnings in advance. `-Wall -Wextra` are
   kept; only `-Werror` goes. A command-line assignment overrides the makefile's,
   so upstream's file is never edited.
2. **`CFLAGS_BASE2` / `CXXFLAGS_BASE2` are the load-bearing system seam.**
   `7zip_gcc.mak:172,213` assemble compile flags from scratch and never
   reference `$CFLAGS`/`$CXXFLAGS`, so passing those directly would do nothing.
   These two variables are read but never assigned anywhere in the tree — a
   clean append point that leaves upstream's own `-O2 -DNDEBUG
   -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE` intact. `LOCAL_FLAGS` was
   rejected for this role: `CPP/7zip/Bundles/Alone2/makefile.gcc:43` assigns it,
   so overriding it from the command line would drop `-DZ7_ST`/`-DZ7_DEVICE_FILE`.
3. **`LIB2=""` in `android.lua` is Android-only and load-bearing** — see that
   file for the `ld.lld: error: unable to find library -lpthread` probe. Verified
   by dry run: with `LIB2=` the link line contains no `-lpthread`.
4. **No install target exists, so the recipe copies `bin/7zz` itself.** The
   binary lands at `CPP/7zip/Bundles/Alone2/_o/7zz` (`PROG = 7zz`,
   `Alone2/makefile.gcc:1`). An earlier revision of this recipe had no publish
   step at all, which would have merged an empty tree — noted here because that
   is a silent failure mode, not an error.
5. **The `cmpl_*.mak` entry points are present but not used.**
   `CPP/7zip/cmpl_gcc.mak`, `cmpl_clang.mak`, `cmpl_gcc_x64.mak`,
   `cmpl_gcc_arm64.mak` and the rest all exist. They `include makefile.gcc`, which
   they expect *in the same directory* — `CPP/7zip/makefile.gcc` — and that file
   **is absent** (verified: `CPP/7zip/` contains only `7zip/`, `Common/`,
   `Windows/` and `Build.mak`). So those entry points, the ones `readme.txt:151-165`
   advertises for "optimized code", cannot run from this tarball at all. That
   claim from the earlier revision was *correct*; it is simply not a problem,
   because the documented `makefile.gcc` entry point is the one used. An earlier
   revision also wrongly asserted `7zip/makefile.gcc` was missing — in the
   stripped tree it was, but the file that matters, `CPP/7zip/Bundles/Alone2/
   makefile.gcc`, was there all along and is what the recipe runs.
6. **`USE_ASM` is off, so no MASM assembler is needed.** `var_gcc_x64.mak:7` and
   `var_gcc_arm64.mak:6` set `USE_ASM=1`, but those belong to the `cmpl_*.mak`
   path, which is not used. Running `makefile.gcc` directly leaves `USE_ASM`
   unset, so the pure-C `*Opt.c` fallbacks compile (`7zip_gcc.mak:207-217`
   `USE_X86_ASM` blocks). No `asmc`/`jwasm` needed anywhere.

## What is NOT the problem (checked, so nobody re-investigates it)

- **No generated sources.** The premise that 7-Zip "generates sources with C++
  that may not be portable" does not hold: there is no code-generation step in
  any makefile, and all sources ship pre-written. `grep -rln 'char8_t\|requires
  \|concept '` matches ordinary identifiers only.
- **Android support is deliberate, not accidental** — see the aarch64-android21
  row for the two `__ANDROID__` sites.
- **No API-level wall in the sources.** Grepped the whole tree for every
  AGENTS.md gate; the only near-miss is `timespec_get`, which upstream explicitly
  disables on Android at `CPP/Windows/TimeUtils.cpp:263`.