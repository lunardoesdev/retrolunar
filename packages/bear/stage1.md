# stage1 — bear 3.1.6 (build forecast)

## BLOCKER: this package cannot build, and the reason is structural

bear's only route to its mandatory gRPC dependency is a **build-time
`git clone`**, which AGENTS.md forbids: "No `jj`/`git` commands inside
recipes; no network access at build time except `curl` in `source.lua`
fetch blocks."

There is no flag that avoids it. Both branches of the check fail here:

- `third_party/grpc/CMakeLists.txt:1-3` first tries the system:
  `pkg_check_modules(gRPC protobuf>=3.11 grpc++>=1.26)`. This repo has
  `packages/protobuf` but **no `packages/grpc`**, so `gRPC_FOUND` is false.
- `:7-21` then requires `find_program(PROTOC protoc)` and
  `find_program(GRPC_CPP_PLUGIN grpc_cpp_plugin)`, each a
  `FATAL_ERROR` when absent. Neither is in this repo.
- `:27-43` falls through to `ExternalProject_Add(grpc_dependency
  GIT_REPOSITORY https://github.com/grpc/grpc GIT_TAG v1.49.2 GIT_SUBMODULES
  GIT_SHALLOW 1)`. That is the build-time clone, and it is unconditional
  once the two checks above fail.

`source/CMakeLists.txt:30` states the requirement outright:
`pkg_check_modules(gRPC REQUIRED IMPORTED_TARGET protobuf grpc++)`. The
inner project cannot be configured at all without it.

Adding gRPC to this repo would be a separate package, outside this adder's
scope. Per AGENTS.md the failure text is the deliverable, so the recipe and
this forecast are written down and the blocker recorded rather than worked
around.

## Native vs target

**Classified NATIVE, and it has to be.** bear is a compiler adapter: it
`LD_PRELOAD`s an interposer (`source/libsys`, `source/intercept`) onto the
host compiler and linker driver to record what was compiled. It must run on
the machine doing the build. `source/CMakeLists.txt:37-39` gates
`SUPPORT_PRELOAD` on `UNIX AND NOT APPLE`, so the design assumes a
`LD_PRELOAD`-capable host.

So `packages/bear/` contains `source.lua`, `clang-native.lua` and this
file, and **deliberately no `generic.lua`** — a cross-built bear could
never intercept anything here, and running a target binary is forbidden
outright.

Because the package is native-only, the six target rows below are all the
same refusal, and the clang-native row carries the real blocker.

## What the artifacts are

bear publishes source. Verified download: 170897 bytes, matching the server
`content-length`, `tar tf` lists 417 entries, top-level `rizsotto-Bear-*/`.
This is the CMake project, not a binary drop — but note it is the
**rizsotto/Bear 3.1.6** lineage, the predecessor of `sbear`
(`rizig/sbear`), which the proxy in this environment blocks (every request
to `github.com/rizig/sbear` returns 404 here, including
`codeload`, `raw.githubusercontent`, and the releases asset listing — and the
same 404 comes back for `github.com/bminor/bash`, a repository that
demonstrably exists, so this is an egress filter, **not** evidence that
sbear is missing upstream). `rizig/sbear` is the more actively maintained
successor and is the version most projects mean by "bear" today; that
should be revisited once the proxy can reach it.

## Build facts

| | |
|---|---|
| Build system | CMake superbuild, `cmake_minimum_required(VERSION 3.12)` (CMakeLists.txt:1) |
| Generated `configure` | n/a — not autotools; no `configure`, `aclocal.m4`, `Makefile.in` or `config.h.in` in the tree |
| Config template | n/a for autotools; `source/config.h.in` is fed by `configure_file` (source/CMakeLists.txt:76) |
| Mandatory deps | **gRPC (grpc++ >= 1.26), protobuf >= 3.11, protoc, grpc_cpp_plugin** — none satisfiable here |
| Optional deps | nlohmann_json, fmt, spdlog (present in this repo); googletest (tests only) |

## Verdicts

| System family | Verdict | Basis |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | Native-only by design (no `generic.lua`): bear is an `LD_PRELOAD` compiler adapter and must run on the build host. Even ignoring that, the gRPC clone blocker applies. |
| aarch64-android24 | WILL NOT BUILD | Same. |
| aarch64-android35 | WILL NOT BUILD | Same. |
| x86_64-android35 | WILL NOT BUILD | Same. |
| x86_64-mingw | WILL NOT BUILD | Same; additionally `source/CMakeLists.txt:37-39` gates `SUPPORT_PRELOAD` on `UNIX AND NOT APPLE`, so the interception mechanism is not even compiled for a mingw target. |
| clang-native | **WILL NOT BUILD** | The gRPC clone. `third_party/grpc/CMakeLists.txt:27-43` is the only path to `grpc_dependency`, `source/CMakeLists.txt:30` marks it REQUIRED, and `packages/grpc` does not exist. |

`armv7a-*` and `i686-*` behave like `aarch64-android*` here.

## Notes for the reviewer

- `-DENABLE_UNIT_TESTS=OFF -DENABLE_FUNC_TESTS=OFF` are both real options
  (CMakeLists.txt:15-16, both default ON). They matter independently of
  the gRPC blocker: the superbuild runs `TEST_BEFORE_INSTALL 1` with
  `TEST_COMMAND ctest` (`:88-92`, `:107-111`), which would execute target
  binaries, and ctest is not something a cross build can do here at all.
- Every flag comes from `$CMAKE_FLAGS`; the two `-D` options are
  package-local build decisions, not target facts.
- Build never fans out: `cmake --build build --parallel 1`.
- To unblock: add gRPC (and protoc) as packages first, then revisit. That
  is outside this adder's five-package scope.