ACCEPT

# pango review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, pango 1.58.2.
Verified against the real tarball (`tar tf` OK, 603 entries, top dir
`pango-1.58.2/`), extracted to `/home/si/.revE/src/pango-1.58.2`.

## 1. Is it using the SYSTEM?

Yes. `$MESON_FLAGS` plus `$NESTDIR/source/pango`. No `export` of search flags,
no hardcoded triplet/API/march, no `DESTDIR`, no `sed`/patch,
`ninja -C build --parallel 1` explicit.

## 2. Is it doing what the package needs?

**All eight options passed exist.** pango's `meson.options` declares exactly
twelve: `build-examples build-testsuite cairo documentation fontconfig
freetype gtk_doc introspection libthai man-pages sysprof xft`. The recipe
passes `xft libthai sysprof introspection documentation man-pages
build-testsuite build-examples` — all present. `buildtype`/`default_library`
are meson built-ins.

Two defaults I verified because the recipe's justification rests on them:

```
meson.options:23-26   option('build-testsuite',  type: 'boolean', value: true)
meson.options:28-31   option('build-examples',    type: 'boolean', value: true)
```

Both genuinely default to **true**, so passing `false` is required, not
cosmetic. And `sysprof` defaults to `disabled` (`meson.options:38-41`) and
`documentation`/`man-pages`/`gtk_doc` to `false`, so those three are named for
the record — correctly labelled as such in the comments.

**The blocker is real, and stated honestly.** Verified directly:

```
$ ls -d packages/glib
ls: cannot access 'packages/glib': No such file or directory   (rc=2)
```

The recipe's `require("glib")` therefore cannot resolve. This is a load-time
failure — the loader will raise "package glib not found" when it tries to
resolve `require("glib")`, so the build script will not even be emitted. That
is worth stating plainly to the builder: this is not a build that fails
partway, it is a package that cannot be queued.

**The cited meson lines are substantively right but the FILE PATH is wrong.**
The recipe and `stage1.md` both attribute the glib lookup to
**`pango/meson.build:233-235`**. The actual location is the **top-level
`meson.build`**:

```
meson.build:233  glib_dep    = dependency('glib-2.0',   version: glib_req)
meson.build:234  gobject_dep = dependency('gobject-2.0', version: glib_req)
meson.build:235  gio_dep     = dependency('gio-2.0',     version: glib_req)
```

`pango/meson.build:233` is inside a `library()` call for `pangoft2-1.0`. The
*line numbers* and the *content* are exactly as claimed — three unconditional
`dependency()` calls with no `required: false` and no `fallback:` — so the
substantive claim ("a missing glib is a hard configure error, not a degraded
build") is confirmed. Only the file path is wrong. Since AGENTS.md makes a
citation the backbone of a forecast, I am recording the correction; it is a
documentation defect in a comment, not a behavioural one, so it does not change
the verdict. **The adder should fix both citations.**

The GLib floor is also confirmed at `meson.build:211-213`
(`glib_major_req = 2`, `glib_minor_req = 88`), and `:225-226` bakes
`GLIB_VERSION_MIN_REQUIRED`/`MAX_ALLOWED` for 2.88 into every compile line, so a
lower glib fails at compile time as well as configure time.

**Other version floors verified, and they corroborate the fontconfig pin.**
`meson.build:216-221`: `fribidi_req >= 1.0.6`, `harfbuzz_req >= 11.0.0`,
`fontconfig_req >= 2.17.0`, `cairo_req >= 1.18.0`. The fontconfig floor of
**2.17.0** is the direct reason fontconfig 2.18.3 is pinned rather than
freedesktop's 2.16.0 — the two packages' claims interlock and both are true.

**The `-Dxft=disabled` reasoning is right.** `meson.build:337` is
`dependency('xft', version: xft_req, required: get_option('xft'))`; left on
`auto` it would resolve a host `xft` on a machine that has one.

**The two other claims I checked directly:**

- fontconfig is genuinely REQUIRED on non-Windows: `meson.build:259-261` sets
  `fontconfig_required = host_system not in ['windows','darwin']` and `:288-294`
  errors if disabled there. The recipe correctly does **not** pass
  `-Dfontconfig=disabled`. Same for freetype at `:305-319`.
- `-Dintrospection=disabled` is right: `:236` gates
  `dependency('gobject-introspection-1.0', ...)` on
  `get_option('introspection').enabled()`, and `g-ir-scanner` is a host
  gobject-introspection tool.

**No host program is compiled and none is executed.** The one tool that looks
like a host program is `tools/gen-script-for-lang`; `stage1.md` risk 4 states it
is built with `install: false` and never run. I did not independently confirm
that file, but it is not load-bearing for the verdict: the recipe ships no
target tool that a build step would execute, and there is no `meson test` or
`run_command` on a target binary in the paths this recipe enables.

## Corrections to `stage1.md` (none blocking)

- The `pango/meson.build` → `meson.build` path correction above, in both the
  recipe comment and the forecast.
- `stage1.md` cites `:281` for harfbuzz; that is `harfbuzz_dep = dependency('harfbuzz', …)`.
  Correct.
- `stage1.md`'s "**If and when a glib >= 2.88 package is added, these rows
  become WILL BUILD with no recipe change**" is slightly optimistic: the
  mingw row's second blocker (`meson.build:365-367` erroring when
  `host_system == 'windows'` and `dwrite_3.h` is missing, combined with cairo's
  `-Ddwrite=disabled`) would still stand. The adder does flag that inline, so
  the summary sentence is the only loose one.

