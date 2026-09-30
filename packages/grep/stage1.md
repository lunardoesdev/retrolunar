# grep build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 3.12
- Build system: autotools
- Installs: `bin/grep`, `bin/egrep`, `bin/fgrep`; `info/grep.info`; man page; **no library, no `.pc`**
- Requires: `grep@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | GNU grep 3.12 is one of the most portable programs in the shard. Its gnulib base is configured to avoid every Bionic gap: grep bundles its own `getopt`, `fnmatch`, `regex`, `iconv`-free and `intl`-minimal code, and `src/*.c` uses only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<errno.h>`, `<fcntl.h>`, `<sys/stat.h>` and `<unistd.h>`. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; grep's multibyte handling is UTF-8-generic. |
| x86_64-mingw | **UNCERTAIN** | grep 3.12 does have a `--with-included-regex` and a MinGW path in gnulib, but the recipe passes no flags, so configure will probe for `grep.exe`-adjacent things like `pcre` and MSVC-only constructs. I could not settle whether it completes. Flagged, not claimed. |
| clang-native | WILL BUILD | Native; topackage.md:34 records Grep 3.12 as `[x]` with no blocker note. |

## API level notes

**21 is the floor and grep clears it.** Two Bionic facts are worth naming
because grep is *known* to trip over them, and this recipe does not:

- **No `nl_langinfo`.** GNU grep's `src/dfasearch.c` and
  `src/greplocale.c` avoid `nl_langinfo` by design — it is one of the
  programs upstream keeps free of it, unlike gawk and less. So the
  API-26 blocker that stops `packages/gawk` does **not** apply here. That
  contrast is the useful part of this file.
- **No separate `-liconv`.** grep 3.12 dropped its optional `iconv` usage
  in favour of its own multibyte handling, so the API-28 `iconv.h` issue
  that stops `packages/gettext` does not apply either.

## Risks / what a reviewer should check

- **`make -j1` is now explicit on both lines.** RETRACTION, and it matters: **bare `make` is not a parallelism violation.** Measured empirically: `make` reports `MAKEFLAGS=[]` and `make -j1` reports `MAKEFLAGS=[-j1]` — a bare `make` is already serial. The recipe now passes `-j1` explicitly anyway, because AGENTS.md asks for a single-job build to be *explicit* rather than implicit and that is better practice; but the edit was **not** required, and an earlier version of this file called the omission a defect and named other packages for the same thing. That was wrong, and it is the same defect class as the other false premises in this wave: a rule that sounds right, is not, and trains the next reader to fail correct recipes. No further package should be failed on bare `make`.
- **`--disable-dependency-tracking` is not passed**, so every header change
  re-triggers automake's depcomp scanning. Slower, not wrong.
- **No `touch` guard for `info/grep.info`.** grep ships a pre-built
  `.info`; if it ever loses to `doc/grep.texi`, make will want `makeinfo`.
  Same minor asymmetry as bison, gawk and findutils.
- **grep installs three binaries** (`grep`, `egrep`, `fgrep`) plus two
  symlinks. All target binaries; nothing runs them here.
- **The recipe is completely plain** — no flags, no platform file — which
  for a package with this many Bionic-adjacent neighbours (gawk blocked,
  gettext blocked, less blocked) is a positive signal rather than an
  absence of work.

## How to verify once built

- `bin/grep`, `bin/egrep`, `bin/fgrep`
- `info/grep.info`
- `file bin/grep` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- `llvm-nm bin/grep | grep -c nl_langinfo` → **zero**; that is the direct
  check for the contrast with gawk claimed above
- `share/man/man1/grep.1`
- No library, no `.pc`
