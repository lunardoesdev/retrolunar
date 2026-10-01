REJECT

# OpenAL-Soft 1.21.0 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

The blocker is one word on the `cmake` line. It is not a style point: it
inverts the build to a shared library and drops the one macro every consumer
of the AL headers needs.

## Required change

**`packages/OpenAL-Soft/generic.lua:34` passes `-DLIBTYPE=Static`. Upstream
compares with `STREQUAL "STATIC"`, and cmake's `STREQUAL` is
case-sensitive. The value never matches, so the build takes the shared
branch and `openal.pc` ships without `-DAL_LIBTYPE_STATIC`.**

Change `Static` to `STATIC`:

```diff
-cmake -S . -B build $CMAKE_FLAGS -DLIBTYPE=Static -DALSOFT_UTILS=OFF …
+cmake -S . -B build $CMAKE_FLAGS -DLIBTYPE=STATIC -DALSOFT_UTILS=OFF …
```

Nothing else in the recipe needs to change.

### The evidence

Every test in the 1.21.0 tree is `if(LIBTYPE STREQUAL "STATIC")`, spelled in
upper case, and there is no normalisation anywhere in the file:

```
$ grep -n 'STREQUAL "STATIC"' CMakeLists.txt
311:    if(NOT LIBTYPE STREQUAL "STATIC")
322:        if(NOT LIBTYPE STREQUAL "STATIC")
329:            if(NOT LIBTYPE STREQUAL "STATIC")
1173:if(LIBTYPE STREQUAL "STATIC")
1207:if(LIBTYPE STREQUAL "STATIC")
1323:if(WIN32 AND MINGW AND ALSOFT_BUILD_IMPORT_LIB AND NOT LIBTYPE STREQUAL "STATIC")
```

`CMakeLists.txt:140-141` only defaults when unset (`if(NOT LIBTYPE) set(LIBTYPE
SHARED)`), so passing `Static` leaves the value as the literal string
`Static` — neither unset nor `"STATIC"`.

What that costs, all verified in the tree:

1. **`:1207` is false → the build is SHARED.** The static branch is
   `:1208` `add_library(${IMPL_TARGET} STATIC …)`; the shared branch is
   `:1257` `add_library(${IMPL_TARGET} SHARED …)`. So this produces
   `libopenal.so` — precisely the versioned shared object the recipe's own
   first comment says a target prefix has no loader path for.
2. **`:1173` is false → `openal.pc` has no `-DAL_LIBTYPE_STATIC`.** The
   `set(PKG_CONFIG_CFLAGS -DAL_LIBTYPE_STATIC)` at `:1174` never runs. The
   recipe's own comment (`:10-11`) and `stage1.md:60-63` both say this is
   the difference between a working consumer and one that cannot link; with
   `Static` it is silently absent, and the AL headers take the
   `__declspec(dllimport)` form.
3. **`:1209` never runs**, so `AL_LIBTYPE_STATIC` is not a `PUBLIC` compile
   definition on the exported target either.
4. **`:311/:322/:329` are all true**, so `EXPORT_DECL` is set to
   `__attribute__((visibility("protected")))` on a non-Windows build —
   visibility attributes that a static archive does not want.
5. **`:1323` is true on mingw**, so the `ALSOFT_BUILD_IMPORT_LIB` block
   re-enters. The recipe's `-DALSOFT_BUILD_IMPORT_LIB=OFF` still saves it
   (the option is only declared at `:125` inside `if(MINGW)`, but passing it
   on the command line pre-seeds the cache, so the `AND ALSOFT_BUILD_IMPORT_LIB`
   guard is false). That one is a genuine save, not luck — but it is the
   only one of the five that the recipe's own comments had right.

### The case-sensitivity claim, proved rather than asserted

I settled this with a throwaway cmake project rather than reasoning about
`STREQUAL`:

```cmake
cmake_minimum_required(VERSION 3.10)
project(p C)
if(NOT LIBTYPE)
  set(LIBTYPE SHARED)
endif()
if(LIBTYPE STREQUAL "STATIC")
  message(STATUS "RESULT: MATCHED -> static")
else()
  message(STATUS "RESULT: NOT matched -> shared path taken")
endif()
```

```
$ cmake -S probe -B probe/b -DLIBTYPE=Static
-- LIBTYPE=[Static]
-- RESULT: NOT matched -> shared path taken
```

That is the whole defect, reproduced outside the package. It is also why
this slipped through: `-DLIBTYPE=Static` produces **no** cmake warning. The
value is accepted, cached and used; it is only ever compared, and every
comparison is false. A recipe carrying it looks deliberate and is silently
wrong, which is the failure mode the brief singles out.

## The claims I was asked to verify

**"1.21.0 has no `alsoft/` subdirectory; the top-level CMakeLists IS the
build."** **CONFIRMED.** `ls -d openal/alsoft` → *No such file or directory*.
Top-level directories in the 1.21.0 tree are exactly:

```
al  alc  build  cmake  common  docs  examples  hrtf  include
presets  resources  router  utils
```

`utils/` is at the root and contains `openal-info.c`, `alsoft-config/`,
`makemhr/`, `sofa-info.cpp`. So the adder is right that the layout changed
and right that no recipe switch needs to name `alsoft/…`. (For the record,
the tag `openal-soft-1.21.0` and `1.21.0` are the same commit; the adder
pinned the former, which resolves — I downloaded both and the trees match
except for the two tag-name lines.)

