ACCEPT

# flatbuffers 25.2.10 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/flatbuffers/`. I did not build.

## What the recipe gets right

- **Every option name is spelled exactly as upstream spells it**, which is
  where cmake recipes usually go wrong. Verified in
  `nest/source/flatbuffers/CMakeLists.txt`: it is
  `FLATBUFFERS_BUILD_SHAREDLIB` (not `BUILD_SHARED_LIBS`),
  `FLATBUFFERS_INSTALL`, `FLATBUFFERS_BUILD_TESTS`,
  `FLATBUFFERS_BUILD_GRPCTEST`, and `FLATBUFFERS_BUILD_FLATC` (line 20). A
  recipe that guessed `-DBUILD_SHARED_LIBS=OFF` would silently produce a shared
  library; this one does not.
- `-DFLATBUFFERS_BUILD_TESTS=OFF` is the switch that matters: it **defaults
  ON**, and it is what pulls in GoogleTest and the gRPC test tree. Turning it
  off is the right cut, and `FLATBUFFERS_BUILD_GRPCTEST=OFF` closes the
  adjacent door.
- `flatc` is deliberately kept, and the recipe comment gives the reason: it is
  a target program, but without it a consumer cannot generate its own headers
  from a `.fbs` schema, so the prefix would be incomplete. That is the same
  judgement `topackage.md` records for `flatc`, and it is right.
- `cmake --build build --parallel 1` is serial, install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("flatbuffers@source")` names no missing package.

## One coupling worth knowing about

`CMakeLists.txt:84` reads `if(NOT FLATBUFFERS_BUILD_FLATC AND FLATBUFFERS_BUILD_TESTS)`.
So the tests option is guarded by `flatc` being *on*. The recipe leaves
`FLATBUFFERS_BUILD_FLATC` at its default (on) and sets
`FLATBUFFERS_BUILD_TESTS=OFF`, which is the combination that works. Had the
recipe disabled `flatc` as well, the intent would still hold but the upstream
error path would change. Worth a half-line in the comment so a future edit
turning off `flatc` knows the two options are coupled — it is the kind of
upstream interaction that turns into a configure failure with a confusing
message.

## Carried to the build

- `lib/libflatbuffers.a` — `llvm-objdump -f lib/libflatbuffers.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libflatbuffers.so*` means `-DFLATBUFFERS_BUILD_SHAREDLIB=OFF` did not take.
- `include/flatbuffers/flatbuffers.h`, `include/flatbuffers/idl.h` — `[ -f include/flatbuffers/flatbuffers.h ] && [ -f include/flatbuffers/idl.h ]`.
- `lib/pkgconfig/flatbuffers.pc` — `pkg-config --modversion flatbuffers` → `25.2.10`.
- `bin/flatc` — `[ -x bin/flatc ]`, and it **must** be present: it is the reason the recipe does not disable programs. It is a target binary, so **never run it** — the builder generates `.fbs` headers on the *host*, as the backlog line for flatbuffers already says.
- `lib/cmake/flatbuffers/FlatBuffersConfig.cmake` and `lib/cmake/flatbuffers/FlatcConfig.cmake` — both present, and they are separate because `flatc` is a separate target.
- No test or gRPC-test binary anywhere under `$OUT`; their presence would mean `-DFLATBUFFERS_BUILD_TESTS=OFF` did not take, and would also mean GoogleTest was configured into a cross build.
