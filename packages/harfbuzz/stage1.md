# harfbuzz build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 14.5.0 (release asset `harfbuzz-14.5.0.tar.xz`, not a git tag)
- Build system: meson
- Installs: static `libharfbuzz.a`, `hb*.h` headers, `harfbuzz.pc` and a
  `harfbuzz` CMake package config. No tools: `utilities=disabled`.
- Requires: `freetype` (exists), `fribidi` (exists). Both are found through
  the prefix's pkg-config path, not by an explicit `--with`.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Pure cross-compile. `$MESON_FLAGS` carries the crossfile, `--prefix=$OUT` and `-Ddefault_library` is passed at `generic.lua:13`. The switches that matter are the four `disabled` ones: `tests` (a googletest suite, host binaries), `docs`, `utilities` and `introspection` (a GObject-introspection step that would need target-side `g-ir-scanner`). Dependencies resolve from `$PREFIX` via the system `PKG_CONFIG_LIBDIR` (`aarch64-android24/generic.lua:83-87`). |
| aarch64-android24 | WILL BUILD | As above; representative Android system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; harfbuzz has no arch-conditional source. |
| x86_64-mingw | WILL BUILD | `glib`/`gobject`/`cairo`/`icu`/`graphite` are all `disabled` at `generic.lua:13`, so the only backend is FreeType+FriBidi, which is in the prefix for every system. |
| clang-native | WILL BUILD | As above. |

**API level notes.** harfbuzz gates nothing on the API level; it uses only
`malloc`/`free` and C++ standard library. Nothing in the recipe reads
`$ANDROID_API`.

**Risks / what a reviewer should check.**

1. **`ninja -C build` at `generic.lua:13-14` runs at full parallelism, and
   `ninja` is not serialised.** AGENTS.md:225-229 requires a single-job build
   (`make -j1` or `--parallel 1`) for every recipe, for log readability and
   deterministic ordering. Every other meson recipe in this tree uses
   `meson compile -C build --parallel 1`; this one is the exception. This is a
   rule deviation in an otherwise correct recipe — the single honest fix is to
   add `--parallel 1` to both ninja lines.
2. `-Dbuildtype=release` is hardcoded, unlike every other flag in the tree
   which comes from the system. It is a target-independent build-type choice
   rather than a target fact, so it is defensible, but it is the only recipe
   here that picks a build type itself.
3. `-Dintrospection=disabled` is the load-bearing switch on Android: GObject
   introspection runs `g-ir-scanner` over the built library, which is a target
   binary. Good catch by whoever wrote this.

**How to verify once built.**

- `lib/libharfbuzz.a` exists.
- `pkg-config --modversion harfbuzz` reports 14.5.0.
- `$OBJDUMP -f lib/libharfbuzz.a` prints `elf64-littleaarch64` on an Android
  system; on `x86_64-mingw` the archive members are PE COFF objects.
- `llvm-nm lib/libharfbuzz.a | grep hb_shape` shows `hb_shape` defined, proving
  the library itself linked (not just that an archive was written).
- Rerunning the install script prints `skip harfbuzz (fresh)`.
