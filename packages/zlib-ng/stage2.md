ACCEPT

# zlib-ng 2.2.4 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/zlib-ng/`. I did not build.

**Adder A's finding #6 is CORRECT**, and I nearly rejected this package on the
opposite conclusion before checking properly. My first read of
`CMakeLists.txt:1314` saw `install(FILES ${CMAKE_CURRENT_BINARY_DIR}/zlib${SUFFIX}.h ...)`
and assumed `SUFFIX` was empty. It is not:

```
CMakeLists.txt:155:    set(SUFFIX "")        # ZLIB_COMPAT  -> zlib.h,  libz.a,    zlib.pc
CMakeLists.txt:159:    set(SUFFIX "-ng")     # native mode  -> zlib-ng.h, libz-ng.a, zlib-ng.pc
```

So with `ZLIB_COMPAT=OFF` the package installs `zlib-ng.h`, `zconf-ng.h`,
`zlib-ng.pc` and `libz-ng.a` — **not** `zlib.h`. `stage1.md`'s verification
instruction is right, and adder A's claim that `ZLIB_COMPAT=OFF` "does not
install `zlib.h`" is right.

## What the recipe gets right

- `-DZLIB_ENABLE_TESTS=OFF` is a real option (`CMakeLists.txt:80`, `option(...
  "Build test binaries" ON)`) and defaults **ON**, so it is load-bearing, not
  decorative. `stage1.md` risk 2 asks for that to be verified; it is.
- `-DBUILD_SHARED_LIBS=OFF` gives `libz-ng.a` and is the static control the
  rest of the tree uses. `cmake --build build --parallel 1` is serial, and
  install goes to `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- No host programs: the test binaries are off, and the recipe comment names
  `minizip-ng` as host-side. `stage1.md` risk 2 correctly notes that
  `packages/minizip-ng` exists in this tree and that the flag is what stops
  zlib-ng building against it — worth keeping in the reviewer's head.
- The API-level analysis is sound and the conclusion right: zlib-ng reaches
  only `mmap`/`open`/`read`/`write`/`close`/`stat`/`gettimeofday`, and in
  particular it does **not** use `mktime_z` (API 35) or `nl_langinfo` (API 26),
  so the level is inert.
- `require("zlib-ng@source")` names no missing package.

## The decision `stage1.md` asks for — my ruling

`stage1.md:26-35` correctly asks which package is the compatibility provider.
There is **no header collision**: zlib installs `zlib.h` + `zconf.h`, zlib-ng
installs `zlib-ng.h` + `zconf-ng.h` (the `-ng` SUFFIX applies to all three
names at `CMakeLists.txt:1204`, `:1314-1319`, `:1281`). Both coexist cleanly
in `include/`.

The real hazard is different and sharper than the forecast states: **zlib-ng's
native mode still exports the unprefixed zlib symbol names** (`deflate`,
`inflate`, `crc32`, `adler32`) — that is the whole point of "built native so
callers get the zlib API". So `libz.a` and `libz-ng.a` both define them. A
consumer that pulls in both — which `libpng`, `curl` and `freetype` all do via
`pkg-config` — gets duplicate definitions at link time.

So the decision is: **one of them, not both, in a given system prefix.** My
recommendation is that `zlib-ng` should not be installed alongside `zlib`
unless a consumer explicitly asks for it, because every existing consumer in
this tree already resolves `zlib` through `pkg-config --libs zlib`. That is a
tree-level decision, not a change to this recipe, which is correct as written
and documents its choice. I record it here so it is not left implicit.

## Carried to the build

- `lib/libz-ng.a` — `llvm-objdump -f lib/libz-ng.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/zlib-ng.h`, `include/zconf-ng.h` — `[ -f include/zlib-ng.h ] && [ -f include/zconf-ng.h ]`.
- `lib/pkgconfig/zlib-ng.pc` — `pkg-config --modversion zlib-ng` → `2.2.4`. Note the name: **`zlib-ng`, not `zlib`**, which `stage1.md` risk 3 flags correctly.
- `llvm-nm --defined-only lib/libz-ng.a | grep -cE 'deflate|inflate|crc32'` → non-zero, proving the zlib API really is exported and that the duplicate-symbol hazard is real.
- `include/zlib.h` from *this package* must be **absent** — its presence means `ZLIB_COMPAT=OFF` did not take. (`include/zlib.h` from `packages/zlib` should be present; tell them apart by which build order ran.)
- `find $PREFIX/lib -name '*.so*'` → **empty**.
- No test binary anywhere under `$OUT`; `ZLIB_ENABLE_TESTS` defaults ON, so their absence is the proof the switch took.
