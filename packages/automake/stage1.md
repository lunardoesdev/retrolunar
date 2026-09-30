# automake build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.18.1
- Build system: autotools (bootstrapped; the release ships a generated `configure` and a prebuilt `automake`)
- Installs: `bin/automake`, `bin/aclocal`; `share/automake-1.18/` (the data dir with the `.am` modules); **man pages from the release**, no `.pc`
- Requires: `autoconf` (exists, 2.72), `automake@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | automake 1.18 is entirely perl plus a tiny C helper (`src/compile` is a shell script, `lib/Automake/*.pm` is perl). The perl itself is not in the recipe's `require` list and does not need to be: the build compiles only `src/automake` and `src/aclocals`, both C programs using `<stdio.h>`/`<stdlib.h>`/`<string.h>` and `config.h`. Nothing touches `nl_langinfo`, `getgrent`, `argp_parse` or `scandir`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | No arch-conditional code. |
| x86_64-mingw | WILL BUILD | Same two C programs; the data dir is perl modules. The release's `configure` does not need to run perl at build time because `aclocal.m4` and `m4/amversion.m4` are shipped and touched at `generic.lua:11`. |
| clang-native | WILL BUILD | Native; topackage.md:10 records Automake 1.18.1 as `[x]`. |

## API level notes

Not a factor. The compiled surface is two small C programs with no POSIX
extension above API 21 in them. The perl interpreter automake needs at
*run* time is a separate package (`packages/perl`, `perl@native` for host
use) and a separate question.

## Risks / what a reviewer should check

- **`--prefix="$PREFIX"` then `make -j1 prefix="$OUT" install`**
  (`generic.lua:9`, `:14`) is the same deliberate two-step as autoconf: the
  perl modules embed their absolute directory, and `$OUT` is deleted on
  success by the loader's EXIT trap. Breaking the pairing yields an
  installed `automake` whose `@Automake::` modules are missing.
- **`touch m4/amversion.m4` at `generic.lua:11` is a version-specific
  filename.** It exists to stop automake regenerating the version macro
  from git. A major version bump that renames or removes it makes `touch`
  fail — a printed error, not a build stop, since the block is not `set -e`.
- **Same `config.h.in` wart as autoconf**: automake has no
  `AC_CONFIG_HEADERS`, so `generic.lua:12` touches a file that does not
  exist. Cosmetic, but it is noise in the log and worth a fix.
- **No `perl` in the require list.** The build does not need one, but an
  installed `automake` does. Nothing here fails because of that; it just
  means the package is only usable alongside `packages/perl`.

## How to verify once built

- `bin/automake`, `bin/aclocal`
- `share/automake-1.18/Automake/*.pm` exists — the data dir
- `grep -a datadir bin/automake` shows the `$PREFIX` path, not the staging dir
- `file bin/automake` shows an Android ELF for cross targets
