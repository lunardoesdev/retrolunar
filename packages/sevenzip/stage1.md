# 7-Zip build forecast — `sevenzip`

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 26.03
- Build system: **hand-written Windows nmake + GNU make**. No `CMakeLists.txt`, no
  `configure`, no `meson.build` anywhere in the tarball (verified by `find`).
  `Build.mak:1` onwards is nmake syntax (`!IFNDEF`, `!IF`). The GNU-make path is
  `CPP/7zip/Bundles/*/makefile.gcc`, documented at `readme.txt:138-144`.
- Requires: `sevenzip@source` only (`generic.lua:1`)
- Installs: nothing. There is no `install` target in the tree
  (`grep -rn '^install' --include='*.mak' --include='makefile*' .` → no match).

## Summary

**WILL NOT BUILD on every system family.** The release tarball cannot be built by
the build system it ships. This is a property of the tarball, not of the
toolchain: see "The blocking defect" below.

## The blocking defect

`7z2603-src.tar.xz` unpacks with the tarball root being the *contents* of
upstream's `CPP/` directory. Evidence:

- `tar tf … | grep -c '^CPP/'` → **1092**. Every C++ member is stored under a
  `CPP/` prefix in the archive.
- `tar tf … | head -3` → `Asm/arm/7zCrcOpt.asm`, `Asm/arm64/7zAsm.S`,
  `Asm/arm64/LzmaDecOpt.S` — i.e. `CPP/Asm/…` arrived as `Asm/…`. The `CPP/`
  component is the first one and is what `--strip-components=1` consumes.
- After unpacking, the tree has `7zip/`, `Common/`, `Windows/`, `C/`'s contents
  (`7z.h`, `7zAlloc.c`, …) and `Util/` **all at the top level**, and there is no
  `CPP/` directory.

Upstream's makefiles are written for that layout, so their `../../../../`
references are one level too deep once `CPP/` is gone. The documented entry
point fails immediately, before compiling anything:

```
$ cd 7zip/Bundles/Alone2 && make -f makefile.gcc
mkdir -p _o
make: *** No rule to make target '../../../../C/7zBuf2.c', needed by '_o/7zBuf2.o'.  Stop.
```

That is a dry run (`-n`); nothing was compiled. `7zip/Bundles/Alone2/makefile.gcc`
resolves its own include chain fine (`../Format7zF/Arc_gcc.mak`,
`../../7zip_gcc.mak`, `../../LzmaDec_gcc.mak` all exist — each verified), so the
failure is specifically the source-file paths, not the includes.

The same defect applies to every other bundle and to `cmpl_*.mak`
(`7zip/cmpl_gcc.mak`, `cmpl_gcc_x64.mak`, `cmpl_clang.mak`, …), which
`include makefile.gcc` from `CPP/7zip/` — and `7zip/makefile.gcc` **does not
exist in the tarball** (`7zip/` holds only a 2009-era `makefile`, 102 bytes,
dated Nov 28 2009). So the "optimized code" entry points that `readme.txt:151-165`
advertises cannot run either.

The nmake path is not a fallback: `Build.mak` is nmake-only and this is Linux.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | Blocks before any compiler runs: `make -C 7zip/Bundles/Alone2 -f makefile.gcc` dies on `No rule to make target '../../../../C/7zBuf2.c'`. Nothing is compiled, so the API level is never reached. |
| aarch64-android24 | WILL NOT BUILD | Same pre-compile failure. |
| aarch64-android35 | WILL NOT BUILD | Same pre-compile failure. |
| x86_64-android35 | WILL NOT BUILD | Same pre-compile failure. `USE_ASM=1` in `var_gcc_x64.mak:7` would additionally require `asmc`/`jwasm` (MASM assembler), which is a separate and independent wall. |
| x86_64-mingw | WILL NOT BUILD | Same pre-compile failure, plus two mingw-only problems that would remain after it: `7zip/7zip_gcc.mak:18` sets `RC=windres.exe` and `:270-274` compiles `resource.rc` into `$O/resource.o` unless `NO_DEFAULT_RES` is set, and `7zip_gcc.mak:146` links `-loleaut32 -luuid -luuid -ladvapi32 -luser32 -lshell32 -lcomctl32 -lcomdlg32` plus `$O/resource.o`, a Windows-only object set. |
| clang-native | WILL NOT BUILD | Same pre-compile failure. Native gcc/clang would satisfy the toolchain side, but it never gets that far. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

## What is NOT the problem (checked, so nobody re-investigates it)

- **No generated-C++ portability problem.** The premise that 7-Zip "generates
  sources with C++ that may not be portable" does not hold: nothing in the tree
  is generated. `grep -rln 'char8_t\|requires \|concept '` matches ordinary
  identifiers, and there is no code-generation step in any makefile. All
  sources ship pre-written.
- **Android is explicitly handled upstream, twice.**
  `Windows/TimeUtils.cpp:258-266` documents *"Android NDK defines TIME_UTC but
  doesn't have the timespec_get()"* and guards
  `#if defined(TIME_UTC) && !defined(__ANDROID__)`, falling through to
  `clock_gettime`. `Threads.h:16` and `Threads.c:419` both exclude
  `__ANDROID__` from the `pthread_setaffinity_np` path. So the Android API level
  is not the wall.
- **No API-21 wall in the sources.** Grepped the whole tree for the AGENTS.md
  walls: `nl_langinfo`, `mktime_z`, `getpass`, `posix_spawn`,
  `process_vm_readv` → **no matches**. `O_BINARY` appears only inside
  `#ifdef O_BINARY` guards (`7zFile.c:77-78`, `Windows/FileIO.cpp:777-778`), so
  it is inert. `Windows/System.cpp:197` uses `sysconf`, present at API 21.
- **`-ldl` links fine on Android.** `7zip_gcc.mak:165` adds `-lpthread -ldl`;
  `7zip_gcc.mak:164` (`LIB2 = -lpthread`) is the variant actually in force. A
  probe confirmed Bionic has **no** `libpthread` (`ld.lld: error: unable to find
  library -lpthread`) but `-ldl` resolves. So `-lpthread` would be a *second*
  Android-only fix, on top of the blocking one — recorded, not acted on.

## If this is to be revisited

The fix is not a recipe change. It requires either a source layout that keeps
`CPP/` (a git checkout with `git = .../7zip`, `tag = "26.03"`), or a source
recipe that re-creates the missing directory level before invoking make. Both
change what the recipe builds relative to what upstream ships, so they are a
decision for the director, not something to smuggle into `generic.lua`.