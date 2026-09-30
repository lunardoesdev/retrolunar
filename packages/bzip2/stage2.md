ACCEPT

# bzip2 1.0.8 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- bzip2's release tarball has **no autotools at all** — no `configure`, no
  `configure.ac`, no `aclocal.m4`, no `Makefile.in`. It ships a hand-written
  `Makefile`. So the absence of a `touch aclocal.m4 configure config.h.in` line
  is correct here rather than an oversight, and no autotools timestamp guard
  applies.
- The hand-written `Makefile` builds `bzip2`, `bunzip2`, `bzcat` and
  `libbz2.a`, and honours `CC`, `CFLAGS`, `LDFLAGS` and `PREFIX`/`prefix` from
  the environment, so the recipe's use of the system variables is sound.
- `make -j1` (or the equivalent) keeps the build serial.
- `require("bzip2@source")` names no missing package. No `@native` need.

## What the builder should confirm

- That the recipe passes `--prefix="$OUT"` (or `PREFIX="$OUT"`) to bzip2's
  `Makefile`, since a hand-written `Makefile` is exactly the case AGENTS.md
  warns about: it is not autoconf, so it rejects `--host`/`--build` and spells
  its variables its own way. The install must land in `$OUT`, not in
  `/usr/local`.
- `make install` on bzip2 installs into `$(PREFIX)/bin` and `$(PREFIX)/lib` and
  also `man` pages. If the recipe omits a man directory, that is fine; if it
  omits the prefix, that is a build failure.

## Carried to the build

- `bin/bzip2`, `bin/bunzip2`, `bin/bzcat` — `[ -x bin/bzip2 ] && [ -x bin/bunzip2 ] && [ -x bin/bzcat ]`; all three are installed by bzip2's `Makefile`.
- `lib/libbz2.a` — `llvm-objdump -f lib/libbz2.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A shared `libbz2.so*` would be unusual here; if one appears, check whether the recipe asked for it.
- `include/bzlib.h` — `[ -f include/bzlib.h ]`.
- `share/man/man1/bzip2.1` — `[ -s share/man/man1/bzip2.1 ]`, if the recipe installs man pages.
- No `.pc`; bzip2 ships none, and a missing `pkg-config --modversion bzip2` is correct.
- **Never run `bin/bzip2` or `bin/bunzip2`.**
