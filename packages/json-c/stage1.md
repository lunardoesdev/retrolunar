# json-c build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 0.19 (`json-c-0.19-20260627`, the current `releases/latest`)
- Build system: **cmake** (the tree also ships `meson.build`; cmake is used here)
- Installs: `lib/libjson-c.so` **and** `lib/libjson-c.a` unless
  `BUILD_SHARED_LIBS=OFF` is honoured; `include/json-c/*.h`; `lib/pkgconfig/json-c.pc`
  (`json-c.pc.in:6` is `Name: json-c`). With the recipe's flags: static archive
  plus headers plus `json-c.pc`. No programs — `BUILD_APPS=OFF`.
- Requires: `json-c@source` only. **No dependency at all** — json-c needs no
  external library.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Pure C99 library, no platform dependency. `json_object.c`, `json_tokener.c`, `linkhash.c`, `arraylist.c`, `printbuf.c`, `debug.c` use only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<ctype.h>`, `<math.h>`, `<errno.h>` plus json-c's own headers. Grep for every Bionic-absent symbol — `nl_langinfo`, `program_invocation_short_name`, `get_current_dir_name`, `fread_unlocked`, `scandir`, `argp_parse`, `getsubopt`, `getpass`, `O_BINARY`, `mktime_z` — returns nothing. `DISABLE_WERROR=ON` is what makes this row safe rather than lucky: `CMakeLists.txt:361-362` appends `-Werror` to `CMAKE_C_FLAGS` whenever `DISABLE_WERROR` is OFF, and it is OFF by default, so a single new warning from the NDK clang would otherwise be a hard error. |
| aarch64-android24 | WILL BUILD | As above; nothing in json-c is API-level gated. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same sources, no arch-conditional code in the library. |
| x86_64-mingw | WILL BUILD (moderate confidence) | `CMakeLists.txt:30-48` has a `IF (WIN32)` branch that only adjusts warning flags and linker flags, not source selection. `json_util.c` uses `strerror`, `vasprintf` and `vsnprintf`; json-c ships its own compatibility shims for these (`vasprintf_compat.h`, `snprintf_compat.h`, `strerror_override.c`) precisely so it builds where they are missing. Moderate because I did not check mingw's `strerror` signature against `strerror_override.c`. |
| clang-native | WILL BUILD | Native glibc x86_64; the obvious consumer for a JSON parser and the system the Linux candidates list implies. |

## API level notes

**21 is the floor and json-c sits comfortably above it.** Nothing in the
library reaches for a symbol introduced after API 21. The one API-adjacent
switch is `ENABLE_THREADING` and `DISABLE_THREAD_LOCAL_STORAGE`
(`CMakeLists.txt:61,64`), both OFF by default: with them off, json-c uses no
`__thread` and no mutex, which sidesteps the pthread-cancellation and
`-lpthread` questions entirely. Left at their defaults.

## Risks / what a reviewer should check

- **`-Werror` was the real defect and the flag name changed between
  versions.** The brief warned that `ENABLE_CUSTOM_COMPILER_FLAGS` defaults
  ON and appends `-Werror`. In 0.19 that option no longer exists; it is
  `DISABLE_WERROR` (`CMakeLists.txt:62`, default **OFF**, i.e. `-Werror` is
  active) and `-Werror` is appended at `CMakeLists.txt:361-362`. A recipe
  copied from 0.18 would pass a now-unknown option and silently keep
  `-Werror`. That is why the recipe names the 0.19 spelling in its comment.
- **`BUILD_APPS` defaults ON** (`CMakeLists.txt:70`) and builds
  `apps/json_parse.c`, a host program, added at `CMakeLists.txt:656-659`.
  The brief did not mention this one; without `BUILD_APPS=OFF` the prefix
  silently gains a program.
- **`BUILD_SHARED_LIBS` defaults ON** (`CMakeLists.txt:45`) *and*
  `BUILD_STATIC_LIBS` also defaults ON (`:46`), so an unconfigured build
  produces both. Passing only `BUILD_SHARED_LIBS=OFF` is what leaves just
  the archive; the recipe passes `BUILD_STATIC_LIBS=ON` too so the intent is
  explicit rather than dependent on a default.
- **json-c 0.19 requires cmake 2.6 minimum** (`CMakeLists.txt:42`), far
  below the tree's cmake, so the `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` floor
  the systems set is inert here.

## How to verify once built

- `lib/libjson-c.a` — and `lib/libjson-c.so*` must be **absent**; its
  presence means `BUILD_SHARED_LIBS=OFF` did not take.
- `include/json-c/json.h`, `include/json-c/json_object.h`,
  `include/json-c/json_tokener.h`
- `lib/pkgconfig/json-c.pc` and `pkg-config --modversion json-c` → `0.19`
- `readelf -h lib/libjson-c.a` → `Machine: AArch64` on Android targets,
  `pei-x86-64` on mingw
- `$OUT/bin` must be **absent** — its presence means `BUILD_APPS=OFF` did
  not take
- No test binary anywhere under `$OUT` (`BUILD_TESTING=OFF`)
