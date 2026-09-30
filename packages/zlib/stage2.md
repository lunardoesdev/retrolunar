ACCEPT

# zlib 1.3.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/zlib/`. I did not build.

## What the recipe gets right

- `-DZLIB_BUILD_EXAMPLES=OFF` with the comment "Only the library is used;
  examples cannot run on the build host" is exactly the reasoning AGENTS.md
  asks for: zlib's `examples/` builds `minigzip` and `example` as target
  programs, and the comment says why they are unwanted rather than just
  asserting it.
- `cmake -S . -B build $CMAKE_FLAGS` takes the install prefix, the cmake toolchain
  file and `-DCMAKE_POLICY_VERSION_MINIMUM` all from the system. Nothing is
  hardcoded to a target. `cmake --build build --parallel 1` is serial.
- `require("zlib@source")` names no missing package.

## Two facts the forecast must record, because other recipes depend on them

I verified both against the real tree, and both are load-bearing elsewhere in
this shard:

1. **The `.pc` file is installed to `share/pkgconfig`, not `lib/pkgconfig`.**
   `zlib`'s own `CMakeLists.txt:14` sets
   `INSTALL_PKGCONFIG_DIR = ${CMAKE_INSTALL_PREFIX}/share/pkgconfig` and
   `:194` installs `${ZLIB_PC}` there. So the artifact is
   `$OUT/share/pkgconfig/zlib.pc`.

   That is *inside* the loader's rewrite set (`src/loader.lua:454-458` covers
   `$OUT/share/pkgconfig/*.pc`), so the `$OUT`→`$PREFIX` fixup happens and
   `pkg-config` works. But a reviewer checking for `lib/pkgconfig/zlib.pc` will
   not find it and will report a phantom defect. `stage1.md` must say
   `share/pkgconfig`.

2. **On `x86_64-mingw` the archive is `libzlib.a`, not `libz.a`, and the
   `.pc` still says `-lz`.** `zlib`'s `CMakeLists.txt:170-172` only applies
   `OUTPUT_NAME z` inside `if(UNIX)`, and `CMAKE_SYSTEM_NAME Windows` leaves
   `UNIX` false. This is the name-mismatch trap AGENTS.md records; `libpng`
   already works around it by symlinking `libz.* → libzlib.*` in `$PREFIX`, and
   **`curl` walks straight into it** (see `packages/curl/stage2.md`, where
   `--with-zlib="$PREFIX"` puts `-lz` on the link line). The clean fix is in
   *this* recipe, not in the consumers: make the name consistent, or add the
   same symlink `libpng` uses. Worth raising here because zlib is the root of
   the problem.

## Non-blocking observation

zlib's CMake honours `BUILD_SHARED_LIBS`, which the recipe does not pass, so
zlib's default applies. In zlib 1.3.1's own CMakeLists that default is
**static** for the `zlibstatic` target, and the recipe has built, producing
`libz.a` — so the prefix is static as intended. Passing
`-DBUILD_SHARED_LIBS=OFF` explicitly would remove the dependence on an upstream
default, and is the same "do not depend on a default" discipline
`packages/zopfli` applies with `-DZOPFLI_BUILD_SHARED=OFF`. Optional.

## Carried to the build

- `lib/libz.a` — `llvm-objdump -f lib/libz.a | head -3` → `elf64-littleaarch64` (Android). On `x86_64-mingw` the name is `libzlib.a` — that is correct, not a defect.
- `include/zlib.h`, `include/zconf.h` — `[ -f include/zlib.h ] && [ -f include/zconf.h ]`.
- `share/pkgconfig/zlib.pc` — `pkg-config --modversion zlib` → `1.3.1`. **Note the directory: `share/pkgconfig`, not `lib/pkgconfig`.**
- `bin/minigzip` and `bin/example` must be **absent** — their presence means `-DZLIB_BUILD_EXAMPLES=OFF` did not take.
- The collision check that matters for this shard: `test -f include/zlib.h` is true, and `test -f include/zlib-ng.h` must be **false**. If both zlib and zlib-ng are installed in one prefix, see `packages/zlib-ng/stage2.md` — the hazard is duplicate `deflate`/`inflate` symbols, not a header clash.
- No `lib/libz.so*` unless `BUILD_SHARED_LIBS` is explicitly turned on.
