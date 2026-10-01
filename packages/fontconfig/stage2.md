ACCEPT

# fontconfig review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, fontconfig 2.18.3.
Verified against the real tarball (`tar tf` OK, 1093 entries, top dir
`fontconfig-2.18.3/`), extracted to `/home/si/.revE/src/fontconfig-2.18.3`.

## 1. Is it using the SYSTEM?

Yes. `$MESON_FLAGS` and `$NESTDIR/source/fontconfig` only. No `export` of any
search flag; no hardcoded triplet/API/march. No `DESTDIR` (correctly explained
in the comment). `ninja -C build --parallel 1` explicit. No `sed`/patch.

Both `@native` requires are correct per AGENTS.md's rule that a host tool gets
an explicit system pin, and the reasoning in the comments matches the tree:

- `meson.build:461` is `find_program('gperf', required: false)`, but the
  fallback at **`meson.build:485`** is a bare `find_program('gperf')` with no
  `required: false`. A missing gperf is a hard configure error, so the
  `require("gperf@native")` is mandatory, not a convenience. Confirmed
  verbatim.
- `meson.build:103` is `python3 = import('python').find_installation()`,
  unconditional, and `meson.build:521-532` runs `src/makealias.py` via two
  `custom_target`s to generate `fcalias.h`/`fcftalias.h` and
  `fcftalias.h`/`fcftaliastail.h`. Confirmed.

## 2. Is it doing what the package needs?

**Every option passed exists.** All 24 names in `meson.options`; the recipe's
seven — `xml-backend`, `nls`, `tools`, `cache-build`, `tests`,
`tests-external-fonts`, `doc` — are all present (plus `buildtype`/
`default_library` as meson built-ins). Spot-checked the types, which matter
because a wrong *value* is as fatal as a wrong name:

- `xml-backend` is a `combo` with `choices: ['auto', 'expat', 'libxml2']` —
  `-Dxml-backend=expat` is a legal choice. Not a `feature`, so `expat` is
  right and `enabled` would have been wrong.
- `cache-build` is `type: 'feature', value: 'enabled'` — `-Dcache-build=disabled`
  is legal and is load-bearing.
- `tests-external-fonts` is `type: 'feature', value: 'enabled'` — i.e. **on by
  default**, which is what makes passing `disabled` necessary rather than
  tidy.
- `nls`, `tools`, `tests`, `doc` are `feature`/`auto`; `disabled` is legal.

**`-Dxml-backend=expat` is a correctness switch, not a preference.**
`meson.build:74-92`: with `auto` and no expat found, `meson.build:88-91` runs
`dependency('libxml-2.0', required: true)` — a hard failure, and one that could
bind a host library. Pinning expat avoids both. Confirmed.

**The version pin is real, current, and correctly justified.**

- freedesktop.org's release directory does stop at 2.16.0. I fetched and
  listed it: the newest entries are `fontconfig-2.15.0.tar.xz`,
  `fontconfig-2.16.0.tar.xz`. No 2.17/2.18 there. Confirmed.
- The GitLab generic-package API does carry 2.18.3, and it is the newest:
  listing versions returns `2.17.0, 2.17.1, 2.18.0, 2.18.1, 2.18.2, 2.18.3`.
  Confirmed current.
- pango's requirement is real: `pango-1.58.2/meson.build:219` is
  `fontconfig_req = '>= 2.17.0'`, and `:295` consumes it. So 2.16.0 would
  genuinely fail pango's configure. The source recipe's comment is accurate
  about the version floor, though it cites "pango meson.build:219" without the
  `pango/` path prefix — minor, the line number is right.

**The tarball is a genuine dist tarball, not a git archive.** This was the
specific risk, so I checked for the generated autotools files a git archive
would lack — all present with real sizes:

```
configure      761042 bytes  (executable, mode -rwxr-xr-x)
Makefile.in     39230 bytes
config.h.in     14928 bytes
```

and `configure.ac:42` is `AC_CONFIG_HEADERS(config.h)`, matching. The dist
tarball claim holds.

**No `android.lua`, and none is needed.** The one switch that is Android-shaped
is `cache-build=disabled` (stops `fc-cache/meson.build:12-15` registering an
install script that *runs* the freshly built target binary). That is a
no-emulation rule, not an Android fact — clang-native would hit it too — so
`generic.lua` is the right home. Correct.

**`tests-external-fonts=disabled` is load-bearing for the no-network rule.**
`meson.build:608` gates `subdir('test')`; the default is `enabled` and its
`fetch-testfonts.py` target downloads fonts at build time. Forbidden per
AGENTS.md. Correct.

## Corrections to `stage1.md` (none blocking)

- `stage1.md` cites `meson.build:517-532` for the makealias targets; the two
  `custom_target`s are at `meson.build:521` (`alias_headers`) and `:528`
  (`ft_alias_headers`). Immaterial.
- `stage1.md` describes the cache-dir `install_emptydir` as `meson.build:376-382`
  for Android; the install itself is `meson.build:645-646`. The behaviour claim
  is right; the line pointer is approximate.
