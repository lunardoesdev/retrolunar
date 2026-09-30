ACCEPT

# FriBidi 1.0.16 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

**This is the reference example the rest of the shard should be measured
against**, and `stage1.md` is right to say so. Both meson rules are satisfied:

- `-Ddefault_library=static` is present on the `meson setup` line, with the
  reason written out (meson builds shared by default; a target prefix has no
  loader path for a versioned object). This is exactly what
  `packages/freetype/generic.lua` omits — see `packages/freetype/stage2.md`.
- The install step is a bare `ninja -C build install` with **no `DESTDIR`**,
  so the `--prefix=$OUT` already carried by `$MESON_FLAGS` is what the install
  honours. Adding `DESTDIR` would have produced `$OUT$OUT`.
- `-Dtests=false -Ddocs=false -Dbin=false` name the three real options in
  fribidi's `meson_options.txt`; the fourth, `deprecated`, is left at its
  default, which is right.
- `require("fribidi@source")` names no missing package, and there is no
  `@native` need: nothing here shells out to a build-host program.

## One observation, not a reject reason

`ninja -C build` runs multi-job — ninja's default is `nproc + 2` — and
AGENTS.md's serial-build rule covers "the build tool's equivalent single-job
option", which for ninja is `-j1`. So a strict reading wants
`ninja -C build -j1`.

I am not rejecting on it, for two reasons: AGENTS.md names *this exact file* as
"the worked example" for meson recipes, and freetype (the only other meson
recipe here) does the same. That makes it a house-wide convention rather than
a fribidi bug. It is worth one tree-wide decision, not a per-package edit —
if the tree wants strict serial builds, change it here and in freetype
together and note it in AGENTS.md's meson paragraph.

`stage1.md`'s "no reason given for `-Dbuildtype=release`" is a fair nit. It is
worth one line, because a reader cannot tell whether `release` is a
house convention or a leftover: it disables meson's `debug`/`debugoptimized`
assertions, which is the right default for a shipped library.

## Carried to the build

- `lib/libfribidi.a` — `llvm-objdump -f lib/libfribidi.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **`lib/libfribidi.so` must be absent** — its presence means `-Ddefault_library=static` is missing.
- `include/fribidi/fribidi.h` — `[ -f include/fribidi/fribidi.h ]`.
- `lib/pkgconfig/fribidi.pc` — `pkg-config --modversion fribidi` → `1.0.16`. If it prints a path containing `tmp.` or a `mktemp` directory, the loader's `$OUT`→`$PREFIX` rewrite did not run.
- `bin/` must be **absent** (`-Dbin=false`); `bin/fribidi-main` appearing means the switch did not take.
