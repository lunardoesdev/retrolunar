# pango build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.58.2
- Build system: **meson** (`meson.build:1-9`, `meson_version: '>= 1.2.0'`; pango
  1.58 has no autotools)
- Requires: `glib` (**ABSENT from this prefix — see below**), `cairo` (in this
  batch), `harfbuzz` (exists), `fribidi` (exists), `fontconfig` (in this
  batch), `freetype` (exists), `pango@source`
- Installs: `lib/libpango-1.0.a`, `libpangocairo-1.0.a`,
  `libpangoft2-1.0.a`, the `pango/` headers and `pango*.pc`

## The blocker, stated plainly

**pango cannot be configured in this prefix today, because `glib` does not
exist here.** This is not a version problem or an option problem:

- `pango/meson.build:233-235` look up `glib-2.0`, `gobject-2.0` and `gio-2.0`
  with **no `required: false` and no `fallback:`** — a missing glib is a hard
  configure error, not a degraded build.
- `meson.build:211-214` pins the floor at **GLib 2.88**, and `:225-226` bakes
  `GLIB_VERSION_MIN_REQUIRED`/`GLIB_VERSION_MAX_ALLOWED` for 2.88 into every
  compile line, so a lower glib would fail at compile time as well.
- `packages/glib/` does not exist. Verified: `ls -d packages/glib` →
  `No such file or directory`, and no `libglib*.pc` anywhere in the nest.
- GLib is a meson project with a large `meson_options.txt` and dozens of
  feature probes (`libmount`-style host-facility detection, d-bus, systemd,
  libmount, pcre2, selinux, xattr, and more). It is **not in this batch**, and
  I have not researched it, so I will not guess its options.

The recipe below is written as it should be, with the correct `require("glib")`
in place, so that adding a glib package makes pango work with no edit here.
**Every verdict row is conditioned on that dependency existing.**

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | `meson.build:233` fails: `Dependency 'glib-2.0' version '>= 2.88' is required but not found`. Not an API-level problem — a missing package. Everything else in the row is fine: `fribidi >= 1.0.6` (`:216,237`, we have 1.0.16), `harfbuzz >= 11.0.0` (`:218,281`, we have 14.5.0), `cairo >= 1.18.0` (`:221,380`, we have 1.18.6), and `fontconfig >= 2.17.0` (`:219,295`) — which is precisely why fontconfig 2.18.3 is pinned rather than 2.16.0. |
| aarch64-android24 | WILL NOT BUILD | As above. |
| aarch64-android35 | WILL NOT BUILD | As above. |
| x86_64-android35 | WILL NOT BUILD | As above. |
| x86_64-mingw | WILL NOT BUILD | As above, plus a second wall behind it: `meson.build:365-367` errors outright if `host_system == 'windows'` and `dwrite_3.h` is missing, and `-Ddwrite=disabled` in the cairo recipe means pango's `cairo-dwrite-font` lookup at `meson.build:392-398` will not find a backend. Two blockers, glib first. |
| clang-native | WILL NOT BUILD | As above. |

**If and when a glib >= 2.88 package is added, these rows become WILL BUILD
with no recipe change**, subject to the mingw DWrite note in the last row.

## What the recipe gets right, and what a reviewer should check

1. **`fontconfig` is REQUIRED on every non-Windows target, not optional.**
   `meson.build:259-261` sets `fontconfig_required = host_system not in
   ['windows','darwin']`; `:294` then forces the option to `true`, and `:288-290`
   is an explicit `error('Fontconfig support cannot be disabled on this
   platform')`. So `-Dfontconfig=disabled` would fail the configure — the
   recipe correctly leaves it alone. Same for freetype, which follows at
   `:305-309`.
2. **`-Dxft=disabled` matters.** Left on `auto`, `meson.build:337` would
   resolve `xft >= 2.0.0` — and this build host has X11, so it could bind a
   host library into a target prefix.
3. **`build-testsuite` and `build-examples` default to TRUE**
   (`meson.options:23-31`), so passing `false` is required, not optional.
4. **A tool builds that looks like a host program and is not.**
   `tools/meson.build:1-6` builds `gen-script-for-lang` with
   `install: false`, so it is compiled for the target and never installed or
   run. That is fine — it is a target binary the recipe simply does not ship.
   Contrast `utils/meson.build`, which installs `pango-view`, `pango-list` and
   `pango-segmentation` (`install: true`) — real target programs, not host ones.
5. **harfbuzz's own cairo integration is off in this prefix**
   (`packages/harfbuzz/generic.lua` passes `-Dcairo=disabled`), which is
   correct and does not affect pango: pango wants harfbuzz for shaping, and
   gets its cairo from `packages/cairo` directly.
6. **Two hard requirements with no fallback.** `fribidi` (`:237`) and
   `harfbuzz` (`:281`) are both unconditional, exactly like glib. All three
   are satisfied here; glib is not.

## How to verify once built (after glib exists)

- `lib/libpango-1.0.a`, `libpangocairo-1.0.a`, `libpangoft2-1.0.a` — all
  `.a`, confirming `-Ddefault_library=static`
- `include/pango-1.0/pango/pango.h`
- `pkg-config --modversion pango` → `1.58.2`
- The meson summary (`meson.build:582-588`) must show Cairo true and, for the
  Fontconfig row, `freetype` true — `pango_font_backends` is filled at
  `:436-476` and an empty one is a hard `error('No Cairo font backends found')`
  at `:478-480`
- `pango.pc`, `pangocairo.pc`, `pangoft2.pc` present; `pangoxft.pc` **must not**
  be — its absence proves `-Dxft=disabled` took effect