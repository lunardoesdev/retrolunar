ACCEPT

# cairo review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, cairo 1.18.6.
Verified against the real tarball (`tar tf` OK, 4976 entries, top dir
`cairo-1.18.6/`), extracted to `/home/si/.revE/src/cairo-1.18.6`.

## 1. Is it using the SYSTEM?

Yes. `$MESON_FLAGS` plus `$NESTDIR/source/cairo`. No `export` of search flags,
no hardcoded triplet/API/march, no `DESTDIR`, no `sed`/patch,
`ninja -C build --parallel 1` explicit. All five deps resolve through
`$PREFIX` via the systems' `PKG_CONFIG_LIBDIR`; nothing is hardcoded.

## 2. Is it doing what the package needs?

**All fifteen options passed exist, and each value is legal.** cairo declares
17 options; the full set is `dwrite fontconfig freetype glib gtk2-utils
gtk_doc lzo png quartz spectre symbol-lookup tee tests xcb xlib xlib-xcb
zlib`. Every one the recipe passes is present:

passed: `png zlib freetype fontconfig` (enabled) and `xlib xcb xlib-xcb
quartz dwrite glib lzo spectre symbol-lookup gtk2-utils tests` (disabled).
`buildtype`/`default_library` are meson built-ins. No nonexistent flag — which
was the specific thing to check, since a nonexistent flag is worse than a
missing one.

`-Dgtk2-utils=disabled` is a no-op by design: `meson.options:20` is
`option('gtk2-utils', type : 'feature', value : 'disabled')`. The recipe says
so rather than pretending it does work.

**pixman is indeed enabled by no switch, and the reasoning is right.**
`meson.build:677-680`:

```
pixman_dep = dependency('pixman-1',
  version: '>= 0.40.0',
  fallback: ['pixman', 'idep_pixman'],
)
```

