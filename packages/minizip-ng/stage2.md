ACCEPT

# minizip-ng — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- **`-DMZ_FETCH_LIBS=OFF -DMZ_FORCE_FETCH_LIBS=OFF` is the most important line
  here.** minizip-ng otherwise downloads its dependencies at configure time.
  `AGENTS.md:371-372` forbids network access at build time except `curl` in
  `source.lua`, so without these two flags the build would attempt a network
  fetch. Turning them off and supplying the libraries via
  `require("xz") require("zstd") require("openssl")` plus
  `-DZLIBNG_PREFER_EXTERNAL=ON` is exactly right.
- `-DMZ_BUILD_TESTS=OFF -DMZ_BUILD_UNIT_TESTS=OFF -DMZ_BUILD_FUZZ_TESTS=OFF
  -DMZ_CODE_COVERAGE=OFF` turn off every test tree; `-DMZ_OPENSSL=ON
  -DMZ_BZIP=ON -DMZ_LZMA=ON -DMZ_ZSTD=ON -DMZ_PKCRYPT=ON -DMZ_WZAES=ON
  -DMZ_ICONV=OFF -DMZ_COMPAT=OFF` names only dependencies this tree has.

## What the forecast should add

`-DMZ_BZIP=ON` is worth calling out: it needs bzip2, which is **not** in this
recipe's `require` list, unlike `xz`, `zstd` and `openssl`. Either bzip2
comes in transitively via zlib (`-DZLIBNG_PREFER_EXTERNAL=ON`), or the flag
will fail to find libbz2. The forecast should state which, and if it is
transitive, note that `packages/zlib`'s presence is now load-bearing for a
package that does not require it directly.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libminizip-ng.a` (or `-lib.a`) | `ls $PREFIX/lib/libminizip*` — static, confirming `-DBUILD_SHARED_LIBS=OFF` |
| `$PREFIX/include/minizip-ng/minizip.h` | `test -f $PREFIX/include/minizip-ng/minizip.h` — note the hyphenated directory |
| `$PREFIX/lib/pkgconfig/libminizip-ng.pc` | `pkg-config --modversion libminizip-ng` — note the **hyphen**, not `libminizip` |
| **no network at build time** | the build log must contain no `Downloading` / `git clone` / `curl` line — that is the `-DMZ_FETCH_LIBS=OFF` check |
| openssl really linked | `llvm-nm --undefined-only $PREFIX/lib/libminizip*.a \| grep -c SSL_` → non-zero |