- `stage1.md` says `pkg-config --modversion fontconfig` → `2.18.3`. That holds
  only if `meson.project_version()` is 2.18.3, which it is; no issue, but it is
  the kind of check that needs stating against the real `.pc`, which I do below.

## Artifacts — what actually installs

From the real tree:

- `lib/libfontconfig.a` — `library(... install: true)` at `meson.build:556`
- `include/fontconfig/{fontconfig.h,fcfreetype.h,fcprivate.h}` —
  `install_headers(fc_headers, subdir: 'fontconfig')` at `meson.build:637`, with
  the three names listed at `meson.build:631-635`
- `lib/pkgconfig/fontconfig.pc` — `pkgmod.generate(libfontconfig, ...)` at
  `meson.build:574`
- `fonts.dtd` under `share/xml/fontconfig` (`meson.build:627-629`) and the
  cache dir at `meson.build:645-646` (skipped on Windows)

## Forecast

I agree with **5 of 6**. The five WILL BUILD rows are right.

The `x86_64-mingw` UNCERTAIN is **correctly hedged and I am leaving it
UNCERTAIN**: the adder names exactly what it could not check (`src/fcunix.c`
against a mingw sysroot, with `-Dtools=disabled` meaning no `.exe` consumer is
built). UNCERTAIN is a legitimate answer per AGENTS.md; manufacturing a green
here would be the error, not the hedge. I found nothing that contradicts it —
`meson.build:644-647` correctly skips the cache dir on Windows.

The `clang-native` row is right for the two reasons given, and I confirmed
`cache-build` really does default to `enabled` (`meson.build:17`) and
`tests-external-fonts` really does default to `enabled`
(`meson.build:13-14`). **However**, see the system caveat below: on
clang-native this package hits the missing-`MESON_FLAGS` wall, so the row's
*build* reasoning is right while the *install* would not land in `$OUT`. That
is a system-file gap, not this recipe's defect.

### System-level caveat (not a recipe defect, recorded for the builder)

`packages/clang-native/generic.lua` contains **no `MESON` line at all** — no
`MESON_FLAGS`, no `MESON_CROSS_FILE` — while it does export `CMAKE_FLAGS` and
`AUTOCONF_CONFIGURE_FLAGS`. Confirmed by grep. I measured the consequence with
meson 1.12.0: `meson setup` with no `--prefix` records `prefix = '/usr/local'`.
So on clang-native `meson setup build $MESON_FLAGS -Ddefault_library=static …`
builds into `/usr/local`, `$OUT` stays empty, and the loader's
`cp -rf "$OUT"/. …` publishes nothing. Every cross system is unaffected
because they all set `MESON_FLAGS="--prefix=$OUT --cross-file …"`.

`packages/gumbo/stage1.md` already records this as a system-level blocker.
Per AGENTS.md the fix belongs in `packages/clang-native/generic.lua`
(`MESON_FLAGS="--prefix=$OUT"`), which is outside this package's scope and
outside a reviewer's remit. **It is not a reason to reject this recipe**, and
the recipe must not be changed to work around it — but the `clang-native` row
of this forecast should be read as "compiles, does not install".

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libfontconfig.a"                    || echo "MISSING libfontconfig.a"
test -f "$OUT/include/fontconfig/fontconfig.h"        || echo "MISSING fontconfig.h"
test -f "$OUT/include/fontconfig/fcfreetype.h"        || echo "MISSING fcfreetype.h"
test -f "$OUT/lib/pkgconfig/fontconfig.pc"            || echo "MISSING fontconfig.pc"

# 2. static not shared. Scoped by fontconfig's own name so a sibling's .so
#    cannot satisfy it.
find "$OUT/lib" -name 'libfontconfig.*' | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libfontconfig.so*' | wc -l           # expected 0

# 3. version: expected 2.18.3. Note the libtool name is plain libfontconfig,
#    so the file glob above is right; do NOT grep for 'libfontconfig-2'.
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion fontconfig

# 4. no $OUT left in the .pc (loader rewrite ran)
grep -c "$OUT" "$OUT/lib/pkgconfig/fontconfig.pc"          # expected 0

# 5. the three switches that matter, each checked against a real file:
#    -Dtools=disabled  -> no bin/fc-* anywhere in this package's output
test -d "$OUT/bin" && find "$OUT/bin" -name 'fc-*' | wc -l   # expected 0
#    -Dxml-backend=expat -> the config header records it, no LIBXML2 define
grep -c 'ENABLE_LIBXML2' "$OUT/include/fontconfig/fontconfig.h"   # expected 0
#    -Dnls=disabled -> no po/mo files under this package's share
find "$OUT/share" -name '*.mo' 2>/dev/null | wc -l                # expected 0

# 6. expat, not libxml2, must be the Requires.private
grep -i 'Requires' "$OUT/lib/pkgconfig/fontconfig.pc"

# 7. meson summary must show the four flags as off (only readable while the
#    block runs; $WORK is trap-removed at block end)
grep -E 'XML backend|NLS|Tools|Tests' "$WORK/build/meson-logs/meson-log.txt"
```