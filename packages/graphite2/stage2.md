ACCEPT

# graphite2 review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, graphite2 1.3.15.
Verified against the real tarball (`tar tf` OK, 552 entries, top dir
**`graphite-1.3.15/`** — note the name, which is why `--strip-components=1`
matters), extracted to `/home/si/.revE/src/graphite-1.3.15`.

## 1. Is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
-DBUILD_TESTING=OFF` — every machine fact comes from `$CMAKE_FLAGS` and the
toolchain file it references. No hardcoded triplet/API/march, no `export` of
search flags. `cmake --build build --parallel 1` is explicit (load-bearing for
cmake, per AGENTS.md). `cmake --install build` with no `--prefix` override,
correct: `-DCMAKE_INSTALL_PREFIX=$OUT` is already in `$CMAKE_FLAGS`.

Note this package does **not** touch `$SYSDIR` directly — `$CMAKE_FLAGS`
carries `-DCMAKE_TOOLCHAIN_FILE=$SYSDIR/...`, which is the AGENTS.md pattern.

## 2. Is it doing what the package needs?

**cmake-only, and the option names are real.** `ls meson*` → nothing;
`CMakeLists.txt:12` `option(BUILD_SHARED_LIBS …, ON)` and `:13`
`option(BUILD_TESTING …, ON)` are the only two the recipe passes. Both are
genuine `option()` calls with those exact names. `BUILD_SHARED_LIBS` and
`BUILD_TESTING` are not graphite2-specific — they are cmake conventions — so
they would not appear in a `.cmake` include and their absence from any list is
expected.

**The "no FreeType" finding is correct, and I re-derived it.**
`grep -rn "freetype\|FreeType\|FT_" --include=CMakeLists.txt .` returns exactly
two hits, both in `tests/examples/CMakeLists.txt`: `:28 find_package(Freetype)`
and `:49 test_freetype(freetype …)`, with `test_freetype` itself guarded by
`if (${FREETYPE_FOUND})` at `:35`. That directory is reached only via
`CMakeLists.txt:87-88`:

```
if (BUILD_TESTING)
    add_subdirectory(tests)
endif()
```

So `-DBUILD_TESTING=OFF` removes the package's entire FreeType reference.
`packages/freetype` exists and is correctly **not** required. This is the
briefed claim inverted, and the adder is right.

**`-DBUILD_TESTING=OFF` is doing two jobs and both are load-bearing.**
`CMakeLists.txt:69-70`:

```
if (BUILD_TESTING AND BUILD_SHARED_LIBS)
    find_package(Python3 3.6 REQUIRED COMPONENTS Interpreter)
