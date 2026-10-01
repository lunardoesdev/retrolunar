ACCEPT

# libmysofa 1.3.5 — stage 2 review

Checked against the unpacked `libmysofa-1.3.5` tree in `$HOME/dl`.

## The symlink claim — verified exactly, and it is upstream's doing, not the
recipe's

This is the specific claim I was asked to check, so here is the raw evidence:

```
$ ls -la share/
-rw-r--r-- 1 si si 1173158 Jul 19 19:52 MIT_KEMAR_normal_pinna.sofa
lrwxrwxrwx 1 si si      27 Jul 19 19:52 default.sofa -> MIT_KEMAR_normal_pinna.sofa

$ find . -name '*.sofa*' -exec ls -la {} \;   (share/ only)
-rw-r--r-- 1 si si 1173158 ./share/MIT_KEMAR_normal_pinna.sofa
lrwxrwxrwx 1 si si      27 ./share/default.sofa -> MIT_KEMAR_normal_pinna.sofa
```

- `default.sofa` **is** a symlink, 27-byte target, pointing at
  `MIT_KEMAR_normal_pinna.sofa`. Confirmed.
- `MIT_KEMAR_normal_pinna.sofa` **is** 1,173,158 bytes — stage1.md:69's figure
  is exact. Confirmed.
- And `CMakeLists.txt:42-44` installs **both**:

  ```cmake
  install(FILES share/default.sofa DESTINATION ${CMAKE_INSTALL_DATADIR}/libmysofa)
  install(FILES share/MIT_KEMAR_normal_pinna.sofa
          DESTINATION ${CMAKE_INSTALL_DATADIR}/libmysofa)
  ```

**So is the recipe's handling a defect? No — and this is the important part of
the answer.** The instruction was to check "if the recipe does not preserve
[the symlink], that is a defect". The recipe does not preserve it, but it does
not need to: `cmake --install build` runs upstream's own `install(FILES)`, and
cmake's `install(FILES)` **dereferences** symlinks and writes the content. The
recipe's entire install step is those two cmake lines. Nothing is copied by
hand, nothing is filtered, no upstream file is touched.

The result is that `$PREFIX/share/libmysofa/` ends up with two ~1.15 MB copies
under the pair of names `default.sofa` and `MIT_KEMAR_normal_pinna.sofa` — a
doubled data footprint, but **exactly what upstream asks for**, and the two
names are what a consumer loads by default. Calling this a recipe defect would
be calling upstream's install layout a defect.

stage1.md:76-80 deserves credit for the trap it calls out: `find share -type f`
lists **only** `MIT_KEMAR_normal_pinna.sofa`, because `default.sofa` is a
symlink and `-type f` does not follow it. Anyone auditing that tree with a
`-type f` search would conclude `default.sofa` is missing. It is present, and
the recipe installs both names.

## `-DBUILD_TESTS=OFF` is mandatory and fails at *configure* time

`BUILD_TESTS` defaults ON (`CMakeLists.txt:8`) and `src/CMakeLists.txt:156` is:

```cmake
if(BUILD_TESTS)
  include(FindCUnit)
  find_package(CUnit REQUIRED cunit)
```

`REQUIRED`, so cmake **aborts** before producing a single object file. CUnit is
not in this tree and not in the backlog. The second reason — that
`src/tests/multithread.c:147` calls `pthread_cancel`, an API-24 gate — is real
too, and both are in the recipe's comment. Passing `-DBUILD_TESTS=OFF` is
correct and necessary.

## zlib is a genuine link dependency, and the `require()` is right

`src/CMakeLists.txt:37` lists `hdf/gunzip.c` in `libsrc` (verified in the
31-51 block), and `:14-15` sets `PKG_CONFIG_PRIVATELIBS` to `-lz -lm`, which
`libmysofa.pc.cmake:10` renders into `Libs.private:`. So `libmysofa.a` will
carry undefined `inflate`/`uncompress` references, and `include (FindZLIB)` at
`:12` resolves it through `$CMAKE_PREFIX_PATH`, which `$CMAKE_FLAGS` already
points at `$PREFIX`. `require("zlib")` is present. Correct.

