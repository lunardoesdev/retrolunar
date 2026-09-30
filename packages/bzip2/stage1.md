# bzip2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.0.8
- Build system: **plain make** — upstream ships a hand-written `Makefile`, no configure
- Installs: `bin/bzip2`, `bin/bzip2recover`; `man/bzip2.1`; **no library, no `.pc`, no headers** (bzip2 has never exposed a C API)
- Requires: `bzip2@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `bzip2.c` and `bzlib.c` are portable C89 with only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<ctype.h>`, `<errno.h>`, `<unistd.h>` and `<sys/stat.h>`. The recipe hands make the toolchain explicitly (`generic.lua:8`: `CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"`) precisely because there is no configure to read them, which is the correct shape for a plain-makefile project. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | bzip2 is endian-neutral. |
| x86_64-mingw | WILL BUILD (moderate confidence) | bzip2's Makefile has no `mingw*` branch and does not define `O_BINARY`, so `bzip2recover` opens files in text mode. That is a correctness wart, not a build failure — `bzip2` itself only reads stdin/writes stdout, which is binary-safe on Windows. Moderate because I did not verify the Makefile's `install` target's assumptions about `man/` on a PE host. |
| clang-native | WILL BUILD | Native; topackage.md:15 records Bzip2 1.0.8 as `[x]`. |

## API level notes

Not a variable, and this is worth stating plainly: bzip2 predates almost
every Bionic gap the backlog records. It is the reference example of a
package that needs no platform knowledge at all. The recipe's only
system-specific content is passing `$CC`/`$CFLAGS`/`$LDFLAGS` to make,
because a plain Makefile has no other way to learn them.

## Risks / what a reviewer should check

- **The default make target runs the test suite** — `generic.lua:6` says so
  and names the two real targets to build instead. This is a load-bearing
  deviation from `make && make install`: `make` alone would run tests that
  shell out to the freshly built `bzip2` binary, which on a cross target
  means executing an aarch64 binary on this x86_64 host. If someone
  "simplifies" the recipe to plain `make -j1`, the build starts executing
  target binaries. That is the single most important thing to preserve here.
- **`PREFIX="$OUT"` on the install line** (`generic.lua:9`) is how this
  makefile learns its destination. Same silent-failure risk as binutils'
  `tooldir`: get it wrong and the tools install to `/usr/local`.
- **The two make invocations each repeat all four toolchain variables.**
  Verbose, but explicit, and correct.
- **No timestamp guard**, correctly — there is no `configure` to re-run.
- **`bzip2recover` is a rarely-used debugging tool** and gets installed on
  every system. Upstream has no flag to suppress it.

## How to verify once built

- `bin/bzip2`, `bin/bzip2recover`
- `share/man/man1/bzip2.1`
- `file bin/bzip2` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- No library and no `.pc`; bzip2 exposes no C API
- `readelf -h bin/bzip2` confirms the machine; do **not** run it here
