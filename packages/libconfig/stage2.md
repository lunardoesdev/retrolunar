ACCEPT

# libconfig — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job, per `AGENTS.md:226-229`.
- `cmake -S . -B build $CMAKE_FLAGS` takes every toolchain fact from the
  system: `$CMAKE_FLAGS` already carries `-DCMAKE_TOOLCHAIN_FILE`,
  `-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
  `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`, the `CMAKE_MAKE_PROGRAM`
  pin, the policy floor and `-DTHREADS_PREFER_PTHREAD_FLAG=ON`
  (`packages/aarch64-android24/generic.lua:111-134`). Nothing is re-specified.
- No `sed`, no patch, no `/dev/null`, **no `DESTDIR`** — the install step is
  plain `cmake --install build`, which is correct because `$CMAKE_FLAGS`
  already sets `CMAKE_INSTALL_PREFIX=$OUT` (`AGENTS.md:237-238`).
- The build switches at `generic.lua` are upstream's own names and correctly
  turn off exactly the host-program and test targets that `make` would
  otherwise descend into: `-DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF`.
- No `export` of `CPPFLAGS`/`LDFLAGS`/`CFLAGS`, no hardcoded
  `--host`/`--prefix`, nothing that duplicates what a system file should own.

## What the forecast should add

Nothing blocking. The forecast should state the exact artifact names, because
upstream naming is inconsistent across these projects and a reviewer otherwise
has to guess whether to expect `libfoo.so` or `libfoo-foo.so.2` — this tree
builds static, so the `.a` form is what should appear.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libconfig.a` | `ls $PREFIX/lib/libconfig.a` — a static archive, confirming the shared build is off |
| `$PREFIX/include/libconfig.h++` | `test -f $PREFIX/include/libconfig.h++` |
| `/lib/pkgconfig/libconfig.pc` | `pkg-config --modversion libconfig` |
| static, not shared | `find /lib -name 'libconfig.a' -o -name 'libconfig.a.so*'` → only the `.a` |
| no host programs installed | `find /bin -newer /lib/libconfig.a` → empty on a fresh prefix
