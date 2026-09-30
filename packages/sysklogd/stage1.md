# sysklogd build forecast — BLOCKED on Android below API 26

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.7.2
  (`github.com/troglobit/sysklogd/releases/download/v2.7.2/sysklogd-2.7.2.tar.gz`)
- Build system: **autotools** — `./configure` at `generic.lua:6`, timestamp
  guard at `:7-8`
- Would install: `bin/logger`, `bin/logread`. No library, no `.pc`.
- Requires: `sysklogd@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `getsubopt` is undeclared at API 21. |
| aarch64-android24 | **WILL NOT BUILD** | Same — API 24 is still below the API-26 gate. |
| aarch64-android35 | WILL BUILD | `getsubopt` is declared and present. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | mingw-w64 provides `getsubopt`. |
| clang-native | WILL BUILD | glibc has had it for decades. |

**API level notes — the blocker, confirmed.**

`topackage.md:74` records "Sysklogd 2.7.2 (blocked: Bionic exposes getsubopt
starting API 26; API24 logger compile fails)". I confirmed the gate directly:
`sysroot/usr/include/stdlib.h:177` reads

```
int getsubopt(char **, char *const *, char **) __INTRODUCED_IN(26);
```

So the wall is exactly between API 24 and API 26, which is why
**android21 *and* android24 both fail and android35 passes**. The affected
source is `logger.c`, which parses `-t`/`-s` tag options with `getsubopt`; the
function is not behind any `#if` that the recipe could pre-empt, and
`sysklogd`'s `configure.ac` has no `--without-getsubopt` switch (the program
has one binary, `logger`, and that binary is the whole point of the package).
Note the backlog says "API24 logger compile fails" — correct, and my reading
adds that **API 21 fails identically**, so this is a two-row block, not a
one-row one.

**Risks / what a reviewer should check.**
1. **The recipe is unadorned and that is correct.** There is no upstream switch
   for the getsubopt dependency and the function is the program's core
   option-parsing primitive. Adding `ac_cv_func_getsubopt=yes` would only move
   the failure from compile to link.
2. `make` at `generic.lua:9` is bare (serialises by default); cosmetic, same
   as `sed`/`tar`/`shadow`.
3. **API 26 is not in this tree.** The Android system directories stop at 25
   (there is no `*-android26` — the list jumps `aarch64-android25` to
   `aarch64-android27`). So even though the gate is 26, there is currently no
   system that clears it: **every Android row in the table above is either 21,
   24 (fail) or 35 (pass), and 35 is the only one that does.** A project that
   wanted sysklogd at a mid-range API would need an `android26` system
   directory first — a system-level change, not a recipe change.

**How to verify once built (valid for android35 / mingw / native).**
- `bin/logger`, `bin/logread`
- `file bin/logger` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for
  Android 35`
- `llvm-objdump -f bin/logger | head` → `elf64-littleaarch64` on aarch64
- `strings bin/logger | grep -m1 sysklogd` for the version stamp
- No `.pc` expected. The binary cannot be run: no emulation.