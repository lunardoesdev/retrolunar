ACCEPT

# tbb review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, oneTBB 2023.1.0 (git tag
archive, `v2023.1.0.tar.gz`). Tarball verified with `tar tf` (1909 entries,
top dir `oneTBB-2023.1.0/`), extracted to
`/home/si/.revE/src2/oneTBB-2023.1.0`.

## 1. Is it using the SYSTEM?

Yes. `$CMAKE_FLAGS` carries the toolchain, `-DCMAKE_INSTALL_PREFIX=$OUT` and
`-DCMAKE_PREFIX_PATH=$PREFIX`; `$CC`/`$CFLAGS` come from the system setup.
No hardcoded triplet/API/march, no `export` of search flags, no `DESTDIR`, no
`sed`/patch. `cmake --build build --parallel 1` is explicit.

## 2. Is it doing what the package needs?

**Every option passed exists, with the stated defaults.** Verified in
`CMakeLists.txt`:

| option | line | default | recipe | correct? |
|---|---|---|---|---|
| `TBB_TEST` | 114 | `ON` | `OFF` | yes — load-bearing |
| `TBB_STRICT` | 116 | `ON` | `OFF` | yes |
| `TBB_ENABLE_IPO` | 125 | `ON` | `OFF` | yes |
| `TBB_EXAMPLES` | 115 | `OFF` | — | already off, correctly untouched |
| `TBB_FUZZ_TESTING` | 127 | `OFF` | — | already off |
| `TBB_INSTALL` | 128 | `ON` | — | left on, correct |

`BUILD_SHARED_LIBS` is a standard cmake option. No nonexistent flag.

**`TBB_TEST=OFF` is load-bearing.** `CMakeLists.txt:348-351`:

```
if (TBB_TEST)
    enable_testing()
    add_subdirectory(test)
endif()
```

That is the whole doctest suite, built as target executables. Off is right.

**`BUILD_SHARED_LIBS=OFF` does two jobs, both real.** `CMakeLists.txt:308-311`:

```
if (NOT BUILD_SHARED_LIBS)
    message(STATUS "TBBBind build targets are disabled due to unsupported environment")
else()
    add_subdirectory(src/tbbbind)
endif()
```

So static additionally drops tbbbind — one fewer thing to build, and the
message proves the branch fired. It also matches the static convention used by
every other package in this prefix.

**`TBB_STRICT=OFF` is the most valuable switch here.** `CMakeLists.txt:116`
defaults `TBB_STRICT` ON, and `cmake/compilers/Clang.cmake:58` turns that into
`-Werror`. oneTBB's own `SYSTEM_REQUIREMENTS.md:71-73` documents support up to
Clang 13 / GCC 12, and every compiler in this tree is far newer. `-Werror`
against a decade of new warnings would fail the build for reasons unrelated to
this prefix. The recipe's point that "the warning level itself is unchanged;
only `-Werror` is dropped" is the right distinction and I confirmed
`TBB_WARNING_LEVEL` is not touched.

**The IPO reasoning is right, and stronger than `stage1.md` states.**
The recipe claims `-DTBB_ENABLE_IPO=OFF` belongs in `generic.lua` rather than
an `android.lua` because the guard is defeated on every system. Verified:

```
CMakeLists.txt:275
if (TBB_ENABLE_IPO AND BUILD_SHARED_LIBS AND NOT ANDROID_PLATFORM AND NOT TBB_SANITIZE MATCHES "thread")
```

`ANDROID_PLATFORM` is referenced only at `:275` and `:378`, and is set by cmake
itself — but our toolchain files deliberately `set(CMAKE_SYSTEM_NAME Linux)`
(confirmed in `packages/aarch64-android24/*.cmake:3`), so `ANDROID_PLATFORM`
is never set on Android either. Upstream's own comment at `:272-273` says LTO
on Android trips an NDK bug (`argument unused during compilation:
'-Wa,--noexecstack'`).

**Note the guard also requires `BUILD_SHARED_LIBS`,** which the recipe sets
`OFF`. So with `-DBUILD_SHARED_LIBS=OFF` the IPO branch is already skipped on
*every* system, and `-DTBB_ENABLE_IPO=OFF` is belt-and-braces rather than
load-bearing. That does not change the verdict — the switch is harmless,
correctly explained, and defends the intent if the static decision ever
changes — but the recipe comment slightly oversells it as the thing that
disables IPO. Worth a sentence in a future edit, not a defect.

**So: no `android.lua`, and that judgement is correct.** IPO here is not an
Android-only switch; it is defeated by our `CMAKE_SYSTEM_NAME` choice on
Android and irrelevant elsewhere. Writing an `android.lua` to carry it would
duplicate a line whose reason is a toolchain fact, which AGENTS.md says belongs
in the system files.

