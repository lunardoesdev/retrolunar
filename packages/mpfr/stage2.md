ACCEPT

# mpfr — stage 2 review

## What the recipe gets right

- **`make -j1` on all three lines**, including `make -j1 install` and
  `make -j1 install-html`. Correctly serialised.
- The guard at lines 13-14 is the standard form; mpfr ships a top-level
  `config.h.in`.
- **`--enable-thread-safe` is a deliberate, correct choice** and the right kind
  of package-local flag: it is a build characteristic, not a target fact, so it
  belongs in `generic.lua` and not in a system file. Worth a comment per
  AGENTS.md:29, but the placement is correct.
- `--docdir="$OUT/share/doc/mpfr-4.2.2"` directs docs into the staging dir per
  AGENTS.md:237-238.

## Three things the forecast should flag, none blocking

1. **`--disable-static` is a departure from this prefix's convention.** Every
   other autotools package here passes `--enable-static --disable-shared`.
   mpfr is the opposite, and it matters more here than for mpc: a *static*
   mpfr is what a prefix wants precisely because it can be linked into shared
   modules, while a shared mpfr in `$PREFIX/lib` is a target `.so` that nothing
   can load. If the reason for `--disable-static` is that a shared gmp/mpfr pair
   is wanted, say so in a comment; if not, this flag looks like an accident.

2. **The version string `mpfr-4.2.2` is hardcoded in `--docdir`** and
   duplicates `source.lua`'s pin, so a version bump silently installs docs
   under the old directory name. Same coupling as `packages/mpc`.

3. **`make -j1 install-html` runs makeinfo**, a host tool this tree may not
   have. If absent, the build fails at the last step after the library is
   already installed — a confusing place to fail. `packages/m4` shows the
   alternative: generate the texinfo and `touch` the manual rather than
   requiring the tool.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmpfr.a` **or** `.so` | `ls $PREFIX/lib/libmpfr.*` — with `--disable-static` this is a `.so` |
| `$PREFIX/include/mpfr.h` | `test -f $PREFIX/include/mpfr.h` |
| `$PREFIX/lib/pkgconfig/mpfr.pc` | `pkg-config --modversion mpfr` |
| thread safety compiled in | `llvm-nm -D --defined-only $PREFIX/lib/libmpfr.so \| grep -c __gmp_mutex` → non-zero, proving `--enable-thread-safe` took |
| docs installed | `test -s $PREFIX/share/doc/mpfr-4.2.2/index.html` |
