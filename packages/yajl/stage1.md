# yajl build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 2.1.0 (`2.1.0` tag; upstream is dormant, this is the
  current release and the newest tag)
- Build system: **cmake**. The tag archive also ships a `configure` script and
  an `Android.configure.mk`, but the cmake path is used here.
- Installs: `lib/libyajl.a`; `include/yajl/*.h`; `share/pkgconfig/yajl.pc`
  (`src/yajl.pc.cmake`, `Name: Yet Another JSON Library`, installed to
  `share/pkgconfig` at `src/CMakeLists.txt:87`).
- Requires: `yajl@source` only. **No dependency** — yajl is freestanding C.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | yajl 2.1.0 does not configure with the cmake in this tree. See the failure below. |
| aarch64-android24 | **WILL NOT BUILD** | Same, and not API-level: configure dies before a single target exists. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | Same. Independently, yajl's cmake path is unverified on a PE toolchain. |
| clang-native | **WILL NOT BUILD** | Same. This is not a target problem — the native system has the newest cmake and hits it hardest. |

## API level notes

**The API level is irrelevant and the cmake breakage is the whole story.**
yajl's own code has no platform surface at all: no `nl_langinfo`, no
`getsubopt`, no `scandir`/`versionsort`, no `fread_unlocked`, no
`argp_parse`, no `mktime_z`, no `posix_spawn`, no `process_vm_readv`. But
none of that matters while configure aborts.

## Why it does not configure

yajl 2.1.0's top-level `CMakeLists.txt:66-71` adds six subdirectories
with **no option to suppress any of them**: `src`, `test`, `reformatter`,
`verify`, `example`, `perf`. Two of them are fatal:

- `reformatter/CMakeLists.txt:38` — `GET_TARGET_PROPERTY(binPath
  json_reformat LOCATION)`
- `verify/CMakeLists.txt:32` — `GET_TARGET_PROPERTY(binPath json_verify
  LOCATION)`

Reading a target's `LOCATION` property was deprecated in cmake 3.19 and is a
**hard error** in cmake 4.x, which is what this prefix carries. Configure
dies with "The LOCATION property may not be read from target ...", before
any target has been created, so no downstream step runs on any system.

**There is no recipe-level fix and no flag.** The escape hatch would be a
cmake older than 3.19, which belongs in the system files, not in a recipe.
Escalated to the director rather than worked around.

## There is no Android.mk escape hatch

An earlier version of this file said the tag archive ships "a `configure`
script and an `Android.configure.mk`". The `configure` is real but it is
only a **cmake wrapper**, so it hits the same failure. The `.mk` is not
there at all — `find . -maxdepth 1 -name '*.mk'` returns nothing. Recorded
because citing the two together sends a builder looking for an escape hatch
that does not exist, and there is no `configure.ac` either.

## Risks / what a reviewer should check

- **The package should be recorded as blocked, not left pending.** The
  recipe is syntactically correct and system-neutral, but it cannot run in
  this tree. What would unblock it is a system-level change — a cmake older
  than 3.19 — which belongs in `packages/<sys>/generic.lua`, not in a
  recipe. **Escalating that as a package-level call rather than working
  around it here**, because the alternative is a prefix carrying a cmake old
  enough to be a security liability.
- **yajl has no options at all — this is unusual and it shaped the recipe.**
  The top-level `CMakeLists.txt` declares no `option()`, so there is no
  `ENABLE_TESTS`, no `YAJL_BUILD_APPS`, nothing to switch off. It then adds
  six subdirectories unconditionally at lines 66-71: `src`, `test`,
  `reformatter`, `verify`, `example`, `perf`. Five of those build host
  programs — `json_reformat`, `json_verify`, `parse_config`, `perftest` and
  the `test/` binaries. **The brief's warning pattern does not apply here
  and the recipe works around it the way `packages/simdjson` does**: build
  only the library target (`yajl_s`, `src/CMakeLists.txt:38`) and let
  `cmake --install` place the archive, headers and `.pc`.
- **That approach has a shape worth checking.** `src/CMakeLists.txt:38` also
  declares `ADD_LIBRARY(yajl SHARED ...)`, which the target-scoped build
  skips. `cmake --install` then installs only what was built. If a future
  yajl adds a `test/` install rule for something the `yajl_s` build did not
  produce, install fails rather than silently skipping. That is the
  preferable failure, but worth knowing.
- **`cmake -DCMAKE_MINIMUM_REQUIRED(VERSION 2.6)`** is far below the tree's
  cmake, so the systems' `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` floor is
  inert here.
- **`yajl.pc` goes to `share/pkgconfig`, not `lib/pkgconfig`.** Both are
  inside the loader's `$OUT`→`$PREFIX` rewrite set (`src/loader.lua:454-468`
  covers `share/pkgconfig/*.pc`), so the prefix works — but a consumer's
  `pkg-config` search path must include `$PREFIX/share/pkgconfig`, which
  every system in this repo does set.

## How to verify once built

- `lib/libyajl.a` — and `lib/libyajl.so*` must be **absent**
- `include/yajl/yajl_parse.h`, `include/yajl/yajl_tree.h`,
  `include/yajl/yajl_version.h`
- `share/pkgconfig/yajl.pc` and `pkg-config --modversion yajl` → `2.1.0`
  (note the module name is `yajl`, from `Name: Yet Another JSON Library`)
- `readelf -h lib/libyajl.a` → `Machine: AArch64` on Android targets
- `$OUT/bin` must be **absent** — `json_reformat` and `json_verify` would
  mean the target-scoped build did not take