stage1.md:124-126 makes a good catch worth repeating: the NDK sysroot *also*
ships a `libz.so` at every API level, so a missing prefix zlib would **not**
fail loudly — it would silently bind the target to the sysroot's zlib.
`$CMAKE_PREFIX_PATH` is searched first, so the right one wins. That is the kind
of silent-wrong-answer risk that justifies the `require()` rather than leaving
it to chance.

## The config template is cmake's, and no guard is correct

The tree's only `*.h.in` is `src/config.h.in`, consumed by
`configure_file(config.h.in config.h)` at `src/CMakeLists.txt:3` — a cmake
template with no autotools timestamp hazard. There is no `configure`, no
`aclocal.m4`, no `configure.ac`. So no guard, and the recipe has none.
Correct, and correctly reasoned in the comment (AGENTS.md:248-254's `awk`
allowance applies to rewriting a generated artifact, not to inventing a guard
for a build system that does not exist).

## The system

```
cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTS=OFF
cmake --build build --parallel 1
cmake --install build
```

All flags via `$CMAKE_FLAGS`, `--prefix` from the system, no hardcoded target
facts, no exported search flags, no `android.lua` (nothing Android-specific —
the recipe has no `case $HOST_ARCH`). `--parallel 1`, no fan-out. Every option
verified: `BUILD_TESTS:8`, `BUILD_SHARED_LIBS:9`, `BUILD_STATIC_LIBS:10`.

`project (libmysofa C CXX)` at `CMakeLists.txt:2` means a C++ compiler must
configure cleanly on every target. Every system here exports `$CXX`, and the
cross systems' `$CMAKE_FLAGS` include `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`
so cmake's C++ check links a static library rather than a runnable binary — no
emulation. stage1.md:133-138 flags this correctly as the one requirement that
would bite a future system added without `CXX`.

## No target binary is executed

With `BUILD_TESTS=OFF` the entire test tree is out — `src/tests/` is referenced
only from the `if(BUILD_TESTS)` block starting at `src/CMakeLists.txt:153`. The
`add_test(...)` registrations in the top-level `CMakeLists.txt:48-118` are all
inside `if(BUILD_TESTS)` too, and `enable_testing()` never runs. The library
build compiles C and links a static archive. Nothing executes anything. Clean.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. mingw is right for two reasons stage1:90 gives: `find_library (MATH m)`
is skipped on Windows (`src/CMakeLists.txt:7-11` sets `MATH ""`), and the MSVC
branch at `:16-29` that requires a `nuget` executable is not taken, because
mingw is `WIN32` but not `MSVC`. The zlib build-order caveat for mingw is
correctly labelled a build-order fact, not a defect.

## One thing the reviewer should weigh

**The 208 MB download is real.** stage1.md:18-50 measures it: archive
208,427,964 bytes, `du -sh tests` → 248 MB, `du -sh --exclude=tests .` →
1.9 MB, 79 of 183 tar entries under `tests/`. The library is 1.9 MB and the
rest is public HRTF measurement data. There is no smaller upstream artifact
(the GitHub releases carry only Windows `.lib`/`.pdb`), so the tag archive is
the only fetchable source.

stage1.md:43-50 identifies the single change that would fix it — drop `tests/`
at unpack time, which `BUILD_TESTS=OFF` makes safe — and then declines to make
it, calling it a policy call for the reviewer. **I think that is the right
call and I am not asking for it to change**, for the reason it gives: filtering
upstream content in the fetch stage changes what `$NESTDIR/source/libmysofa/`
is, and that is a tree-wide decision, not one a package recipe should make
silently. But someone with authority over that policy should make it
deliberately rather than by omission, because 249 MB per source refresh is not
free. Flagging it as an open question, not a defect.

## Verdict

ACCEPT. The symlink claim is exactly right and the recipe's handling is correct
because `cmake --install` does the work and dereferences it — two ~1.15 MB
copies is upstream's intent, not a recipe bug. `BUILD_TESTS=OFF` is verified
mandatory at configure time, zlib is a real link dependency with the
`require()` present, no guard is needed and none is present, no target binary
is executed, and every flag comes from the system. The 208 MB source archive
is a policy question worth a decision, not a defect in this recipe.
