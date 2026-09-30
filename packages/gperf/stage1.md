# gperf build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 3.3
- Build system: autotools
- Installs: `bin/gperf`; `share/info/gperf.info`; man page from the release; `lib/` convenience archive, not installed; **no `.pc`**
- Requires: `gperf@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | gperf 3.3 is C++ plus a small C library (`lib/`, the `GPERF` hash table used by the `--pic` output path). Its sources use the standard library and `<cstdio>`/`<cstring>`/`<cstdlib>`; the only POSIX surface is `getcwd` in `input.cc`/`output.cc` for the `-K` key file path, which is in Bionic at API 21. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral. |
| x86_64-mingw | **UNCERTAIN** | gperf has no `mingw*` branch that I saw, and it uses `getcwd` plus `<unistd.h>` in a couple of places. mingw-w64 provides both, so the build plausibly completes; the `-K` path handling uses `/` separators which is cosmetic on Windows. Flagged, not claimed. |
| clang-native | WILL BUILD | Native; topackage.md:33 records Gperf 3.3 as `[x]` with no blocker note. |

## API level notes

**21 is the floor and gperf clears it.** gperf is a *build-time* tool, so
it is always built for `clang-native` in practice — the
`gperf@native` requires in `packages/bison` and `packages/libseccomp` are
what actually exercise it. That means the Android rows are of academic
interest only, and the row that matters is `clang-native`.

## Risks / what a reviewer should check

- **This package is load-bearing for two others in its shard and one in
  adder C's.** `packages/bison/generic.lua:1` and
  `packages/bison/android.lua:1` both `require("gperf@native")`;
  `packages/libseccomp/generic.lua:1` does too. **If gperf does not build
  on `clang-native`, all three break.** That is the most important
  consequence of this file and it is not recorded anywhere else.
- **The touch guard is unusual and correct** (`generic.lua:9-12`):
  `find . -name 'aclocal.m4' | xargs touch` rather than the standard
  `touch aclocal.m4`, because gperf's `lib/` subdirectory has its own
  generated `aclocal.m4`. The comment says so. This is a genuine
  deviation from the AGENTS.md one-liner, justified and explained.
  `touch configure config.h.in` (no `aclocal.m4` in that list) is
  consistent with the reason.
- **The docs touch at `generic.lua:12`** — `doc/gperf.info doc/gperf.pdf
  doc/gperf.html doc/gperf.1` — is version- and file-set-specific. A gperf
  release that drops `doc/gperf.pdf` or adds a new manual would make
  `touch` fail on the missing name. Cosmetic (the block is not `set -e`),
  but brittle. Same class of wart as the `man/*.1` list in
  `packages/autoconf`.
- **`make install` with no flags** (`generic.lua:14`) is fine here, unlike
  `gettext`/`grep`/`gzip` where the omission is a serial-build violation.
  gperf is a single C++ program plus a small library, so the parallel
  default is not a practical problem — though it is still a deviation
  from the stated rule.
- **gperf installs no library**, so the `lib/` build is pure overhead in
  the prefix. Correct outcome, minor waste.

## How to verify once built

- `bin/gperf`
- `share/info/gperf.info`, `share/man/man1/gperf.1`
- `file bin/gperf` → x86_64 ELF on `clang-native`; an Android ELF if a
  target build is ever attempted
- **The check that matters for the shard:** with this package in
  `$NESTDIR/clang-native/bin`, `command -v gperf` from inside a generated
  build block must resolve there. That is what makes `bison` and
  `libseccomp` work
- No `.pc`; gperf is a program
