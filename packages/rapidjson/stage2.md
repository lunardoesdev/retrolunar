REJECT

# rapidjson 1.1.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`v1.1.0` tree. I did not build anything.

**The recipe will build. The one required change is comment text only — no flag
changes, no source changes, no build risk.** AGENTS.md requires that every
non-obvious switch carry an explanation of why ("Explain non-obvious flags and
recipe-local workarounds"), and the explanation attached to
`RAPIDJSON_BUILD_EXAMPLES=OFF` is not merely thin, it is inverted with respect to
the load-bearing fact.

## Required changes

### 1. `packages/rapidjson/generic.lua`, lines 11-17 — the comment is false and it invites a build-breaking edit

It currently reads:

```
        # Everything upstream builds by default is host-side work with no
        # place in a target prefix: the docs need doxygen, and the examples
        # and the perftest/unittest tree link against a library that does not
        # exist (rapidjson is headers), which is why they only turn up inside
        # GTESTSRC_FOUND/guarded blocks in the first place. The tests block
        # additionally wants the thirdparty/gtest submodule, which the release
        # tag archive does not ship.
```

Every clause about the **examples** is wrong, and they are the clauses that
justify the flag:

- `example/CMakeLists.txt` has **fifteen unconditional `add_executable` calls**
  (lines 22-37), not guarded blocks. There is no `GTESTSRC_FOUND` and no
  library link to be guarded against.
- Worse, that file sets, for Clang,
  `-Werror -Wall -Weffc++ -Wswitch-default -Wfloat-equal -Wimplicit-fallthrough
  -Weverything`, and for GNU `-Werror -Wall -Wextra -Weffc++ -Wswitch-default`
  (`example/CMakeLists.txt:18-24`). `-Werror -Weverything` against a 2016
  codebase on NDK clang 19 is a build failure, not a warning.
- And the top-level file appends `-march=native`
  (`CMakeLists.txt:53` and `:76`). On `aarch64-linux-androidNN-clang` and
  `armv7a-linux-androideabiNN-clang`, `-march=native` is a **hard error**
  ("unsupported argument 'native' to argument '-march='"). `stage1.md` gets this
  exactly right (its per-system rows and scrutiny item 1); the recipe comment
  does not.

The `GTESTSRC_FOUND` guard is real, but it is in `test/CMakeLists.txt`, not in
the examples — the comment has attached a true fact about the *tests* to a false
claim about the *examples*.

**Replace lines 11-17 with:**

```
        # rapidjson is header-only, so the build step below is empty by
        # design; the install is the whole package.
        #
        # RAPIDJSON_BUILD_EXAMPLES=OFF is load-bearing, not cosmetic.
        # example/CMakeLists.txt builds fifteen target executables
        # unconditionally, and it sets -Werror (plus -Weverything under
        # Clang) on them; the top-level file also appends -march=native,
        # which every NDK wrapper except x86_64/i686 rejects outright. No
        # upstream switch other than this one can stop it, and AGENTS.md
        # forbids a patch, so the option stays off.
        #
        # RAPIDJSON_BUILD_DOC=OFF stops doc/'s doxygen requirement.
        # RAPIDJSON_BUILD_TESTS=OFF skips test/, which needs the
        # thirdparty/gtest submodule the tag archive does not carry.
```

Note also that `install(DIRECTORY example/ ...)` at `CMakeLists.txt:148-155` is
**unconditional** — the example *sources* land in
`$OUT/share/doc/RapidJSON/examples/` no matter what `RAPIDJSON_BUILD_EXAMPLES`
is set to. The comment above must not claim the examples vanish; they only stop
being compiled.

### 2. Nothing else is required

No flag changes. No `android.lua` is needed (nothing is compiled, so no target
fact can differ). `CMakeLists.txt:148-155` is upstream's install rule and must
be left alone.

## What the recipe otherwise does right

- `source.lua`: `v1.1.0` is genuinely the newest tag (I re-queried:
  `v1.1.0, v1.0.2, v1.0.1, v1.0.0`); the archive predates any newer release and
  upstream's post-1.1.0 work is on `master`/`v2.0.0_devel`, not in releases.
  URL 200, 1 019 402 B, top dir `rapidjson-1.1.0/`. Guarded download,
  `curl -C -` resume, `rm -rf src`, `mkdir -p $OUT/rapidjson`.
- `generic.lua` requires only `rapidjson@source`. Nothing missing, no `@native`
  need.
- Every build-system flag comes from `$CMAKE_FLAGS`. No `export`, no hardcoded
  architecture, triplet, API level, `-I` or `-L`. Serial build. Install into
  `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch,
  no `/dev/null`.
- `CMAKE_MINIMUM_REQUIRED(VERSION 2.8)` (`CMakeLists.txt:1`) is below cmake 4's
  floor, and the recipe leans on `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` from
  `$CMAKE_FLAGS` instead of hardcoding a floor — the right division of labour.
  Confirmed present in all three systems checked (`aarch64-android24:128`,
  `x86_64-mingw:69`, `clang-native:57`).
- `cmake --build` is genuinely empty (no `add_library` anywhere in
  `CMakeLists.txt`) and the recipe says so rather than pretending otherwise.
- `stage1.md` is accurate and, unusually, volunteers a side effect against its
  own package: `export(PACKAGE ${PROJECT_NAME})` at `CMakeLists.txt:160` writes
  into the user's cmake package registry (`~/.cmake/packages/RapidJSON`)
  unless `CMAKE_EXPORT_NO_PACKAGE_REGISTRY` is set. That is a write outside
  the nest caused by configuring this package, correctly flagged and
  correctly not silently worked around. It does not fail the build.

## Carried to the build

Expected under `$NESTDIR/<sys>/`:

| Artifact | The one check that proves it |
| --- | --- |
| `include/rapidjson/*.h` (e.g. `document.h`, `writer.h`) | `[ -f include/rapidjson/document.h ]` |
| `lib/pkgconfig/RapidJSON.pc` | `pkg-config --modversion RapidJSON` → `1.1.0` (note the capitalised module name; it is `PROJECT_NAME`, `CMakeLists.txt:12`) |
| `lib/cmake/RapidJSON/RapidJSONConfig.cmake`, `RapidJSONConfigVersion.cmake` | `[ -f lib/cmake/RapidJSON/RapidJSONConfig.cmake ]` |
| `share/doc/RapidJSON/readme.md` | `[ -f share/doc/RapidJSON/readme.md ]` |
| `share/doc/RapidJSON/examples/**` | expected and **unavoidable** — `install(DIRECTORY example/ ...)` at `CMakeLists.txt:148-155` is unconditional. Source files only; no binaries. |

**There is no library file** and there must not be one — rapidjson is
header-only and `CMakeLists.txt` has no `add_library`. A missing `lib/*.a` is
correct.

**Two system-specific notes for the builder:**

1. On `x86_64-mingw` there is **no `.pc`**: the pkg-config block is
   `IF (UNIX OR CYGWIN)` (`CMakeLists.txt:131-138`) and `UNIX` is unset. That
   is upstream's doing, not a failure.
2. On `x86_64-mingw` the CMake package config lands in
   `$OUT/cmake/RapidJSONConfig.cmake`, not `lib/cmake/...`
   (`CMakeLists.txt:102-103` sets `_CMAKE_INSTALL_DIR` to
   `${CMAKE_INSTALL_PREFIX}/cmake` for `WIN32`). The loader's staging-path
   rewrite only covers `$OUT/lib/pkgconfig/*.pc`, `$OUT/share/pkgconfig/*.pc`,
   `$OUT/lib/*.la` and `$OUT/{lib,share}/cmake/**` (`src/loader.lua:454-458`),
   so **that one file keeps its baked `$OUT` path on mingw**. It does not fail
   this build; it is a latent defect for the first `find_package(RapidJSON)`
   consumer on mingw. Record it; it is an emitter question, not a recipe one.

Rerun should print `skip ... (fresh)`.