**"LIBTYPE defaults SHARED."** **CONFIRMED** — `CMakeLists.txt:140-141`.

**"With STATIC it sets `AL_LIBTYPE_STATIC` both on the target (`:1209`) and
in `openal.pc` (`:1173-1174`)."** **CONFIRMED as an upstream fact** — both
lines exist exactly as cited. It is the *recipe* that fails to trigger them,
which is the defect above. So the adder's analysis of upstream is right on
this point too; the only error is the value's spelling, and the comments
that quote `LIBTYPE=STATIC` (`generic.lua:8`, `:23`) are correct while the
command line that has to match them is not.

## Question 1 — is it using the SYSTEM?

Yes, apart from the one value. `cmake -S . -B build $CMAKE_FLAGS …`,
`cmake --build build --parallel 1`, `cmake --install build`. No hardcoded
target facts, no `export` of search flags, no per-target recipe.
`require("OpenAL-Soft@source")` resolves and the tree lands in
`$OUT/OpenAL-Soft/`. Correct.

Every option the recipe passes genuinely exists in 1.21.0 — I checked each
one rather than trusting the list, because a nonexistent flag is worse than
a missing one:

| option passed | exists at | note |
|---|---|---|
| `ALSOFT_UTILS` | declared | removes `openal-info` + `alsoft-config` |
| `ALSOFT_EXAMPLES` | declared | removes alplay/alstream |
| `ALSOFT_INSTALL_EXAMPLES` | declared | |
| `ALSOFT_INSTALL_UTILS` | declared | |
| `ALSOFT_INSTALL_CONFIG` | declared | `alsoft.conf` install, `:1396` |
| `ALSOFT_BUILD_IMPORT_LIB` | `:125`, inside `if(MINGW)` | command-line cache seed makes it defined on every system; harmless |
| `ALSOFT_UPDATE_BUILD_VERSION` | declared | |
| `ALSOFT_INSTALL_HRTF_DATA` | declared | `install(DIRECTORY hrtf …)` at `:1402` |
| `ALSOFT_INSTALL_AMBDEC_PRESETS` | declared | `install(DIRECTORY presets …)` at `:1408` |

All ten exist. So the "every option passed genuinely EXISTS" test passes —
it is only the *value* of `LIBTYPE` that is wrong.

The HRTF/AmbDec data decision (`stage1.md` risk 1) is right and I endorse
it: they are data the library loads from the prefix at runtime, not host
programs, and `install(DIRECTORY …)` at `:1402`/`:1408` confirms they are
plain file copies. `ALSOFT_INSTALL_CONFIG=OFF` (risk 2) is a defensible
call either way and is not a defect.

## The forecast

All six rows say WILL BUILD and cite `LIBTYPE=Static` as the reason the
library is static — `stage1.md:21` literally reads "`LIBTYPE=Static` avoids
a versioned `.so` a target cannot load, and sets `AL_LIBTYPE_STATIC` on the
exported target (`:1209`)". **The forecast is contradicted by the recipe it
describes**: the recipe does the opposite of what the row claims. That is a
finding on its own under AGENTS.md ("a forecast that contradicts the recipe
is a REJECT"), and here both are wrong in the same direction.

The rows are otherwise careful — the `ALSOFT_BUILD_IMPORT_LIB` / "requires
sed" note at `:21-24` is a real upstream help string (`CMakeLists.txt:125`
`"Build an import .lib using dlltool (requires sed)"`), and correctly
identified as a thing this tree must not run.

**The concrete thing that would break the mingw row**, since the brief asks
per row: with `Static`, `:1323` is true and the import-lib block runs
`find_program(SED_EXECUTABLE NAMES sed …)`. It is currently saved only by
`-DALSOFT_BUILD_IMPORT_LIB=OFF`. So the mingw build survives *by accident of
a second correct flag*, while every other system silently gets a shared
library. That asymmetry is worth stating: the one row the adder reasoned
hardest about is the one that works, and the five rows dismissed with "as
above" are the ones that break.

The Android rows' "API level notes: none found" is credible — the mixer is
portable C/C++ and the Android backends are the oboe/opensl wrappers, none
of which reference a symbol Bionic lacks. I did not find a gate either.

## Carried to the build

- `lib/libopenal.a` exists — **a `.a`, not a `.so`**. This is the check that
  catches the defect above if the fix is not applied; with `Static` the
  build produces `lib/libopenal.so` instead and this fails.
- `include/AL/al.h`, `alc.h`, `efx.h` exist.
- `lib/pkgconfig/openal.pc` exists and `pkg-config --modversion openal`
  reports 1.21.0.
- **`grep -c AL_LIBTYPE_STATIC lib/pkgconfig/openal.pc` must be ≥ 1** — state
  the expected value. With `Static` this is 0 and the install is silently
  unusable by any consumer that includes the AL headers.
- `$OBJDUMP -f lib/libopenal.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libopenal.a | grep -cw alGetVersion` non-zero.
- `lib/cmake/OpenAL/OpenALConfig.cmake` exists (`install(EXPORT OpenAL …)`,
  `:1378`).
- `ls $OUT/share/openal/hrtf` is non-empty, and `presets` is non-empty. The
  install destination is `${CMAKE_INSTALL_DATADIR}/openal` (`:1403`, `:1409`).
  An empty directory means the data switch regressed.
- `ls $OUT/bin/` is empty — no `openal-info`, no `alsoft-config`, no `alplay`.
- `test ! -e $OUT/share/openal/alsoft.conf` — the sample config is off.
