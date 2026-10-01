ACCEPT

# pixman review (stage2)

Recipe: `generic.lua` + `android.lua`. Source: `source.lua`, pixman 0.46.4.
Verified against the real tarball, extracted to a scratch dir under
`/home/si/.revE/src/pixman-0.46.4`. Every tarball was checked with `tar tf`
before extraction (235 entries, top dir `pixman-0.46.4/`).

## 1. Is it using the SYSTEM?

Yes, throughout. The only flag inputs are `$MESON_FLAGS` (which carries
`--prefix=$OUT` and `--cross-file $MESON_CROSS_FILE` on every cross system)
and `$NESTDIR/source/pixman`. No `export` of any search flag. No hardcoded
triplet, API level, `-march`, or `--host`. No `DESTDIR`. No `sed`, no patch,
no `/dev/null`. `ninja -C build --parallel 1` is explicit and single-job
(AGENTS.md: ninja does not default to serial, so this is load-bearing, not
cosmetic).

## 2. Is it doing what the package needs?

**Every option passed exists.** pixman declares its options in a *multiline*
`option(` form — the name is on the line AFTER `option(`, so a naive
`^option('name'` grep returns nothing and a reviewer can easily convince
himself the options are absent. Extracted all 20 names:

```
a64-neon arm-simd cpu-features-path demos gnu-inline-asm gnuplot gtk
libpng loongson-mmi mips-dspr2 mmx neon openmp rvv sse2 ssse3 tests
timers tls vmx
```

All seven the recipe passes are present: `tests`, `demos`, `libpng`, `gtk`,
`openmp` (`generic.lua`), `arm-simd`, `neon` (`android.lua`). `buildtype` and
`default_library` are meson built-in core options, correctly not in
`meson.options`.

**The `android.lua` claim is TRUE, and I reproduced the failure and the
asymmetry directly.** `android.lua` claims it is load-bearing for armv7a only.

1. Header absence, verified with my own `find` over the r28b sysroot:

```
$ find $SYSROOT -name 'cpu-features*'
(no output — zero hits)
$ find $SYSROOT -name '*.h' | xargs grep -l android_getCpuFamily
(no output — the symbol is declared nowhere in the sysroot)
```

   Sanity that the sysroot was readable, not silently skipped:
   `$SYSROOT/usr/include/stdio.h` is 15887 bytes. AOSP's own copy does ship in
   the NDK, but under `sources/android/cpufeatures`, never in the sysroot — so
   it cannot be found by `#include <cpu-features.h>`.

2. `pixman-arm.c` structure confirmed: `:36` is
   `#if defined(USE_ARM_SIMD) || defined(USE_ARM_NEON)`, and `:96-123` is the
   `#elif defined(__ANDROID__) || defined(ANDROID)` branch that does
   `#include <cpu-features.h>` at `:98` and calls `android_getCpuFamily()` /
   `android_getCpuFeatures()`.

3. Compile probe. I had to stub `config.h` and `pixman-version.h` (both are
   meson-generated, absent from the tarball). **My first stub wrongly baked
   `#define USE_ARM_SIMD 1` into `config.h`, which poisoned every case;** with
   a clean stub the results are:

| target | macro | result |
|---|---|---|
| `armv7a-linux-androideabi35` | `-DUSE_ARM_NEON` | `fatal error: 'cpu-features.h' file not found` at `tu.c:99` (i.e. `pixman-arm.c:98`), rc=1 |
| `armv7a-linux-androideabi35` | `-DUSE_ARM_SIMD` | same fatal error, rc=1 |
| `aarch64-linux-android35` | `-DUSE_ARM_A64_NEON` | **rc=0, compiles clean** |
| `armv7a-linux-androideabi35` | `-DPIXMAN_NO_TLS` | rc=0, compiles clean |

   That last row is the control: with neither `USE_ARM_SIMD` nor
   `USE_ARM_NEON` defined, the `:36` guard excludes the whole block and the
   header is never reached. So the header is missing *and* the guard admits
   the file only for those two macros — the claim is exactly right.

4. The aarch64 immunity mechanism checks out end to end. `meson.build:322`
   gates a64-neon on `cpu_family() == 'aarch64'`; `:290`/`:306` gate arm-simd
   and neon on `cpu_family() == 'arm'`. The cross files agree: the aarch64
   ones say `cpu_family = 'aarch64'`, the armv7a ones say `cpu_family = 'arm'`
   (checked `aarch64-android24`, `aarch64-android35`, `x86_64-android35`,
   `armv7a-android35`). `meson.build:330` sets `USE_ARM_A64_NEON`, which
   `pixman-arm.c:36` never tests — so aarch64 keeps full NEON.

The recipe's choice is also the *right* one: upstream's alternative is
`cpu-features-path` (`meson.options:81-85`), which wants a local copy of
AOSP's `cpu-features.[ch]`, and there is no such package in this prefix.
Vendoring one is the patch-shaped answer AGENTS.md forbids. Losing SIMD on
armv7a only is the cheap, honest trade, and `android.lua` says so.

## Corrections to `stage1.md` (none blocking)

- `stage1.md`'s claim that `meson.build:298/315` defines `USE_ARM_SIMD` /
  `USE_ARM_NEON` is off by a few lines: the `config.set10` calls are at
  **`meson.build:298`, `:314`, `:330`** for SIMD/NEON/A64-NEON respectively.
  The conclusion is unaffected.
