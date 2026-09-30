# msgpack-c build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 7.0.2 (git tag `c-7.0.2`)
- Build system: CMake
- Installs: static `libmsgpack-c.a` and `libmsgpack-cxx.a`, the `msgpack.h`
  and `msgpack/` headers, and `msgpack-c.pc` plus `msgpack-cxx.pc`. The other
  language implementations in the tree (C, Python, Ruby, …) are off.
- Requires: `msgpack-c@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `MSGPACK_ENABLE_CXX=ON` with `MSGPACK_ENABLE_C=OFF` (both at `generic.lua:9`) selects exactly one implementation — the C++ one, which is the modern default and what the backlog entry describes. `MSGPACK_BUILD_TESTS=OFF` and `MSGPACK_BUILD_BENCHMARKS=OFF` remove the test suite and the benchmark, both host programs. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. msgpack-cxx needs a working C++ standard library, which mingw's g++ provides. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. msgpack-cxx is a header-driven C++11 serialisation
library: it uses `malloc`, `memcpy` and standard containers, nothing
platform-specific. No API-gated symbol. `armv7a-android*` and `i686-android*`
match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **Two archives and two `.pc` files, but only one implementation is
   compiled.** With `MSGPACK_ENABLE_C=OFF` the C-only library should not be
   produced. Check that `libmsgpack-cxx.a` is the real payload and that no
   stray C-only archive appears — msgpack-c's CMake has historically emitted
   the C library as a side effect of the C++ one, so this is worth confirming
   rather than assuming.
2. **The package is a dependency of `msgpack` 5.x**, per the backlog.
   `topackage.md:159` records it as built: *"static libmsgpack-c.a,
   msgpack.h and msgpack/ headers; pkg-config --modversion msgpack-c reports
   7.0.2; archive members are elf64-littleaarch64."* Consistent with this
   recipe, and that archive-member string is a useful reference for the next
   build.
3. **A C++ library in a prefix that is otherwise mostly C.** Any consumer must
   link the C++ runtime. A `.pc` file normally does not add `-lstdc++`/`-lc++`
   — that is the consumer's job — but it surprises people. Worth a line in the
   package's `readme.md`.
4. **`BUILD_SHARED_LIBS=OFF` is the house convention** and correct.
5. `cmake --build build --parallel 1` is correct (`:10`).
6. `topackage.md` records this as built. Consistent.

**How to verify once built.**

- `lib/libmsgpack-cxx.a` exists; `include/msgpack.hpp` exists — that is the
  header that matters with `ENABLE_CXX=ON`.
- `pkg-config --modversion msgpack-c` reports 7.0.2.
- `$OBJDUMP -f lib/libmsgpack-cxx.a` prints `elf64-littleaarch64` on Android —
  the exact check `topackage.md:159` already recorded.
- `llvm-nm -C --defined-only lib/libmsgpack-cxx.a | grep -c 'msgpack::type::'`
  must be non-zero. This is the check that distinguishes the C++ build from the
  C one, and it is the one that catches risk 1.
- `ls $OUT/bin/` must be empty — no benchmark binary, no test program.
