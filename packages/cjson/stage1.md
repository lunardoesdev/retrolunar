# cjson build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 1.7.19
- Build system: cmake
- Installs: `lib/libcjson.a` (static); `include/cjson/cJSON.h`; `lib/pkgconfig/libcjson.pc`; `lib/cmake/cJSON/cJSONConfig.cmake`; **no programs** — `cJSON_add`/`cJSON_pretty` do not exist in 1.7.19, and the utils are the `cjson_utils` *library* behind `ENABLE_CJSON_UTILS`, which defaults OFF
- Requires: `cjson@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `cJSON.c` is C89-compatible C with no platform dependency at all — it uses `malloc`/`free`, `snprintf`, `strtod` and string ops, all in Bionic at API 21. `ENABLE_CJSON_TEST=OFF` (`generic.lua:9`) removes the test program, which is the only host program in the tree. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral. |
| x86_64-mingw | WILL BUILD | cJSON has no platform gate; `BUILD_SHARED_LIBS=OFF` avoids export macros. |
| clang-native | WILL BUILD | Native; topackage.md:148 records cJSON 1.7.19 as `[x]` with `elf64-littleaarch64` archive members. |

## API level notes

Not a variable. This is the smallest possible surface in the shard: one C
file, no libc beyond C89. Nothing in the a–g shard is less likely to be
affected by the API level.

## Risks / what a reviewer should check

- **The installed CMake config needed the loader's `$OUT`→`$PREFIX` rewrite
  and previously did not get it** — topackage.md:148 records this verbatim:
  "the installed CMake config needed the loader's staging-path rewrite - it
  originally pointed at the build's staging dir, which broke the first
  consumer, msgpack-c". The loader does that rewrite automatically
  (AGENTS.md: "Staged `.pc` files get `$OUT` paths rewritten to `$PREFIX`"),
  and its glob covers `lib/cmake/*.cmake`. **The risk is that a future
  loader change to those globs silently breaks cJSON's `find_package`**
  again, and the symptom is a consumer failing to configure, not cJSON
  failing to build. This is the most valuable thing to re-check here.
- **Nothing but the core library is installed.** The earlier version of this
  file claimed `cJSON_add` and `cJSON_pretty` were installed target
  programs; they do not exist in 1.7.19. `ENABLE_CJSON_UTILS`
  (CMakeLists.txt:174) defaults OFF and builds a library, not programs.
- **cJSON 1.7.19 requires a C99-capable compiler** for its designated
  initialisers in `cJSON.c`. The NDK clang defaults to gnu17 and the native
  system does too, so no `-std` flag is needed. Worth knowing that the
  recipe gets away without one.

## How to verify once built

- `lib/libcjson.a`
- `include/cjson/cJSON.h`
- `lib/cmake/cJSON/cJSONConfig.cmake` — and **grep it for the staging
  path**: it must contain `$PREFIX`'s value, not a `mktemp` path. That is
  the check that catches a loader-glob regression.
- `pkg-config --modversion libcjson` → `1.7.19`. The module name is `libcjson`, not `cjson`: `library_config/libcjson.pc.in:4` is `Name: libcjson`. An earlier version of this line said `cjson`, which does not resolve, so the builder would have chased a missing-package error that was really a typo here.
- `bin/cJSON_add` and `lib/libcjson_utils.a` must both be **absent**
- `readelf -h lib/libcjson.a` → `Machine: AArch64` on Android targets
- `pkg-config --modversion libcjson` → `1.7.19`, or `find_package(cJSON)`