It has `version:`/`fallback:` but **no `required:` option**, so meson defaults
to `required: true`. My review finding in `pixman/stage2.md` also matters here:
pixman 0.46.4 *does* install `pixman-version.h` (via
`pixman/meson.build:26-31`'s `install_dir`), so cairo's `#include <pixman.h>`
(`src/cairoint.h:63`) resolves against the installed prefix. Verified
empirically — a consumer TU compiles against the installed headers.

**The X11 run-check is real and disabling xlib genuinely avoids it.**
`meson.build:387-401` is the important passage:

```
prop = meson.get_external_property('ipc_rmid_deferred_release',
        meson.is_cross_build() ? 'false' : 'auto')
```

On a cross build this resolves to `'false'` and `cc.run` is skipped — so on
the four Android systems and mingw the run check is *already* avoided.
But `meson.build:365-366` looks up `x11`/`xext` **before** that, guarded by
`required: get_option('xlib')`, which defaults to `auto`. With `auto` and no
host `.pc` visible it would simply not be found — and with a host `.pc`
visible it would bind host X11 into a target prefix. `-Dxlib=disabled` makes
the intent explicit and safe on every system. That is the stronger reason, and
the recipe's comment leads with the run check rather than the host-binding
risk; both are real, and the conclusion is right either way.

I checked the `clang-native` case the adder flags: `meson.build:365-366` plus
the unconditional `meson.build:888-891` win32 block mean a host `.pc` really
could be picked up, so the explicit `disabled` is load-bearing rather than
decorative.

**Every dependency has a `fallback:` that would attempt a network download.**
`subprojects/` holds `expat.wrap fontconfig.wrap freetype2.wrap glib.wrap
libpng.wrap pixman.wrap zlib.wrap`, and each `dependency()` carries a
`fallback:`. If a `.pc` were missing from `$PREFIX` the build would try to
clone at configure time — forbidden per AGENTS.md. The recipe's `require()`
list covers each of them, and `-Dglib=disabled` removes the one dep
deliberately absent. This is the single highest-value check for the builder
(see §5 below).

**`python@native` is genuinely required, twice.** `meson.build:3` runs
`run_command(find_program('version.py'), check: true)` with
`check: true` — a hard error if it fails — and `version.py:1` is
`#!/usr/bin/env python3`. Separately `boilerplate/meson.build:24-27` runs
`make-cairo-boilerplate-constructors.py`. Both confirmed. `@native` is right:
these are host tools.

**Version floors all satisfied.** `meson.build:9` freetype `>= 23.0.17`,
`:11` fontconfig `>= 2.13.0`, `:12` libpng `>= 1.4.0` — all met by the pinned
fontconfig 2.18.3 and the existing freetype/libpng/zlib.

**No host program is compiled for the target.** `-Dtests=disabled` gates both
suite subdirs — `meson.build:843-846`:

```
if not get_option('tests').disabled() and feature_conf.get('CAIRO_HAS_PNG_FUNCTIONS', 0) == 1
  subdir('test')
  subdir('perf')
```

I checked `perf/` specifically since `stage1.md` lists it as a suite:
`perf/meson.build:5-10` builds `libcairoperf`, a **static** library that links
`gtk+-2.0` — under the same `tests` gate, so `disabled` covers it. Also
`util/` (`meson.build:841`) is *not* under the tests gate: it builds
`cairo-script`/`cairo-trace`. With `zlib=enabled`, `CAIRO_HAS_INTERPRETER`
(`meson.build:627-629`) is set and `util/cairo-script` builds
`libcairo-script-interpreter`. That is a **target** library installed into the
prefix, which is exactly what `stage1.md` risk 5 warns the builder to expect.
Not a defect; noted so it is not mistaken for one.

`trace` is not built: it needs `CAIRO_HAS_DLSYM` (`meson.build:225-233`,
probe-derived) and a `linux`-family `system()` check, so Android skips it.

## Corrections to `stage1.md` (none blocking)

- `stage1.md` says the Xlib run check is at `meson.build:393-401`. That is
  right, but it should also record `meson.build:387` (`get_external_property`
  with `is_cross_build() ? 'false' : 'auto'`), which is *why* the run check
  never fires on a cross build — i.e. the run check is not the load-bearing
  reason `-Dxlib=disabled` is needed. The host-binding risk is. Worth
  recording so a future reader does not "fix" a flag that is protecting against
  something other than what the comment says.
- `stage1.md` cites `meson.build:843-846` for "test and boilerplate program
  sets"; the gate is at `843-845` and covers `test/` and `perf/`. `boilerplate/`
  is a *support* library built by `-Dpng=enabled`, not a suite — `stage1.md`
  risk 4 says this correctly elsewhere, so the two statements are consistent
  but the §2 phrasing is loose.
- `stage1.md` says the Xlib block is `meson.build:365-404`; the block runs
  `:365-404` with the dependency lookup at `:365-366`. Consistent.

## Artifacts — what actually installs

- `lib/libcairo.a` — `pkgmod.generate(libcairo, ...)` at `meson.build:266`
  with `subdirs: ['cairo']`; static via `-Ddefault_library=static`
- `include/cairo/*.h` — `install_headers(cairo_headers, subdir: 'cairo')` at
  `src/meson.build:273`, where `cairo_headers` is built at `:121`/`:233` and
  `cairo-features.h` appended at `:257-258`. So `cairo.h`, `cairo-features.h`,
  `cairo-ft.h`, `cairo-pdf.h`, `cairo-ps.h`, `cairo-svg.h` all install.
- `lib/pkgconfig/cairo.pc` plus **one `.pc` per built feature** —
  `meson.build:852-860` loops `foreach feature: built_features` and calls
  `pkgmod.generate` with `name: feature['name']`. The names come from the
  `built_features` dicts, e.g. `'cairo-xlib'` at `meson.build:370`.
- `libcairo-script-interpreter.a` when zlib is on (see above).

## Forecast

I agree with **3 of 6**: the four Android rows and clang-native's UNCERTAIN on
reasoning I could verify, plus mingw's UNCERTAIN.

- The four `aarch64/x86_64-android*` **WILL BUILD** rows: correct. The X11/GL
  family is off, `host_machine.system()` is `android` so the win32 block
  (`meson.build:504-585`, adding gdi32/msimg32 and enabling the win32 surface)
  never fires, and every dep resolves from `$PREFIX`.
- `x86_64-mingw` **UNCERTAIN**: correctly hedged. The adder verified the
  mingw-side headers exist and states precisely what it did not compile. I
  accept the hedge; I did not compile cairo's win32 surface either, and I note
  the combination it flags (`-Ddwrite=disabled` + `meson.build:583`'s
  `_WIN32_WINNT_VISTA` branch while `:504-516` still adds gdi32/msimg32) is
  upstream's own default shape, not something the recipe creates.
- `clang-native` **UNCERTAIN**: correctly hedged, and the reason given (X11,
  XCB, libxml-2.0, glib-2.0, gobject-2.0, lzo2, libspectre are all present on
  this host, so the disabled switches are the only thing stopping host
  binding) is the honest one.

The one place I would not follow the forecast as *stated* is the same
clang-native install caveat as in the other meson packages: this recipe is
correct, but `packages/clang-native/generic.lua` exports no `MESON_FLAGS`, so
`meson setup build $MESON_FLAGS …` carries no `--prefix` and meson defaults to
`/usr/local` (measured, meson 1.12.0). It compiles; it does not land in `$OUT`.
That is a system-file gap — see `pixman/stage2.md` for the measurement — and
per AGENTS.md it must not be worked around in this recipe.

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libcairo.a"                    || echo "MISSING libcairo.a"
test -f "$OUT/include/cairo/cairo.h"             || echo "MISSING cairo.h"
test -f "$OUT/include/cairo/cairo-features.h"    || echo "MISSING cairo-features.h"
test -f "$OUT/lib/pkgconfig/cairo.pc"            || echo "MISSING cairo.pc"

# 2. static not shared, scoped by cairo's own name
find "$OUT/lib" -name 'libcairo.*' | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libcairo.so*' | wc -l           # expected 0

# 3. version expected 1.18.6
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion cairo

# 4. THE FOUR DISABLED-BACKEND CHECKS. Each absent .pc is one disabled toggle,
#    so this is the precise regression signal. Scoped to cairo's own .pc files
#    (grep on the whole pkgconfig dir would measure the prefix).
cd "$OUT/lib/pkgconfig"
for f in cairo-xlib.pc cairo-xcb.pc cairo-quartz.pc cairo-win32.pc; do
  [ -e "$f" ] && echo "REGRESSION: $f exists"
done
echo "x11/xcb/quartz/win32 pc files absent: OK if nothing printed above"

# 5. the four ENABLED backends must each have a .pc (png/zlib/freetype/fontconfig
#    are the four -D=enabled switches)
for f in cairo-ft.pc cairo-fc.pc cairo-png.pc cairo-svg.pc cairo-ps.pc cairo-pdf.pc; do
  test -e "$f" || echo "MISSING expected enabled backend: $f"
done

# 6. pixman must be in cairo's Requires, or cairo builds fine and every consumer
#    fails to link
grep -i '^Requires' cairo.pc

# 7. no $OUT left in any of cairo's .pc files. Scoped with a glob over cairo's
#    own files, so a sibling package's .pc cannot produce a false hit.
grep -l "$OUT" cairo*.pc; echo "(no output above = loader rewrite ran)"

# 8. no subproject fallback fired. A wrap firing means a .pc was missing from
#    $PREFIX and the build tried a NETWORK download. Check the configure log.
grep -iE 'subproject|wrap-mode|Neither a subproject directory' \
     "$WORK/build/meson-logs/meson-log.txt" | head
echo "(expected: no wrap download lines)"

# 9. no X11 anywhere in the built config
grep -c 'CAIRO_HAS_XLIB_SURFACE' "$OUT/include/cairo/cairo-features.h"  # expected 0
grep -c 'CAIRO_HAS_XCB_SURFACE'  "$OUT/include/cairo/cairo-features.h"  # expected 0

# 10. ELF machine
$OBJDUMP -f "$OUT/lib/libcairo.a" | head -3
```