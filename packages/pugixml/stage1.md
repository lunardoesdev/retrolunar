# pugixml build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.15 (git tag archive)
- Build system: CMake
- Installs: static `libpugixml.a`, `pugixml.hpp`, `pugixml.cpp`, `pugixml.pc`,
  and a CMake package config. No tools.
- Requires: `pugixml@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `PUGIXML_BUILD_TESTS=OFF` at `generic.lua:9` is the one switch that matters, and the comment at `:7-8` gives the full reason: the tests are a host program suite *and one of the cases fetches a document over the network*. That second half is the stronger justification — a cross build that ran a test suite would both violate the no-execution rule and depend on the network, which AGENTS.md:371-372 forbids outside `source.lua`'s curl. Nothing else is built, and pugixml itself is two files of portable C++ with no dependency beyond the standard library. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. pugixml is pure C++ with no platform layer — it does not even touch the filesystem unless a consumer passes a filename to `load_file`. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. `pugixml.cpp`/`pugixml.hpp` use `std::string`,
`std::vector` and `FILE*`; it is among the most portable libraries in the
shard. No API-gated symbol. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`pugixml.cpp` is installed as a source file, not just the header.** That
   is upstream's install rule and it is correct — a consumer compiles
   `pugixml.cpp` into their own binary rather than linking a prebuilt archive.
   But it means the `.pc` file's `Libs:` is empty and a consumer must add
   `pugixml.cpp` to their sources, which surprises people who expect
   `pkg-config --libs pugixml` to do something. Worth knowing, and worth a line
   in `readme.md` if it is not already there.
2. **A C++ library in a mostly-C prefix**, same note as msgpack-c: the consumer
   needs the C++ runtime on the link line, and the `.pc` will not say so.
3. **This is a C++11-era library built under a C++23-defaulting NDK clang.**
   `pugixml.cpp` is small and conservative, so the risk is low, but it is the
   same class of concern as LAME's (see the `lame` forecast, risk 5). Nothing
   in the recipe sets `-std=`, so it inherits the compiler default. Worth
   confirming on a real build.
4. **`BUILD_SHARED_LIBS=OFF` is the house convention** and correct.
5. `topackage.md:157` records this as built: *"static libpugixml.a;
   pkg-config --modversion pugixml reports 1.15; archive members are
   elf64-littleaarch64."* **Consistent, and note the "static libpugixml.a"
   wording matches the CMake build** — the archive contains the compiled
   `pugixml.cpp` objects even though the installed `.cpp` is also shipped for
   consumers who prefer to compile it themselves. Both are true; a reviewer
   should not be confused by the apparent duplication.
6. `cmake --build build --parallel 1` is correct (`:10`).

**How to verify once built.**

- `lib/libpugixml.a` exists; `include/pugixml.hpp` **and** `include/pugixml.cpp`
  exist — check both, since the `.cpp` is the easy one to forget.
- `pkg-config --modversion pugixml` reports 1.15.
- `$OBJDUMP -f lib/libpugixml.a` prints `elf64-littleaarch64` on Android — the
  exact check `topackage.md:157` recorded.
- `llvm-nm --defined-only lib/libpugixml.a | grep -cw 'pugi::Document'`
  non-zero (demangled), proving the archive has real C++ content.
- `pkg-config --libs pugixml` may well be empty; that is expected, not a bug
  (risk 1).
- `ls $OUT/bin/` must be empty — no test binary.
