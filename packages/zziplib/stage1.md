# zziplib build forecast — `zziplib`

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.13.78
- Build system: **CMake** (`CMakeLists.txt:1-2`, `cmake_minimum_required 3.1`,
  `project(zziplib VERSION "0.13.78" LANGUAGES C)`). The autotools path is
  retired, not merely stale — see "The premise that does not hold" below.
- Requires: `zlib` and `zziplib@source` (`generic.lua:1-2`). zziplib links
  `ZLIB::ZLIB` (`zzip/CMakeLists.txt:150-151`) and ships
  `Requires: zlib` in its `.pc`.
- Installs: `lib/libzzipmmapped-0.a`, `include/zzip/*.h`,
  `lib/pkgconfig/zziplib.pc`, `lib/pkgconfig/zzipmmapped.pc`, plus
  `lib/cmake/zziplib/*`.

## The premise that does not hold

Two of the stated assumptions are wrong for 0.13.78, and both change the
forecast, so they are recorded up front.

**It is not C++.** `CMakeLists.txt:2` declares `LANGUAGES C`, and a `find` for
`*.cpp`, `*.cc`, `*.hpp` over the whole unpacked tree returns **nothing**. The
"old C++ with a configure that has not been maintained in years" description
does not describe this version. Consequently the C++-standard concern is moot:
there is no `-std=` to pick, and the AGENTS.md note that NDK clang defaults to
C23 (needing `-std=gnu17` for old `bool`-typedef code) **does not apply here**.
A probe confirms NDK r28's clang++ defaults to `__cplusplus 201703L`, which is
moot for a C-only project.

**Its configure is not merely unmaintained — it is parked on purpose.**
`configure.ac` is present only as `old.configure.ac`, and **no generated
`configure` ships** (both verified: `old.configure.ac` 30 KB present,
`configure` ABSENT). `GNUmakefile:72-73` shows the upstream workflow is
`ln -sv old.configure configure` before use. So the autotools route requires
either autoreconf or a `ln -s` — `autoreconf` is not in the allowed build-body
verbs. cmake is not merely the nicer choice here, it is the only one available
under the hygiene rules.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | No API-21 wall in the source — see the API notes below, which are clean. The open question is `find_package(UnixCommands REQUIRED)` at `zzip/CMakeLists.txt:51`, whose module is not in the tree; see "The blocker to check first". If that resolves, this row is WILL BUILD. |
| aarch64-android24 | UNCERTAIN | As above. Nothing API-24-specific is used. |
| aarch64-android35 | UNCERTAIN | As above. |
| x86_64-android35 | UNCERTAIN | As above. `zzip/CMakeLists.txt:56-58` guards `check_include_files(dirent.h ZZIP_HAVE_DIRENT_H)` on `if(NOT ANDROID)` — and per AGENTS.md our toolchain files deliberately set `CMAKE_SYSTEM_NAME` to `Linux`, so cmake's `ANDROID` is **never set** and that branch *does* fire. Bionic does have `dirent.h`, so the probe succeeds harmlessly; recorded so nobody reads it as a platform bug. |
| x86_64-mingw | UNCERTAIN | `zzip/CMakeLists.txt:29-35` turns ZZIP_COMPAT/ZZIP_LIBTOOL/ZZIP_PKGCONFIG **off** when neither `UNIX` nor `MINGW` matches, and our toolchain sets `CMAKE_SYSTEM_NAME=Linux`, so `UNIX` matches and they stay ON — as intended. Needs a real build; mingw is the least-trodden path here (upstream's `makefile.android_arm` and mingw coverage both predate current NDKs). |
| clang-native | UNCERTAIN | As above. Best chance of the six, since native cmake + zlib + bash are all present and no cross-compile probe can fail. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

## The blocker to check first

`zzip/CMakeLists.txt:51` calls

    find_package ( UnixCommands REQUIRED ) # bash cp mv rm gzip tar

guarded by `if(ZZIP_COMPAT OR ZZIP_PKGCONFIG)` (`:49`). `find` for `Find*.cmake`
over the whole tree returns **nothing** — `CMakeScripts/` holds only
`CheckVerboseSymlink.cmake`, `CodeCoverage.cmake` and `JoinPaths.cmake`. cmake
would fall back to its own module path and then fail the REQUIRED check.

`generic.lua` sidesteps this by passing `-DZZIP_COMPAT=OFF`; but
`find_package(UnixCommands REQUIRED)` also sits at `bins/CMakeLists.txt`,
`test/CMakeLists.txt:32` and `docs/CMakeLists.txt:24`, all three of which the
recipe switches off (`-DZZIPBINS=OFF -DZZIPTEST=OFF -DZZIPDOCS=OFF`). If cmake
still reports the module missing, the confirmed fix is `-DZZIP_PKGCONFIG=OFF`
as well, at the cost of the `.pc` file.

## API-level notes

**No API gate.** The library's libc surface, checked against the NDK r28 clang
wrappers at API 21, 24 and 35 — a probe using `pread`, `strndup` and
`strcasecmp` compiled **clean at all three levels** (one unrelated
`-Wpointer-to-int-cast` warning from the probe itself). `zzip/CMakeLists.txt:80-81`
probes exactly `strndup` and `:78` probes `pread`, and both exist at API 21.
Grepped the tree for the AGENTS.md walls — `nl_langinfo`, `mktime_z`, `getpass`,
`O_BINARY`, `posix_spawn`, `mblen`: no use.

## Risks / what a reviewer should check

1. **`-DBUILD_SHARED_LIBS=OFF` is load-bearing** and the reason is recorded:
   cmake defaults this ON (`CMakeLists.txt:11`) and every other library in this
   prefix is static, since a target prefix has no loader path for a versioned
   `.so`. With it off, the `libzzip_links` / `libzzip_latest` symlink targets
   (`zzip/CMakeLists.txt:184-199`, `:239-…`) become no-ops, which is what we want.
2. **The `sed` inside zziplib's own cmake is not a recipe `sed`.**
   `ZZIP_PKGCONFIG` generates `zziplib.pc` via a `${BASH} -c "... sed ..."`
   custom command (`zzip/CMakeLists.txt:233-241`). That is upstream's build
   system editing files *it* generated in this run, which AGENTS.md permits
   ("`awk` is permitted only on a generated file under `$OUT`" — the same
   principle, upstream's own build step). The recipe itself contains no `sed`.
   `ZZIP_COMPAT` is switched **off** precisely because its equivalent command
   (`zzip/CMakeLists.txt:190-204`) is more of the same and buys only deprecated
   compat headers.
3. **`ZZIPMMAPPED` is deliberately left ON** (default), and the recipe sets
   `ZZIPFSEEKO=OFF`. `zzip/CMakeLists.txt:22` labels mmapped "not fully
   portable"; that refers to mmap-based seeking, which zziplib only uses when
   the caller asks for it via `zzip_seek_map`. If a builder wants the
   conservative set, `-DZZIPMMAPPED=OFF` is the single flag to add.
4. **`find_package(ZLIB REQUIRED)`** resolves through `CMAKE_PREFIX_PATH`,
   which every system file sets to `$PREFIX` — hence the `require("zlib")` at
   `generic.lua:1`.
5. **Version-pin drift:** Debian carries `0.13.72` and `0.13.78`; 0.13.78 is
   what `source.lua` pins and is the newest upstream release the pool has.