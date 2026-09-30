ACCEPT

# msgpack-c — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- **`-DMSGPACK_ENABLE_CXX=ON -DMSGPACK_ENABLE_C=OFF`** is a deliberate,
  correct choice: this tree's consumers are C++ (see `require("msgpack-c")`
  usage elsewhere), and the C++ binding is the one with the `std::` types
  consumers want. It is a package decision, not a target fact, so it belongs
  in `generic.lua` — which is where it is.
- `-DMSGPACK_BUILD_TESTS=OFF -DMSGPACK_BUILD_BENCHMARKS=OFF` turn off the test
  and benchmark trees, which is what keeps `make all` from compiling host
  programs.
- `-DBUILD_SHARED_LIBS=OFF` gives the static archive.

## What the forecast should add

With `-DMSGPACK_ENABLE_C=OFF`, the C API is **not** installed. Any C consumer
would fail to compile against it. The forecast should say this explicitly,
because msgpack-c is commonly consumed from C and the missing
`msgpack/pack.h` C header set looks like a broken install if nobody said so.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmsgpackc.a` | `ls $PREFIX/lib/libmsgpackc.*` — static |
| `$PREFIX/include/msgpack.hpp` (C++ only) | `test -f $PREFIX/include/msgpack.hpp`; `test ! -f $PREFIX/include/msgpack.h` proves `-DMSGPACK_ENABLE_C=OFF` took |
| `$PREFIX/lib/pkgconfig/msgpack.pc` | `pkg-config --modversion msgpack` |