## Artifacts — what actually installs

From the real tree (`-Ddefault_library=static`):

- `lib/libpango-1.0.a` — `library('pango-1.0', …, install: true)` in
  `pango/meson.build`; `install_headers(pango_headers, subdir: pango_api_path)`
- `lib/libpangocairo-1.0.a` — `pango/meson.build:562-568`
- `lib/libpangoft2-1.0.a` — `pango/meson.build:228-241`, with
  `install_headers(pangoft2_headers + pangofc_headers + pangoot_headers, …)`
- `include/pango-1.0/pango/pango.h`
- `pango.pc`, `pangocairo.pc`, `pangoft2.pc`; **not** `pangoxft.pc`

## Forecast

I agree with **6 of 6**. All six rows are **WILL NOT BUILD**, and the stated
reason — `packages/glib` does not exist — is exactly right, confirmed by
`ls -d packages/glib` returning rc=2. Recording WILL NOT BUILD honestly for a
missing package is the behaviour AGENTS.md asks for; inventing a green here
would be the error.

The forecast is also useful in the way a forecast should be: it says the
recipe is already correct and the blocker is a missing dependency, which is
what lets this package be accepted now and built later without rework.

Caveat carried forward from the other meson packages: even with glib present,
the `clang-native` row would hit the missing-`MESON_FLAGS` system gap. That is
a system-file defect, not this recipe's, and must not be worked around here.

## Carried to the build

**This package cannot be built yet.** `require("glib")` will fail to resolve at
load time, so the emitted script will not exist. These checks are for the
builder *after* a `packages/glib` exists — record that precondition at the top
of the stage3.md rather than presenting a build that never ran.

```sh
# PRECONDITION: packages/glib must exist, else the loader raises on
# require("glib") and no build script is emitted at all.
ls -d "$PACKAGEDIR/glib" || { echo "BLOCKED: no glib package"; exit 1; }

# 1. artifacts (expected: all present)
test -f "$OUT/lib/libpango-1.0.a"     || echo "MISSING libpango-1.0.a"
test -f "$OUT/lib/libpangocairo-1.0.a"|| echo "MISSING libpangocairo-1.0.a"
test -f "$OUT/lib/libpangoft2-1.0.a"  || echo "MISSING libpangoft2-1.0.a"
test -f "$OUT/include/pango-1.0/pango/pango.h" || echo "MISSING pango.h"

# 2. static not shared, scoped by pango's own library names
find "$OUT/lib" -name 'libpango-1.0.*'      | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libpango-1.0.so*'    | wc -l           # expected 0

# 3. version expected 1.58.2
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion pango

# 4. pangoxft.pc MUST NOT exist: its absence is the proof that -Dxft=disabled
#    took effect. Scoped to pango's own .pc files, not the pkgconfig dir.
cd "$OUT/lib/pkgconfig"
test -e pangoxft.pc && echo "REGRESSION: pangoxft.pc exists (xft not disabled)"
for f in pango.pc pangocairo.pc pangoft2.pc; do
  test -e "$f" || echo "MISSING expected: $f"
done

# 5. no $OUT left in pango's .pc files
grep -l "$OUT" pango*.pc; echo "(no output above = loader rewrite ran)"

# 6. fontconfig + freetype must be in the Requires chain, and cairo too
grep -i '^Requires' pango.pc

# 7. no host pkg-config leaked in: every dependency name must be one this
#    prefix provides. Anything host-shaped (x11, xcb, xft) is a defect.
pkg-config --print-requires pango

# 8. the meson summary must show Cairo true and fontconfig's freetype true.
#    An empty pango_font_backends is a hard error at meson.build:478-480, so
#    reaching a successful configure already proves it.
grep -E 'Cairo|fontconfig|freetype' "$WORK/build/meson-logs/meson-log.txt"
```