REJECT

# harfbuzz — stage 2 review

## Required changes

1. **`packages/harfbuzz/generic.lua:13-14` — `ninja -C build` and
   `ninja -C build install` are unserialised.** `AGENTS.md:226-229` requires
   "the build tool's equivalent single-job option", and for ninja that is
   `--parallel 1`. Replace both lines with:

   ```sh
           ninja -C build --parallel 1
           ninja -C build install
   ```

   This is the same shape `packages/fribidi/generic.lua:14-15` has, so if the
   tree's meson convention is being relaxed for ninja, settle it once rather
   than package by package — but as the rulebook stands it is a deviation.

2. **`packages/harfbuzz/generic.lua:12` — `-Dbuildtype=release` has no
   comment.** It is not a target fact, so it is not an `AGENTS.md` violation
   per se, but `AGENTS.md:29` asks for non-obvious choices to be explained and
   the forecast itself calls this choice only "defensible". Add a reason:

   ```sh
           # release: this prefix ships optimised static libraries and does
           # not carry the debug info a debug build would add.
   ```

## What the forecast gets right

- The meson option names are all real and correctly spelled: I checked them
  against `meson_options.txt` in the unpacked tree — `tests`, `docs`,
  `utilities`, `introspection`, `freetype`, `icu`, `graphite` all exist there.
- `-Ddefault_library=static` is present, which is the `AGENTS.md:248-252`
  requirement, and there is **no `DESTDIR`** in the install step — the
  kmod-class bug is correctly avoided here.
- `-Dglib=disabled -Dgobject=disabled -Dcairo=disabled` is right: this tree
  has no glib, and harfbuzz's meson otherwise finds the host's and links
  against it.
- `require("freetype")` and `require("fribidi")` are real dependencies and
  both packages exist.
- Version 14.5.0 is real: `meson.build:3` in the unpacked tree declares
  `version: '14.5.0'`.

## One correction to the forecast

`stage1.md` cites `generic.lua:13` for the `meson setup` line; it is actually
line 12. Trivial, but the line references in this shard have been unreliable
and the builder will follow them.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libharfbuzz.a` (static) | `ls $PREFIX/lib/libharfbuzz.*` — must be `.a`, not `.so`, confirming `-Ddefault_library=static` |
| `$PREFIX/include/harfbuzz/hb.h` | `test -f $PREFIX/include/harfbuzz/hb.h` |
| `$PREFIX/lib/pkgconfig/harfbuzz.pc` | `pkg-config --modversion harfbuzz` → `14.5.0` |
| freetype actually linked | `llvm-nm --undefined-only $PREFIX/lib/libharfbuzz.a \| grep -c FT_` → non-zero |
| no utils | `test ! -e $PREFIX/bin/hb-shape` — proves `-Dutilities=disabled` took effect |