# diffutils build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 3.12
- Build system: autotools
- Installs: `bin/diff`, `bin/cmp`, `bin/diff3`, `bin/sdiff`; `info/diffutils.info`; man pages from the release; **no library, no `.pc`**
- Requires: `diffutils@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | topackage.md:18 records "blocked: src/system.h needs `<stdbit.h>`, absent in the NDK", and I confirmed it: `usr/include/stdbit.h` does not exist in the NDK r28b sysroot. `<stdbit.h>` is the C23 header for `stdc_leading_zeros`/`stdc_trailing_zeros`/`stdc_bit_width` etc. diffutils 3.12's `src/system.h` includes it unconditionally, so `src/system.h` cannot be preprocessed and nothing that includes it compiles. |
| aarch64-android24 | **WILL NOT BUILD** | Same header, same absence. `<stdbit.h>` is not an API-level question: it arrived in Android's headers with a much later NDK, not at a lower API level, so 24 and 35 fail identically. |
| aarch64-android35 | **WILL NOT BUILD** | Same. Raising the API level does **not** fix this one — the header is missing from the whole NDK sysroot, not guarded by `__INTRODUCED_IN`. This is the important distinction from the `nl_langinfo` (API 26), `mktime_z` (API 35) and `stderr` (API 23) blockers elsewhere in the backlog: those are `__INTRODUCED_IN` gates that a **new `aarch64-androidNN` system directory clears**, and this one is not a gate at all. **No new Android system unblocks diffutils.** Only an NDK that ships `<stdbit.h>` does, or a patch, which the no-patch rule forbids. That makes this a *harder* blocker than the API-level ones and is worth stating plainly. |
| x86_64-android35 | **WILL NOT BUILD** | Identical, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | mingw-w64 has no `<stdbit.h>` either (it is not a C23-era toolchain), so the same `#include` fails. |
| clang-native | **UNCERTAIN** | The host clang is 19/20-era and *does* ship `<stdbit.h>`, so the include resolves. Whether the rest of diffutils 3.12 then builds cleanly is a separate question I did not settle. Flagged rather than claimed. |

## API level notes

**The recorded blocker is real and I verified it, but the label in
topackage.md is subtly wrong in a way that matters.** topackage.md:18
files this under the API-level family of blockers. It is not one: Bionic
simply does not ship `<stdbit.h>` at any API level, so no new
`aarch64-androidNN` directory would unblock it. The only fixes are a newer
NDK (whose sysroot would need to gain the header) or patching `src/system.h`
to not include it, which the no-patch rule forbids. **That is a stronger
blocker than the API-level ones, and worth recording so nobody spends time
trying API 35 on it.**

## Risks / what a reviewer should check

- **The recipe has a `touch man/*.1` guard that this package may never
  reach** (`generic.lua:12`). It is correct and harmless, and it documents
  that someone understood the help2man problem — but since the build never
  reaches `make` on any Android target, the guard is currently untested in
  practice. Do not read it as evidence the recipe works.
- **`make -j1 -C src` before the full `make`** (`generic.lua:11`) exists so
  the shipped man pages stay newer than the built binaries and are not
  regenerated with help2man. That ordering trick is fragile: it depends on
  `make -C src` not touching `man/`, which holds for diffutils but is worth
  re-checking on a version bump.
- **The blocker is in `src/system.h`, which is included by essentially
  every source file**, so there is no "build only the tool that works"
  subset. This is an all-or-nothing package.

## How to verify once built

Not verifiable on any target in this repo. On a host with `<stdbit.h>`:

- `bin/diff`, `bin/cmp`, `bin/diff3`, `bin/sdiff`
- `share/man/man1/diff.1`
- `file bin/diff` → Android ELF *if and when* the NDK gains `<stdbit.h>`
- No library, no `.pc`