**No host program is compiled and none is executed.** With `TBB_TEST=OFF` the
suite never enters. `hwloc` cannot leak in:
`cmake/hwloc_detection.cmake:58-71` is gated on
`TBB_DISABLE_HWLOC_AUTOMATIC_SEARCH`, which `CMakeLists.txt:124` defaults to
`${CMAKE_CROSSCOMPILING}` — true on every cross system here. On clang-native
the search does run, but that system sets `PKG_CONFIG_PATH=""` and hwloc is not
in the prefix, so it finds nothing. Correctly reasoned.

## Version and provenance

`v2023.1.0` is a real oneTBB tag and the archive is the release source (no
release *asset* exists upstream, so the tag archive is the tarball — the
source recipe says this and it is correct). 2023.1.0 is the current stable
line; 2022.x is the older LTS.

## Artifacts — what actually installs

With `TBB_INSTALL` left ON and static:

- `lib/libtbb.a`, `lib/libtbbmalloc.a`, `lib/libtbbmalloc_proxy.a`
- `include/oneapi/tbb/*.h`
- `lib/pkgconfig/tbb.pc` — from `integration/pkg-config/tbb.pc.in`. **Note the
  module name is `tbb`, matching the directory**, unlike `dpl` below.
- `share/doc/oneTBB/`

## Forecast

I agree with **6 of 6**. All six rows are WILL BUILD.

The reasoning that carries the forecast — static drops tbbbind, `TBB_TEST=OFF`
drops the doctest suite, `TBB_STRICT=OFF` removes the `-Werror` that a newer
compiler would trip, IPO is already inert, hwloc cannot leak — is all verified
above. Nothing in the recipe hardcodes a target fact, and nothing depends on an
API level: oneTBB is a threading library over `pthread_create`, which is
Bionic-native and available at every API level this tree ships.

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libtbb.a"            || echo "MISSING libtbb.a"
test -f "$OUT/lib/libtbbmalloc.a"     || echo "MISSING libtbbmalloc.a"
test -f "$OUT/lib/libtbbmalloc_proxy.a" || echo "MISSING libtbbmalloc_proxy.a"
test -d "$OUT/include/oneapi/tbb"     || echo "MISSING oneapi/tbb headers"
test -f "$OUT/lib/pkgconfig/tbb.pc"   || echo "MISSING tbb.pc"

# 2. static, not shared. Scoped by tbb's own library names.
find "$OUT/lib" -name 'libtbb.*' | grep -c '\.a$'          # expected 1
find "$OUT/lib" -name 'libtbb.so*' | wc -l                  # expected 0

# 3. pkg-config module name is "tbb" (integration/pkg-config/tbb.pc.in)
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion tbb

# 4. no $OUT left in the .pc — proves the loader rewrite ran
grep -c "$OUT" "$OUT/lib/pkgconfig/tbb.pc"                  # expected 0

# 5. THE THREE SWITCHES, each checked against a real file or log rather than
#    assumed. Read these while the block runs: $WORK is trap-removed at end.
grep -E 'TBBBind build targets are disabled' "$WORK/build/CMakeCache.txt" \
  || grep -rE 'TBBBind build targets are disabled' "$WORK/build" 2>/dev/null | head -1
# expected: the message, proving BUILD_SHARED_LIBS=OFF took the static branch

grep -E '^(TBB_TEST|TBB_STRICT|TBB_ENABLE_IPO|TBB_INSTALL):' "$WORK/build/CMakeCache.txt"
# expected: TBB_TEST=OFF, TBB_STRICT=OFF, TBB_ENABLE_IPO=OFF, TBB_INSTALL=ON

# 6. the test suite must NOT have been configured: no doctest binaries, and no
#    test/ in the build tree's subdirectory list
test -d "$WORK/build/test" && echo "REGRESSION: test/ was configured (TBB_TEST not off)"

# 7. -Werror must not be in the compile flags (TBB_STRICT=OFF)
grep -c 'Werror' "$WORK/build/src/tbb/CMakeFiles/tbb.dir/flags.make"   # expected 0

# 8. hwloc must not have been found
grep -ci 'hwloc' "$WORK/build/CMakeCache.txt"    # expected 0

# 9. ELF machine per family; and pthread must resolve from libc, not a
#    separate library (Bionic has no libpthread)
$OBJDUMP -f "$OUT/lib/libtbb.a" | head -3
llvm-nm -u "$OUT/lib/libtbb.a" | grep -cw pthread_create    # expected >=1
find "$OUT/lib" -name 'libpthread*' | wc -l                   # expected 0
```