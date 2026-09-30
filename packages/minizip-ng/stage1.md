# minizip-ng build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.0.10 (git tag archive)
- Build system: CMake
- Installs: static `libminizip-ng.a`, the `minizip-ng/` headers, and
  `minizip-ng.pc`. No tools: the test programs, unit tests, fuzz targets and
  coverage instrumentation are all off.
- Requires: **six** packages, all present — `zlib-ng`, `zlib`, `bzip2`, `xz`,
  `zstd`, `openssl`. This is the most dependency-heavy recipe in the shard.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Two switches carry the design. `MZ_FETCH_LIBS=OFF` and `MZ_FORCE_FETCH_LIBS=OFF` together are the whole point (comment at `:12-14`): minizip-ng has no "prefer external" option, it has *fetch* options, so turning the fetching off is how this prefix's own libraries get used at all. Without them the build would download its own zlib, bzip2, zstd and OpenSSL mid-build — a network fetch and a host-compiled dependency in the middle of a cross build. `ZLIBNG_PREFER_EXTERNAL=ON` then points it at the `zlib-ng` in this tree. `MZ_BUILD_TESTS=OFF`, `MZ_BUILD_UNIT_TESTS=OFF`, `MZ_BUILD_FUZZ_TESTS=OFF` and `MZ_CODE_COVERAGE=OFF` remove four categories of host program. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The fetch switches are the important ones and they are off, so minizip-ng will use this tree's libraries. The open question is whether the mingw builds of zlib-ng, bzip2, xz, zstd and OpenSSL all present `.pc` files and import libraries that cmake can consume together; six cross-built dependencies is a lot of surface. `openssl` in particular is built for Android targets by its own recipe. What would settle it: the configure summary, which should list every backend as found. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None directly. The transitive dependency chain is where
the API level could matter, but every one of those six packages is itself
already building for all four Android API levels in this tree. The one to
watch is `zlib-ng`, which does more aggressive syscalls than zlib; it is
marked built in this tree, so it is fine. `armv7a-android*` and `i686-android*`
match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The `MZ_OPENSSL=ON` plus `MZ_PKCRYPT=ON` pair enables the *password
   crypto* backend**, and OpenSSL 3.x in this tree requires the provider
   machinery. The recipe lists `require("openssl")` so the dependency edge is
   declared, which is right — but a reviewer should confirm the resulting
   `libminizip-ng.a` links against *this* OpenSSL and not a system one. The
   `.pc`'s `Requires` is the place that will show it.
2. **`MZ_COMPAT=OFF` is a real API decision, commented at `:15-16`**: it is what
   stops minizip-ng renaming the library to `libminizip`. A consumer expecting
   the compat name will not find it. Correct for a fresh prefix, and worth
   keeping in mind as a deliberate break from upstream's compat mode.
3. **`MZ_WZA` at the end of the flag list — check it was not truncated.** The
   recipe's last switch is `-DMZ_WZA`, with no value. If the intended value was
   `=ON` or `=OFF`, an unvalued switch is a cmake warning or an ignored
   argument. **This is the one thing in this file I could not verify by reading
   and it should be checked against minizip-ng's `CMakeLists.txt` option list.**
   It is a typo-shaped defect, not a design question.
4. **The `.pc` carries six transitive requirements.** `pkg-config --static
   --libs minizip-ng` should name zlib-ng (or zlib), bzip2, lzma, zstd and
   libcrypto/libssl. A missing one is the consumer link failure this build
   cannot detect. This is the same latent class as lcms2, libarchive, libevent
   and libtiff — and this package has the most opportunities for it.
5. **Six `require()`s means six rebuilds upstream of it.** If `zstd` is bumped,
   this package rebuilds. That is correct behaviour, not a problem, but it
   makes this recipe sensitive to churn in packages outside its own shard.
6. `topackage.md` records this as built: *"static libminizip-ng.a;
   pkg-config --modversion minizip-ng reports 4.0.10"*. Consistent.
7. `cmake --build build --parallel 1` is correct (`:19`).

**How to verify once built.**

- `lib/libminizip-ng.a` exists; `include/minizip-ng/minizip-ng.h` exists.
- `lib/libminizip.a` must **not** exist — that would mean `MZ_COMPAT=OFF`
  regressed.
- `pkg-config --modversion minizip-ng` reports 4.0.10.
- `pkg-config --static --libs minizip-ng` must name **all** of the
  compression libraries and the crypto library. This is the most important
  check in this file.
- `$OBJDUMP -f lib/libminizip-ng.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm -u lib/libminizip-ng.a | grep -c 'zng_\|BZ2_\|lzma_\|ZSTD_\|SSL_'`
  non-zero, proving the backends really compiled in.
- `ls $OUT/bin/` must be empty — a `minizip-ng` test binary means one of the
  three test switches regressed.
- **Check the build log for any download step.** minizip-ng's fetch logic is
  loud; a `Downloading` or `FetchContent` line means the two `MZ_*FETCH_LIBS`
  switches did not take.
