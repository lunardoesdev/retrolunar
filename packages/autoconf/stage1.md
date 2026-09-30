# autoconf build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 2.72
- Build system: autotools (bootstrapped; the release ships a generated `configure` and a prebuilt `autoconf`)
- Installs: `bin/autoconf`, `bin/autoheader`, `bin/autom4te`, `bin/autoreconf`, `bin/autoscan`, `bin/autoupdate`, `bin/ifnames`; `share/autoconf/` (the data dir); **man pages from the release**, no `.pc`
- Requires: `m4` (exists), `autoconf@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | autoconf's own C parts (`bin/autoconf`, `autom4te`) use only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<errno.h>` and `lib/autom4te.c`'s ordinary C. It needs a working `m4` at *run* time, and `autoconf/generic.lua:1` requires the `m4` package; the binary is never executed during the build (the recipe just links and installs it). Nothing in the tree references `nl_langinfo`, `getgrent`, `argp_parse` or `scandir`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | No arch-conditional code. |
| x86_64-mingw | WILL BUILD | autoconf is portable C plus perl. The `configure` script itself is a `/bin/sh` script shipped by the release, and the recipe builds the seven named binaries only (`generic.lua:13`). |
| clang-native | WILL BUILD | Native; topackage.md:9 records Autoconf 2.72 as `[x]`. |

## API level notes

Not a factor. The recipe builds only the seven program targets, none of
which calls a POSIX extension introduced after API 21. The `m4` the
installed `autoconf` will *later* need is a separate package and a separate
question.

## Risks / what a reviewer should check

- **`--prefix="$PREFIX"` is deliberate and load-bearing** (`generic.lua:8`).
  autoconf's generated scripts embed the absolute data directory, and
  `$PREFIX` is the nest dir where the package will actually live, whereas
  `$OUT` is a per-build staging dir that the loader deletes (`trap 'rm -rf
  "$WORK" "$OUT"' EXIT`). The install is then re-pointed with
  `make -j1 prefix="$OUT" install` (`generic.lua:19`). If that pairing is
  broken, the installed `autoconf` looks for its `.m4` files in a directory
  that no longer exists.
- **`make -j1 .version` at `generic.lua:14`** is a hand-picked target. The
  `all` target would also want the info manuals; this one lets the recipe
  touch the shipped `man/*.1` files afterwards instead of needing
  help2man. If autoconf ever renames that target, the build stops with a
  bare "no rule to make target".
- **The `touch man/*.1` list at `generic.lua:17` is version-specific.** It
  names the seven 2.72 manuals by hand. A version bump that adds or renames
  a manual leaves the new one to be regenerated with help2man.
- **`config.h.in` does not exist in the autoconf tree** — autoconf has no
  `AC_CONFIG_HEADERS`. `generic.lua:10` still runs `touch ... config.h.in`,
  and `touch` on a missing file exits non-zero. The generated block is not
  `set -e`, so the failure is a printed error, not a build stop, and the
  next line still runs. This is a real (cosmetic) wart worth flagging.

## How to verify once built

- `bin/autoconf`, `bin/autom4te`, `bin/autoheader`, `bin/autoreconf`
- `share/autoconf/autoconf.texi` exists — the data dir the prefix baked in
- `grep -a datadir bin/autoconf` shows the `$PREFIX` path, **not** the
  staging dir
- `file bin/autoconf` shows an Android ELF for cross targets