```

`REQUIRED` — a hard configure failure without a host interpreter. `:71-83` then
`execute_process`es that interpreter. So the switch is what keeps a host
toolchain out of the build. Note the condition is `AND BUILD_SHARED_LIBS`, so
with `-DBUILD_SHARED_LIBS=OFF` the Python probe is already skipped
independently — the two switches overlap here, and either alone suffices. The
recipe passes both, which is the belt-and-braces choice and matches the stated
reasoning.

**The `include(GetPrerequisites)` scare is genuinely harmless.**
`Graphite.cmake:3` is `include(GetPrerequisites)` and `find . -iname '*prereq*'`
returns nothing, so the file does not ship in the tarball. But `CMakeLists.txt:7`
sets `CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}`, and cmake's `include()` falls
back to `$CMAKE_ROOT/Modules/` for a bare name, where `GetPrerequisites.cmake`
ships. The adder probed this with cmake 4.4.3 and found `include()` succeeds
while `include(TotallyBogusModuleXYZ)` fails. I did not re-run that probe (it
would require configuring graphite2, which the brief forbids), but the
mechanism is standard cmake behaviour and the `if (${CMAKE_SYSTEM_NAME} STREQUAL
"Linux")` guard means it only fires on Linux-named system — which our
toolchain files set deliberately. Harmless, and correctly pre-empted in
`stage1.md` so no one wastes time on it.

**`GRAPHITE2_VM_TYPE` at its default resolves safely.**
`CMakeLists.txt:56-58` picks `direct` for a `Release` build type; `:62-64`
downgrades to `call` with a warning unless `CMAKE_COMPILER_IS_GNUCXX` or
`CMAKE_CXX_COMPILER_ID STREQUAL "Clang"`. `:8-10` defaults `CMAKE_BUILD_TYPE`
to `Release` when unset, and no system here sets it, so every system lands on
`direct`. mingw is GCC, clang-native is Clang — both accepted. Correct to leave
it alone.

**No host program is compiled and none is executed.** With `BUILD_TESTING=OFF`
the Python `execute_process` never runs. `doc/` builds nothing:
`doc/CMakeLists.txt` uses `find_program` for asciidoc/doxygen/latex and only
populates `DOC_DEPENDS` if found; the resulting `docs` target is not in `ALL`.
`gr2fonttest` **is** still installed (`gr2fonttest/CMakeLists.txt:23
install(TARGETS gr2fonttest EXPORT gr2fonttest RUNTIME DESTINATION bin)`) but
it is a *target* executable that is compiled and never executed, so it does not
violate the no-emulation rule. `stage1.md` risk 3 says exactly this and
explains why `-DGRAPHITE2_NFILEFACE=ON` is *not* used (it would compile out the
real `gr_make_file_face*` API — a genuine library feature loss). Correct
trade-off, correctly reasoned.

**API gates: none apply.** Pure C++11 (`CMakeLists.txt:15-16`), no libc surface
beyond the C runtime. Nothing in `src/` references `iconv_open`, `nl_langinfo`,
`mktime_z`, `posix_spawn`, `mblen`/`getpass`, `O_BINARY`, `POSIX_MADV_*` or
`process_vm_readv`.

## Corrections to `stage1.md` — one real artifact error

**`share/cmake/gr_2/*.cmake` is wrong; the export goes to `share/graphite2/`.**
`src/CMakeLists.txt:147`:

```
install(EXPORT graphite2 DESTINATION share/graphite2 NAMESPACE gr2_)
```

So the installed files are `share/graphite2/gr_2*.cmake`, not
`share/cmake/gr_2/`. This matters beyond cosmetics because the loader's `.pc` /
cmake-config rewrite (`src/loader.lua:454-468`) sweeps
`$OUT/lib/cmake/*.cmake`, `$OUT/lib/cmake/*/*.cmake`, `$OUT/share/cmake/*.cmake`
and `$OUT/share/cmake/*/*.cmake` — **it does not sweep `share/graphite2/`**.
cmake's `install(EXPORT)` emits `_IMPORT_PREFIX`-relative paths, so the export
is relocatable and needs no rewrite; that is why nothing breaks. But a builder
following `stage1.md`'s check would look in the wrong directory and could
report a false failure. Corrected below.

Other `stage1.md` corrections, minor:

- It cites the cmake version as 4.4.3 (its own probe) and the meson version as
  1.12.1 for other packages; the toolchain here has meson 1.12.0. No claim
  depends on it.
- The source-URL rationale (GitHub 404s, GitLab needs sign-in, Debian mirror
  byte-verified) is a reasonable call. I fetched the Debian tarball independently:
  13,698,237 bytes, `tar tf` OK, 552 entries. Matches its stated size exactly.

## Artifacts — what actually installs

From the real `CMakeLists.txt` / `src/CMakeLists.txt`:

- `lib/libgraphite2.a` — `src/CMakeLists.txt:146` `install(TARGETS graphite2 …
  ARCHIVE DESTINATION lib${LIB_SUFFIX})`, static via `-DBUILD_SHARED_LIBS=OFF`
- `include/graphite2/*.h` — same line, `PUBLIC_HEADER DESTINATION
  include/graphite2` (`GRAPHITE_HEADERS` at `src/CMakeLists.txt:80`)
- `lib/pkgconfig/graphite2.pc` — `CMakeLists.txt:98 configure_file` +
  `CMakeLists.txt:100 install(FILES … DESTINATION lib${LIB_SUFFIX}/pkgconfig)`
- `bin/gr2fonttest` — `gr2fonttest/CMakeLists.txt:23`
- `share/graphite2/gr_2*.cmake` — `src/CMakeLists.txt:147` (see correction above)

**`pkg-config --modversion graphite2` really does report `3.3.1`, not 1.3.15.**
`src/CMakeLists.txt:7-10` computes `GRAPHITE_VERSION` from the ABI triple
(3.3.1), and `CMakeLists.txt:94-100` feeds that to `configure_file` for
`graphite2.pc`, whose template uses `${version}`. This is upstream's doing, and
`stage1.md` risk 5 flags it explicitly so nobody "fixes" it. Verified — the
template is `Version: ${version}` with no reference to the project version.

## Forecast

I agree with **6 of 6**. All six rows are **WILL BUILD**.

The one branch the adder singles out as able to misfire is real and I checked
its consequence. `src/CMakeLists.txt:87` tests
`if (${CMAKE_SYSTEM_NAME} STREQUAL "Linux")`, and our toolchain files
deliberately set `CMAKE_SYSTEM_NAME` to `Linux`, so it **does** fire on Android.
It sets `LINKER_LANGUAGE C` and `LINK_FLAGS "-nodefaultlibs"` (`:88-91`). With
`-DBUILD_SHARED_LIBS=OFF` the target is a static archive, which has no link
step, so `LINK_FLAGS` and `LINKER_LANGUAGE` are inert. That is the correct
assessment, and it is the same `CMAKE_SYSTEM_NAME` fact AGENTS.md documents for
glog.

`x86_64-android35`'s extra `-mfpmath=sse -msse2` at `src/CMakeLists.txt:97`
is benign on x86_64, where SSE2 is baseline.

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libgraphite2.a"                 || echo "MISSING libgraphite2.a"
test -f "$OUT/include/graphite2/Font.h"          || echo "MISSING Font.h"
test -f "$OUT/lib/pkgconfig/graphite2.pc"        || echo "MISSING graphite2.pc"

# 2. static not shared, scoped by graphite2's own name so a sibling's .so
#    cannot satisfy it
find "$OUT/lib" -name 'libgraphite2.*' | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libgraphite2.so*' | wc -l           # expected 0

# 3. version reports 3.3.1, NOT 1.3.15. This is upstream's ABI-triple versioning
#    (src/CMakeLists.txt:7-10 feeding graphite2.pc at CMakeLists.txt:94).
#    Seeing 3.3.1 here is SUCCESS; seeing 1.3.15 would mean someone changed it.
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion graphite2

# 4. no $OUT left in the .pc — proves the loader rewrite ran
grep -c "$OUT" "$OUT/lib/pkgconfig/graphite2.pc"          # expected 0

# 5. THE FREETYPE CHECK. BUILD_TESTING=OFF must have removed the only
#    find_package(Freetype) in the tree. This is the direct check.
llvm-nm -u "$OUT/lib/libgraphite2.a" | grep -cw freetype    # expected 0
llvm-nm -u "$OUT/lib/libgraphite2.a" | grep -cw FT_         # expected 0

# 6. no host interpreter was required or run. If BUILD_TESTING had been on,
#    configure would have failed outright (REQUIRED) or logged this.
grep -c 'Could NOT find Python\|Could not find a package configuration file provided by "Python3"' \
     "$WORK/build/CMakeCache.txt"    # expected 0
grep -c 'Python3_EXECUTABLE' "$WORK/build/CMakeCache.txt"   # expected 0

# 7. the cmake export lands in share/graphite2/, NOT share/cmake/. stage1.md
#    says share/cmake/gr_2/*.cmake; that path does not exist.
test -d "$OUT/share/graphite2" && ls "$OUT/share/graphite2"   # expected gr_2*.cmake
test -d "$OUT/share/cmake" && echo "unexpected: share/cmake exists"

# 8. VM type resolved to direct (Release default + GCC/Clang)
grep -i 'vm machine type' "$WORK/build/CMakeCache.txt" || \
  grep -ri 'Using vm machine type' "$WORK/build/CMakeFiles/CMakeOutput.log" 2>/dev/null

# 9. gr2fonttest present and a target binary, never executed by the build
test -x "$OUT/bin/gr2fonttest" || echo "MISSING gr2fonttest"
$OBJDUMP -f "$OUT/bin/gr2fonttest" | head -3
$OBJDUMP -f "$OUT/lib/libgraphite2.a" | head -3
```

Note for check 6/8: `CMakeCache.txt` lives under `$WORK/build`, which the
loader's `trap` removes at block end — read or copy it during the block.