- `stage1.md` says the tarball is "827,198 bytes" implicitly by nothing —
  no issue. I measured 827,198 bytes, `tar tf` OK, 235 entries.
- No `cpu-features*` hit is an **absence** claim, and it is the kind AGENTS.md
  warns about. It is backed here by the command and its control above.

## Artifacts — what actually installs

Verified in the real tree rather than assumed:

- `lib/libpixman-1.a` — `library(... install: true)` with
  `-Ddefault_library=static` (`pixman/meson.build:122-131`)
- `include/pixman-1/pixman.h` — `install_headers('pixman.h', subdir: 'pixman-1')`
  at `pixman/meson.build:141`
- `include/pixman-1/pixman-version.h` — **installed**, via
  `configure_file(... install_dir: .../pixman-1)` at `pixman/meson.build:26-31`.
  This matters because `pixman.h:72` does `#include <pixman-version.h>`. I
  initially mis-read that `install_dir` as belonging to something else and
  briefly believed the header was not installed; a probe of a consumer TU
  (`#include <pixman.h>`) against a prefix holding only `pixman.h` failed
  with `fatal error: 'pixman-version.h' file not found`, and adding the
  header made it compile. Ground truth from a real pixman 0.42.2 build tree
  agrees both ways: autotools
  `libpixmaninclude_HEADERS = pixman.h pixman-version.h`, meson the same
  `install_dir`. **The stage1 artifact list was right and my first reading
  was wrong** — recorded because the trap is real and a later reader may hit it.
- `lib/pkgconfig/pixman-1.pc` — `pkg.generate(filebase: 'pixman-1')` at
  `meson.build:614-621`, `subdirs: 'pixman-1'`

`-Dbuildtype=release` is justified: `meson.build:27` pins
`buildtype=debugoptimized` in `default_options`, and this prefix ships
optimised archives.

## Forecast

I agree with **6 of 6** rows. All WILL BUILD. The aarch64/armv7a reasoning in
the x86_64-android35 and aarch64 rows holds, and the clang-native row is right
that no Android recipe is consulted there.

One caveat on the clang-native row, which is a *system* fact rather than a
pixman defect and therefore not this recipe's to fix: `packages/clang-native/
generic.lua` exports **no `MESON_FLAGS` and no `MESON_CROSS_FILE`** (the file
has no `MESON` line at all, while it does export `CMAKE_FLAGS` and
`AUTOCONF_CONFIGURE_FLAGS`). I confirmed the consequence: `meson setup` with
no `--prefix` records `prefix = '/usr/local'`. So on clang-native the build
succeeds but nothing lands in `$OUT` and the loader publishes an empty tree.
`packages/gumbo/stage1.md` documents exactly this as a system-level blocker.
pixman's recipe is written correctly (`$MESON_FLAGS`, no hardcoded prefix) —
the gap belongs in `packages/clang-native/generic.lua`, per AGENTS.md's rule
that a rule describing the target system goes in the system file. Recorded
here so the builder is not surprised; **not** a reason to reject the recipe.

## Carried to the build

Scoped to pixman's own outputs; every check names a path pixman owns, so it
cannot pass in an empty prefix or fail when a second package installs.

```sh
# 1. artifacts (expected: all four exist)
test -f "$OUT/lib/libpixman-1.a"                 || echo "MISSING libpixman-1.a"
test -f "$OUT/include/pixman-1/pixman.h"         || echo "MISSING pixman.h"
test -f "$OUT/include/pixman-1/pixman-version.h" || echo "MISSING pixman-version.h"
test -f "$OUT/lib/pkgconfig/pixman-1.pc"         || echo "MISSING pixman-1.pc"

# 2. static, not shared: the direct check that -Ddefault_library=static took.
#    Scoped by pixman's own name, so a sibling's .so cannot satisfy it.
find "$OUT/lib" -name 'libpixman-1.*' | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libpixman-1.so*' | wc -l           # expected 0

# 3. version string, expected 0.46.4
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion pixman-1

# 4. no $OUT left in the .pc (loader rewrite ran; src/loader.lua:454-468).
#    Scoped to pixman's own file: grep on $PREFIX/lib/pkgconfig would measure
#    the whole prefix.
grep -c "$OUT" "$OUT/lib/pkgconfig/pixman-1.pc"          # expected 0

# 5. ELF machine of the archive, per system family
$OBJDUMP -f "$OUT/lib/libpixman-1.a" | head -3

# 6. the ARM switch is load-bearing exactly as stage2 claims. On armv7a the
#    meson log must NOT mention an arm implementation; on aarch64 it SHOULD.
#    (armv7a only — see the note in stage1.md about android.lua over-disabling)
grep -o 'arm-simd\|neon\|a64-neon' "$WORK/build/meson-logs/meson-log.txt" | sort -u

# 7. the cpu-features.h fix really is in force: no reference may survive into
#    the installed tree. Scoped to the output, not $WORK.
grep -rc 'cpu-features' "$OUT/include" 2>/dev/null        # expected 0
```

Note for check 6: `$WORK/build/...` is the meson build dir the recipe creates,
and `$WORK` is removed by the loader's `trap` only at the end of the block, so
the log is readable while the block runs.