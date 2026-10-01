# cairo build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.18.6
- Build system: **meson** (`meson.build:1-7`, `meson_version: '>= 1.3.0'`;
  cairo 1.18 has no autotools at all)
- Requires: `pixman` (in this batch), `freetype` (exists),
  `fontconfig` (in this batch), `libpng` (exists), `zlib` (exists),
  `python@native` (exists), `cairo@source`. **`glib` is deliberately NOT
  required** — it is absent from this prefix and cairo's gobject backend is
  optional.
- Installs: `lib/libcairo.a`, `include/cairo/*.h`, `cairo.pc` plus one `.pc`
  per built backend (`meson.build:266-273`, `855-868`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Every dependency is explicit: pixman is looked up unconditionally at `meson.build:677-680`; freetype needs `>= 23.0.17` (`meson.build:9`, i.e. 2.10; ours is 2.13.3 = 25.13.3); fontconfig needs `>= 2.13.0` (`meson.build:11`); libpng `>= 1.4.0`; zlib plain. The X11/GL family is off, which is what makes this work: `meson.build:365-404` is the Xlib block and it contains a **run check** — `meson.build:393-401` executes a compiled test program for `IPC_RMID_DEFERRED_RELEASE` — that a cross target binary cannot perform and that we never emulate. All eight disabled toggles are enumerated in `generic.lua` with reasons. `host_machine.system()` is `android`, so the `windows` block (`meson.build:504-585`, which adds gdi32/msimg32 and pulls in a C++ compiler for DWrite) and the `darwin` quartz block (`:470`) never fire. Nothing cairo probes at `meson.build:168-183` (`alarm`, `ctime_r`, `localtime_r`, `gmtime_r`, `drand48`, `flockfile`, `funlockfile`, `getline`, `link`, `fork`, `waitpid`, `raise`, `newlocale`, `strtod_l`) is above API 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. Note `meson.build:814-816` sets `ATOMIC_OP_NEEDS_MEMORY_BARRIER` for any non-x86 family, which is the correct branch here. |
| x86_64-mingw | UNCERTAIN | The mingw toolchain genuinely carries the Windows-side prerequisites — I verified `d2d1.h`, `dwrite_3.h`, `d2d1_2.h`, `d2d1_3.h` and `libd2d1.a`/`libdwrite.a`/`libwindowscodecs.a` all exist, and that a `windows.h` + `dwrite_3.h` TU compiles. But this recipe sets `-Ddwrite=disabled`, and with that off `meson.build:583` takes the `_WIN32_WINNT_VISTA` branch **while** `meson.build:504-516` still unconditionally adds `gdi32` and `msimg32` and sets the win32 surface and font features. That combination is upstream's own default shape, but I did not compile cairo's win32 surface against mingw, so I will not call it green. |
| clang-native | UNCERTAIN | This is the system most likely to break, and the reason is exactly the flag set. **X11, XCB, libxml2, glib, lzo2 and libspectre are all installed on this build host** (I confirmed each with `pkg-config --exists`: x11 1.8.13, xext, xcb, libxml-2.0, glib-2.0, gobject-2.0, lzo2, libspectre). With `-Dxlib=disabled` and friends cairo will not bind them — but only because those switches are there. Remove one and it silently becomes a host-library dependency, which is the whole reason they are spelled out rather than left on `auto`. UNCERTAIN, not WILL BUILD, because cairo's `perf/` and `test/` sets are off (`-Dtests=disabled`, `meson.build:843-846`) so I have no evidence about the atomics/mkdir probe results on this compiler. |

## API level notes

**No API gate is hit.** cairo's own header probe list
(`meson.build:127-156`) is all `#ifdef`-guarded config, and its function
probes are `cc.has_function`, so a miss is a feature flag rather than an error.
`nl_langinfo`, `posix_spawn`, `mktime_z` and `O_BINARY` appear nowhere in
`src/`. `dlopen` appears nowhere in `src/` either — `meson.build:225-233`
sets `CAIRO_HAS_DLSYM` only from probes, and with it unset the trace utility
(`meson.build:820-822`, which also requires `system() in ['linux', ...]`) is
not built at all on Android.

## Risks / what a reviewer should check

1. **The eight disabled toggles are the recipe.** Each is justified inline in
   `generic.lua`. The reviewer should spot-check the two that are easy to get
   backwards: `symbol-lookup` (`meson.build:631`, needs binutils/**bfd**, a
   host facility that must never reach a target library) and `glib`
   (`meson.build:587-595`, absent from this prefix — enabling it would fail
   outright, and its gobject functions are not wanted).
2. **`pixman` is enabled by no switch at all.** `meson.build:677-680` looks it
   up unconditionally because the image surface is core cairo. If a reviewer
   expects a `-Dpixman=enabled` and finds none, that is correct, not a
   missing flag.
3. **Subproject fallbacks are declared but must never fire.** Every
   dependency carries a `fallback:` (`meson.build:245,258,291,327,589,594,679`)
   and `subprojects/` holds wraps for zlib, libpng, freetype2, fontconfig, glib
   and pixman. Any of them firing means a `.pc` was not found in `$PREFIX`, and
   the fallback would try a **network download** at build time — forbidden. A
   reviewer should check the configure log for "Looking for ... NOT found"
   followed by a subproject line.
4. **`-Dpng=enabled` costs a python3 run.** It pulls in
   `boilerplate/meson.build:26`, whose custom_target runs
   `make-cairo-boilerplate-constructors.py`. That is why `python@native` is
   required even though cairo's library itself is C.
5. **cairo installs several libraries, not one.** With zlib on,
   `CAIRO_HAS_INTERPRETER` (`meson.build:627-629`) builds and installs
   `libcairo-script-interpreter` (`util/cairo-script/meson.build:27-37`).
   Expect it; do not treat it as a defect.

## How to verify once built

- `lib/libcairo.a` — a `.a`, confirming `-Ddefault_library=static`
- `include/cairo/cairo.h`, `cairo-features.h` (`meson.build:257-258`),
  `cairo-ft.h`, `cairo-pdf.h`, `cairo-ps.h`, `cairo-svg.h`
- `libcairo.pc` plus the per-feature `.pc` files: `cairo-fc.pc`,
  `cairo-ft.pc`, `cairo-png.pc`, `cairo-svg.pc`, `cairo-ps.pc`, `cairo-pdf.pc`,
  `cairo-script.pc`, `cairo-tee.pc`. **`cairo-xlib.pc`, `cairo-xcb.pc`,
  `cairo-quartz.pc` and `cairo-win32.pc` must NOT exist** — each is one
  disabled toggle, so their presence is a precise regression signal.
- `pkg-config --modversion cairo` → `1.18.6`
- The meson summary (`meson.build:871-896`) must show FreeType/fontconfig and
  PNG/PS/PDF/SVG true, and Xlib/XCB/Quartz false
- `$OBJDUMP -f lib/libcairo.a` → `elf64-littleaarch64` on Android
- `grep -c 'Requires' libcairo.pc` / check its `Requires:` line actually names
  pixman-1 — if pixman is missing there, cairo builds fine and every consumer
  fails to link (the same latent-link problem flagged for lcms2)
- `pkg-config --libs cairo-ft` must mention both freetype2 and fontconfig,
  since `cairo-ft.h` includes `fontconfig.h` (`meson.build:336`)