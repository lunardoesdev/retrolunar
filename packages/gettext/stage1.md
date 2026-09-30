# gettext build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 0.26
- Build system: autotools
- Installs: `lib/libintl.so` (shared), `lib/libasprintf.so`; `include/libintl.h`; `lib/preloadable_libintl.so`; `bin/gettext`, `bin/ngettext`, `bin/xgettext`, `bin/msgfmt`, `bin/msgmerge`, `bin/msgcat`, …; **no `.pc`**
- Requires: `gettext@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (link)** | topackage.md:30 records the blocker in full and the recipe comment at `generic.lua:5-11` reproduces it exactly: the NDK hides `iconv.h`'s declarations before API 28, so gettext's iconv probe fails, `libtextstyle` is built with `HAVE_ICONV=0`, and `libtextstyle/lib/libtextstyle.sym.in:41` still exports `iconv_ostream_create` — which that build does not define. `ld.lld` then fails with "version script assignment of 'global' to symbol 'iconv_ostream_create' failed: symbol not defined". The recipe's `-Wno-error=incompatible-function-pointer-types` gets *past compilation*; the comment says so and says the link still fails. |
| aarch64-android24 | **WILL NOT BUILD (link)** | Same; `iconv.h` is guarded before API 28, and 24 < 28. |
| aarch64-android35 | **WILL NOT BUILD (link)** | Same, and **this is the important row**: 35 ≥ 28, so `iconv.h` *should* be visible and the probe *should* succeed — which means `HAVE_ICONV=1` and `iconv_ostream_create` would be defined, and the recorded blocker would *not* apply. **But the recipe's comment describes the failure unconditionally, and topackage.md:30 does not qualify it by API level.** Either the API-28 guard does not cover what gettext's probe needs even at 35, or the topackage entry is under-qualified. **I could not resolve this without configuring, and it is the single most useful thing for a reviewer to test here.** |
| x86_64-android35 | **WILL NOT BUILD (link)** | Same as the aarch64-35 row; arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | mingw-w64 has `iconv.h` only via a separate package, and gettext 0.26's libtextstyle is not built for PE targets in any case. |
| clang-native | **UNCERTAIN** | glibc has a real `iconv`, so the probe succeeds and the version-script mismatch cannot occur. Whether 0.26 completes is unverified. |

## API level notes

**The recorded blocker is nominally an API-level one (`iconv.h` before 28)
but the evidence does not support a clean level boundary.** Two reasons
for doubt, and both are checkable:

1. Bionic also has **no separate `-liconv`** at any level — `iconv_open`
   and friends live in `libc.so` — so even at API 35 the *link* side
   differs from glibc. gettext's `AC_CHECK_LIB([iconv])` would find
   nothing to add to `LIBS`, which is fine, but it means the probe's
   success at 35 is not the same kind of success as on glibc.
2. The recipe's `CFLAGS` workaround (`generic.lua:12-13`) is applied
   **unconditionally**, i.e. also to `clang-native`. That is only
   harmless because the host does not hit the diagnostic. It suggests the
   workaround was added for the Android case and never revisited.

## Risks / what a reviewer should check

- **`export CFLAGS` at `generic.lua:13` is the one place in the a–g shard
  where a recipe mutates `CFLAGS`.** AGENTS.md's exception is
  "recipe-local workarounds with a comment explaining why", and there *is*
  a comment (`generic.lua:5-11`) that explains it in detail. So this is
  the sanctioned form, and the comment is unusually good. But it should be
  re-examined once the underlying iconv problem is solved, at which point
  it should be deleted rather than left to mask a future diagnostic.
- **`--disable-static` (`generic.lua:16`)** makes `libintl` a shared
  object, which is correct and conventional for gettext (its whole model is
  that programs LD_PRELOAD or link the replacement `libintl`). This is one
  of the few shared-library packages here where shared is clearly the
  right answer.
- **`chmod 0755 $OUT/lib/preloadable_libintl.so` at `generic.lua:24`** is a
  genuine, correct recipe-local fix: gettext installs that file mode 0644
  because it is normally mapped rather than executed, but its stated use is
  `LD_PRELOAD`, which requires the execute bit. The comment explains it.
  Good.
- **`make -j1` is now explicit on both lines.** RETRACTION, and it matters: **bare `make` is not a parallelism violation.** Measured empirically: `make` reports `MAKEFLAGS=[]` and `make -j1` reports `MAKEFLAGS=[-j1]` — a bare `make` is already serial. The recipe now passes `-j1` explicitly anyway, because AGENTS.md asks for a single-job build to be *explicit* rather than implicit and that is better practice; but the edit was **not** required, and an earlier version of this file called the omission a defect and named other packages for the same thing. That was wrong, and it is the same defect class as the other false premises in this wave: a rule that sounds right, is not, and trains the next reader to fail correct recipes. No further package should be failed on bare `make`.
- **`--docdir=$OUT/share/doc/gettext-0.26`** (`generic.lua:17`) hardcodes
  the version in the path. A version bump that forgets to update it puts
  the docs in a directory named for the old release. Cosmetic but real.

## How to verify once built

Not verifiable until the iconv problem is resolved. After that:

- `lib/libintl.so`, `lib/libasprintf.so`, `lib/preloadable_libintl.so`
- `include/libintl.h`
- `bin/gettext`, `bin/msgfmt`, `bin/xgettext`
- `readelf -d lib/libintl.so` → `Type: DYN`, `Machine: AArch64`
- `ls -l lib/preloadable_libintl.so` → mode `755`, not `644`; that is the
  direct check for the `chmod` at `generic.lua:24`
- `share/doc/gettext-0.26/` present — and check the directory name matches
  the version
