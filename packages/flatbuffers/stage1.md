# flatbuffers build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 25.2.10
- Build system: cmake
- Installs: `lib/libflatbuffers.a` (static); `include/flatbuffers/*.h`; `lib/pkgconfig/flatbuffers.pc`; `bin/flatc` (the schema compiler); `lib/cmake/flatbuffers/FlatBuffersConfig.cmake`
- Requires: `flatbuffers@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The C++ library is C++11 and uses the standard library plus `<cstring>`/`<cstdio>`; `FLATBUFFERS_BUILD_TESTS=OFF` and `FLATBUFFERS_BUILD_GRPCTEST=OFF` (`generic.lua:9`) remove both the gtest suite and the gRPC dependency, which is the only part of flatbuffers that reaches for anything platform-specific. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | flatbuffers' C++ is arch-neutral; the generated accessors are plain struct manipulation. |
| x86_64-mingw | WILL BUILD | `FLATBUFFERS_BUILD_SHAREDLIB=OFF` (`generic.lua:9`) removes the `__declspec(dllimport)` question, and the library itself is portable C++. |
| clang-native | WILL BUILD | Native; topackage.md:166 records FlatBuffers 25.2.10 as `[x]` with `pkg-config --modversion flatbuffers` = 25.2.10 and `elf64-littleaarch64` archive members. |

## API level notes

Not a variable. The C++ library is standard-library-only once the tests
and gRPC are off, which the recipe does.

## Risks / what a reviewer should check

- **`flatc` is a target binary that is never run here**, and topackage.md:166
  says so explicitly: "flatc is built for the target and never run here;
  generate code with a host flatc". That is the right call, and the recipe
  comment at `generic.lua:6-8` gives the reason: without `flatc` a consumer
  cannot turn a `.fbs` schema into headers. So `flatc` earns its place
  despite being a program — a rare and defensible exception.
- **The consequence deserves stating in the readme:** a *consumer*
  building on an Android target also cannot run `flatc`; it must generate
  its headers on the build host and ship them. Otherwise the `flatc` in the
  target prefix is dead weight.
- **`FLATBUFFERS_BUILD_FLATC` is not set**, so `flatc` is on because it is
  the default. If a future version changes that default, `flatc` silently
  disappears and consumers lose the ability to generate code. Setting it
  explicitly would pin the intent.
- **`FLATBUFFERS_INSTALL=ON`** (`generic.lua:9`) is set explicitly, which is
  the right instinct — some flatbuffers versions default it off when built
  as a subproject.
- **The `lib/cmake/flatbuffers/FlatBuffersConfig.cmake` is subject to the
  same `$OUT`→`$PREFIX` rewrite risk** documented in
  `packages/cjson/stage1.md`: a loader-glob change would break a consumer's
  `find_package`, not this build.

## How to verify once built

- `lib/libflatbuffers.a`
- `include/flatbuffers/flatbuffers.h`
- `lib/pkgconfig/flatbuffers.pc` and `pkg-config --modversion flatbuffers` → `25.2.10`
- `readelf -h lib/libflatbuffers.a` → `Machine: AArch64` on Android targets
- `bin/flatc` present, and `file bin/flatc` shows a *target* ELF (do not
  run it here)
