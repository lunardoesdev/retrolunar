# easylogging-plusplus build forecast

- Recipe: `generic.lua`, source `source.lua` (no `android.lua`)
- Version pinned: 9.97.1 (tag `v9.97.1`)
- Build system: CMake, `cmake_minimum_required(VERSION 2.8.7)`
  (`CMakeLists.txt:1`)
- Header-only: **yes**, in the split-header sense — `build_static_lib`
  defaults OFF (`CMakeLists.txt:25`), so nothing is compiled and no library
  is installed.
- Installs: `include/easylogging++.h`, `include/easylogging++.cc`
  (`CMakeLists.txt:38-42`) and `share/pkgconfig/easyloggingpp.pc` (`:44-47`).
  **No CMake package config** — see risk 1. No library file.
- Requires: `easylogging-plusplus@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled (`build_static_lib` OFF at `:25`) and `test=OFF` keeps the only `add_executable` (`:87-100`) out of the graph. The install is a two-file copy plus a generated `.pc`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. Nothing platform-specific is selected at build time: the only configure-time probe is `check_include_file_cxx("execinfo.h")` (`:49-53`), whose result is never even used by an installed artifact. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is a file copy, identical on every
system, and no architecture check applies. `armv7a-*`/`i686-*` match the
`aarch64-*` rows.

## Upstream identity — the repo name in the brief is a 404

`github.com/abumq/easylogging-plusplus` returns **404**. The repository is
`abumq/easyloggingpp`, and upstream's own README points at it
(`README.md:102` → `github.com/abumq/easyloggingpp/releases`). I confirmed it
is the same project by title and content ("C++ logging library…") and by the
`ACKNOWLEDGEMENTS.md` file, which links `amrayn/easyloggingpp` PRs from the
project's own history. v9.97.1 is the newest tag (20-07-2023,
`CHANGELOG.md:3`). Recorded in `source.lua`.

## The layout is what upstream installs — including the `.cc`

`CMakeLists.txt:38-42` is

```cmake
install(FILES
    src/easylogging++.h
    src/easylogging++.cc
    DESTINATION "${ELPP_INCLUDE_INSTALL_DIR}"
    COMPONENT dev)
```

Both files land in `include/`, side by side. That is correct for this library
and not an accident: easylogging++ was split from a single header into
`.h`/`.cc` (the project's own `ACKNOWLEDGEMENTS.md` credits the split), and a
consumer compiles `easylogging++.cc` into their own program. A recipe that
"helpfully" installed only the header would ship a package whose
implementation file is missing.

Note there is **no subdirectory structure at all** — no `include/easylogging/`,
no `easylogging++/…`. `-I${includedir}` (`easyloggingpp.pc.cmakein:7`) is the
whole include story, so this is the one header package in this batch where the
Eigen-style subdirectory trap does not apply.

## Risks / what a reviewer should check

1. **There is no CMake package config, and `CMakeLists.txt:69` looks like
   there should be.** Line 69 is a bare `export(PACKAGE
   ${PROJECT_NAME})`. With no `install(EXPORT ...)` anywhere in the file and
   no `*Config.cmake.in` template in the tree (I checked:
   `cmake/` holds only `FindEASYLOGGINGPP.cmake`, `Findgtest.cmake` and
   `easyloggingpp.pc.cmakein`), nothing is written to `$OUT` beyond the `.pc`.
   **`easyloggingpp.pc` is the only discovery mechanism** — a consumer using
   `find_package(easyloggingpp)` will not find it. Record this as a property
   of the package, not a gap in the recipe.
2. **The installed `.pc` reports the wrong version.** `CMakeLists.txt:29-30`
   hardcodes `ELPP_MINOR_VERSION "96"` / `ELPP_PATCH_VERSION "7"` while the
   tag is `v9.97.1`, so the `Version:` field of the generated
   `easyloggingpp.pc` (`easyloggingpp.pc.cmakein:4`, `@ELPP_VERSION_STRING@`)
   renders **9.96.7**.
   This is an upstream defect that a recipe cannot fix without editing
   `CMakeLists.txt`, which the no-patch rule forbids. Expected value for the
   build check is **9.96.7**, not 9.97.1.
3. **`check_include_file_cxx("execinfo.h")` (`:49-53`) is a compile probe that
   is then discarded.** With `build_static_lib` off it adds
   `-DHAVE_EXECINFO` to a build that compiles nothing. It is a
   `try_compile`, not a `try_run`, so `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`
   covers it on the cross systems and it is safe.
4. **The header does have a platform split, but it is consumer-side.**
   `easylogging++.h:124-131` selects `ELPP_OS_UNIX`, `:129-133` detects
   `__ANDROID__` as `ELPP_OS_ANDROID`, `:364-367` pulls `<cxxabi.h>` and
   `<execinfo.h>` when `HAVE_EXECINFO` is defined, and `:368-370` pulls
   `<sys/system_properties.h>` on Android. None of that is evaluated at *our*
   build time; it is all in the installed header and is the consumer's
   problem. Worth stating because it is the one place this package touches a
   target libc at all.
5. `lib_utc_datetime` (`:26`, default OFF) only appends
   `-DELPP_UTC_DATETIME` to this build's own compile line (`:57`). With no
   static library there is nothing to compile, so it is genuinely inert here
   and correctly left alone.

## How to verify once built

- `include/easylogging++.h` **and `include/easylogging++.cc` both exist**.
  The `.cc` is the load-bearing check: it is the implementation, and its
  absence is exactly the defect the split-header layout makes possible.
- `share/pkgconfig/easyloggingpp.pc` exists.
  **Note it is under `share/pkgconfig`, not `lib/pkgconfig`** — upstream's own
  choice at `CMakeLists.txt:34`, and both are on every system's
  `PKG_CONFIG_LIBDIR`.
- `pkg-config --modversion easyloggingpp` reports **9.96.7**. State this
  expected value explicitly (risk 2) so the next reader does not file it as a
  defect.
- **`find $OUT -name '*.a' -o -name '*.so'` returns nothing** — the single
  check that proves nothing was compiled and `build_static_lib=OFF` took.
- `find $OUT -name '*Config.cmake'` returns nothing. Expected (risk 1), not a
  gap.
- Compare two systems' `include/` with `diff -r`: any difference is a bug.
