ACCEPT

# nanopb — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- `-Dnanopb_BUILD_GENERATOR=OFF` is the important one: nanopb ships a Python
  **code generator**, and leaving it on would need a target or host Python at
  build time. Turning it off matches what the other pure-Python entries here
  do, though for the opposite reason (this one is C, not Python).
- `-DBUILD_STATIC_LIBS=ON -DBUILD_SHARED_LIBS=OFF` pins static.

## What the forecast should add

`-Dnanopb_BUILD_GENERATOR=OFF` means **no `.pb.c`/`.pb.h` are generated**.
nanopb is fundamentally a generator-plus-runtime library: consumers normally
run `nanopb_generator.py` on their own `.proto` at *their* build time. So the
installed package is the runtime only, and the forecast should say so — a
consumer expecting `nanopb_generator.py` in `$PREFIX/bin` will not find it,
and that is a deliberate choice rather than a missing file.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libnanopb.a` | `ls $PREFIX/lib/libnanopb.*` — static |
| `$PREFIX/include/nanopb/nanopb.h` | `test -f $PREFIX/include/nanopb/nanopb.h` |
| `$PREFIX/lib/pkgconfig/nanopb.pc` | `pkg-config --modversion nanopb` |
| **no generator installed** | `find $PREFIX -name "nanopb_generator.py"` → absent, proving `-Dnanopb_BUILD_GENERATOR=OFF` took |
