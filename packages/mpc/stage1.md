# mpc build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.1 (ftp.gnu.org)
- Build system: autotools
- Installs: `libmpc.a` and `mpc.h`. The HTML documentation is installed too
  (`make -j1 install-html` at `generic.lua:15`). No tools — GMP's tools are
  gmp's, not mpc's. No `.pc` file from mpc itself.
- Requires: `gmp` (exists), `mpfr` (exists) — both hard link dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-static` at `generic.lua:9` is a typo-shaped switch name that autoconf silently ignores (the real option is `--enable-static`), so the build is static-or-shared by mpc's own default — and mpc's default is static. Worth knowing, because it means **the recipe does not actually control this**, unlike its neighbours libmpfr and libogg which pass `--enable-static --disable-shared` explicitly. The library itself is small, portable C calling GMP and MPFR; no API-gated symbol. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; GMP and MPFR are in the prefix and build for every system. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. mpc is arithmetic on top of GMP/MPFR — it calls
`mpz_*`, `mpfr_*` and `malloc`. The only thing to check is that GMP's
`gmp.h` is found, which it is through `$CPPFLAGS`/`$LDFLAGS` pointing at
`$PREFIX`. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`--disable-static` is almost certainly a mistake, and the recipe inherits
   it from mpfr** — `mpfr/generic.lua:8` has the identical flag. Autoconf
   generates `--enable-static` and `--enable-shared`; a bare
   `--disable-static` is not a recognised option and is ignored with a warning.
   The build is currently correct **by luck**, because GMP's and mpc's default
   is static. **What would settle it: the configure log.** A line reading
   `configure: WARNING: unrecognized options: --disable-static` confirms it.
   This is the single most actionable finding in this file, and it applies to
   `mpfr` too — the two recipes should either drop the flag or use the real
   `--enable-static --disable-shared` pair that every other recipe in this
   shard uses.
2. **`--docdir="$OUT/share/doc/mpc-1.3.1"` hardcodes the version twice** — once
   in `source.lua` and once in the path here. Same maintenance trap as lua's
   hand-written `.pc`: a version bump must touch two places. The path is
   `$OUT`-relative, so the loader's rewrite applies and it lands in the right
   place, but the duplication is real.
3. **`make -j1 install-html` is unusual and is the second half of that
   `--docdir` flag.** mpc's `install` target does not install the HTML docs;
   `install-html` is a separate target. So this line is required, not
   decorative. Worth a comment, because a reader who "simplifies" it to a
   plain `install` would silently lose the documentation.
4. **The `.pc` question: mpc ships no `mpc.pc`.** Its consumers (mpfr's
   `gmp`-based configure) use `--with-gmp` and `--with-mpfr` with explicit
   prefixes rather than pkg-config. So a consumer of this prefix must pass
   `-lgmp -lmpfr -lmpc` by hand. Verify rather than assume.
5. `topackage.md:59` records this as built with no caveats. Consistent, and
   consistent with the flag having been harmless.
6. `make -j1` is used throughout (`:13-15`) — correct.

**How to verify once built.**

- `lib/libmpc.a` exists; `include/mpc.h` exists.
- `share/doc/mpc-1.3.1/index.html` exists, proving `install-html` and
  `--docdir` both took. The directory name is a direct check of risk 2.
- `$OBJDUMP -f lib/libmpc.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libmpc.a | grep -cw mpc_add` non-zero.
- `llvm-nm -u lib/libmpc.a | grep -c 'mpz_\|mpfr_'` must be non-zero, proving
  it really links against this tree's GMP and MPFR rather than something else.
- `lib/libmpc.so` presence: if it exists, the build is shared, which would mean
  mpc's default is not static on some system and the ignored
  `--disable-static` has stopped being harmless. Worth checking explicitly.
- **Read the configure log for `unrecognized options: --disable-static`.**
  That one line settles risk 1.
