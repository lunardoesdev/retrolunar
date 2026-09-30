ACCEPT

# mpc — stage 2 review

## What the recipe gets right

- **`make -j1` on all three lines**, including `make -j1 install` and
  `make -j1 install-html`. Correctly serialised.
- The guard at lines 12-13 is the standard form; mpc ships a top-level
  `config.h.in`.
- `--docdir="$OUT/share/doc/mpc-1.3.1"` directs the docs into the staging dir
  rather than letting them land in `/usr/share`, which is what
  AGENTS.md:237-238 requires.

## Three things the forecast should flag, none blocking

1. **`--disable-static` is a departure from this prefix's convention.** Every
   other autotools package here passes `--enable-static --disable-shared`.
   mpc is the opposite. That may be deliberate — gmp/mpc/mpfr are often
   consumed as a matched trio where the *shared* gmp is wanted — but
   AGENTS.md:29 requires the reason in a comment and there is none. Add one,
   or reconsider the flag.

2. **The version string `mpc-1.3.1` is hardcoded in the `--docdir` path**, and
   it duplicates `source.lua`'s pin. When mpc is bumped the docs land in a
   directory named after the old version. The forecast should note the
   coupling. Same issue in `packages/mpfr/generic.lua`.

3. **`make -j1 install-html` runs makeinfo.** It is a *host* tool this tree may
   not have. If `makeinfo` is absent the build fails at the last step, after
   the library has already been installed into `$OUT` — a confusing place to
   fail. The forecast should confirm makeinfo is present, or the `install-html`
   line should go the way `packages/m4` handles its texinfo (generate with a
   documented fallback rather than requiring the tool).

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmpc.a` **or** `.so` | `ls $PREFIX/lib/libmpc.*` — with `--disable-static` this is a `.so`, which is the flag taking effect |
| `$PREFIX/include/mpc.h` | `test -f $PREFIX/include/mpc.h` |
| `$PREFIX/lib/pkgconfig/mpc.pc` | `pkg-config --modversion mpc` |
| docs installed | `test -s $PREFIX/share/doc/mpc-1.3.1/index.html` — proves both `--docdir` and `install-html` worked |
| host makeinfo | `command -v makeinfo` must succeed **before** the recipe runs, or required change 3 applies |
