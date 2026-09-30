ACCEPT

# nlohmann-json — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- `-DJSON_BuildTests=OFF` is the correct spelling of upstream's option
  (note the capital `B` in `BuildTests`, which is easy to get wrong) and turns
  off the test tree.

## What the forecast should add

nlohmann-json is **header-only**. There is no compiled library and no `.pc`
consumer in the usual sense — the install is headers plus a cmake package
config. The forecast should say so plainly, because "no `lib/` artifact"
would otherwise look like a failed install. `AGENTS.md:449-457` rewrites
`$OUT/lib/cmake/*.cmake` paths to `$PREFIX`, so the installed config is
usable by a later `find_package`.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/include/nlohmann/json.hpp` | `test -f $PREFIX/include/nlohmann/json.hpp` |
| `$PREFIX/include/nlohmann/` populated | `ls $PREFIX/include/nlohmann \| wc -l` |
| cmake package config, paths rewritten | `find $PREFIX -name "nlohmann_jsonConfig.cmake"` non-empty, and `grep -c $OUT` in it → 0, proving the loader's rewrite ran |
| **no library is expected** | `ls $PREFIX/lib/libnlohmann*` → absent, and that is correct for a header-only package |
