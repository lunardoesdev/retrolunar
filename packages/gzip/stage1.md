# gzip build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.15 (LFS pins 1.14; the recipe uses the newer stable)
- Build system: autotools
- Installs: `bin/gzip`, `bin/gunzip`, `bin/zcat`, `bin/zless`/`zmore` (symlink), `bin/zdiff`, `bin/zcmp`, `bin/zdiff`; `info/gzip.info`; man page; **no library, no `.pc`**
- Requires: `gzip@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | gzip 1.15 is a self-contained C program plus its bundled gnulib. Its own sources (`gzip.c`, `gunzip.c`, `zcat.c`, `gzip.h`, `lib/`), `src/util.c` and `src/timestamp.c` use only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<errno.h>`, `<fcntl.h>`, `<unistd.h>`, `<sys/stat.h>` and `<utime.h>`. gnulib's `fchmod`/`futimens`/`utimensat` shims are compile-time, not link-time. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; DEFLATE's bit packing is explicit. |
| x86_64-mingw | **UNCERTAIN** | gzip 1.15's configure does have a `mingw*` branch (it has for decades), and gnulib handles the Windows stat/utime differences. The recipe passes no flags, so configure will take its defaults. Plausible but unverified. Flagged, not claimed. |
| clang-native | WILL BUILD | Native; topackage.md:37 records Gzip 1.15 as `[x]`, "LFS 1.14; latest stable". |

## API level notes

**21 is the floor and gzip clears it.** gzip is worth holding up as the
counter-example to the "GNU program → Bionic wall" intuition in this
backlog: gawk is blocked at 21 by `nl_langinfo`, gettext at 21 by
`iconv.h`, and gzip has no wall at all, because its gnulib base is small
and its feature set is correspondingly narrow.

## Risks / what a reviewer should check

- **`make -j1` is now explicit on both lines.** RETRACTION, and it matters: **bare `make` is not a parallelism violation.** Measured empirically: `make` reports `MAKEFLAGS=[]` and `make -j1` reports `MAKEFLAGS=[-j1]` — a bare `make` is already serial. The recipe now passes `-j1` explicitly anyway, because AGENTS.md asks for a single-job build to be *explicit* rather than implicit and that is better practice; but the edit was **not** required, and an earlier version of this file called the omission a defect and named other packages for the same thing. That was wrong, and it is the same defect class as the other false premises in this wave: a rule that sounds right, is not, and trains the next reader to fail correct recipes. No further package should be failed on bare `make`.
- **gzip 1.15 is newer than LFS's 1.14 pin and newer than most
  distributions' 1.12**, and it is the first release to use the *new* zlib
  replacement in-tree (it bundles a minimal `lib/` with its own inflate,
  rather than linking zlib). That is why `require("zlib")` is absent and
  correct here. Worth a reviewer's confirmation, because a reader
  accustomed to older gzip would expect a zlib dependency and might "fix"
  the recipe.
- **No `touch` guard for `info/gzip.info`.** Same minor asymmetry as
  `grep`, `gawk`, `bison`, `findutils`, `diffutils`. The shard has five of
  these, and only `diffutils` and `autoconf` guard theirs.
- **Six installed binaries** (`gzip`, `gunzip`, `zcat`, `zless`, `zdiff`,
  `zcmp`), all target binaries. Nothing runs them here. `zless` needs
  `less`, which is a separate package on adder C's shard and is currently
  blocked (topackage.md:45) — **so `zless` in this prefix would be a
  program whose `PAGER` counterpart does not exist.** Harmless, but worth
  noting.
- **The recipe is entirely plain**, no flags, no platform file. For a
  program this portable that is the right outcome, not an absence of work.

## How to verify once built

- `bin/gzip`, `bin/gunzip`, `bin/zcat`
- `info/gzip.info`, `share/man/man1/gzip.1`
- `file bin/gzip` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- `readelf -d bin/gzip | grep NEEDED` should show only `libc.so` (and
  `libm.so` if the systems' `-lm` is honoured) — **no `libz.so`**, which
  is the direct check that 1.15's in-tree zlib is being used
- No library, no `.pc`
