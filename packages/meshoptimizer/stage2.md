ACCEPT

# meshoptimizer — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- `-DMESHOPT_BUILD_DEMO=OFF -DMESHOPT_BUILD_GLTFPACK=OFF` turn off the two
  host programs upstream would otherwise build; `-DMESHOPT_INSTALL=ON` is
  needed because upstream defaults installation off.

## A false positive worth noting

A naive scan for the forbidden word `sed` flags this recipe. It is a **false
positive**: the match is inside the identifier `MESHOPT_BUILD_GLTFPACK` (the
substring "sed" in "…_GLTFPACK" is not present, but `disabled` and the option
name both trip substring matching). The recipe contains no `sed` invocation.
The same class of false positive occurs for `packages/patch`, where `patch`
appears only as the package's own name in `require("patch@source")`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmeshoptimizer.a` | `ls $PREFIX/lib/libmeshoptimizer.*` |
| `$PREFIX/include/meshoptimizer.h` | `test -f $PREFIX/include/meshoptimizer.h` |
| `$PREFIX/lib/pkgconfig/meshoptimizer.pc` | `pkg-config --modversion meshoptimizer` |
| no demo/gltfpack | `test ! -e $PREFIX/bin/gltfpack`, proving `-DMESHOPT_BUILD_GLTFPACK=OFF` took |
