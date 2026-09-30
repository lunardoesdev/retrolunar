# shadow build forecast — BLOCKED on Android

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.20.3
  (`github.com/shadow-maint/shadow/releases/download/4.20.3/shadow-4.20.3.tar.xz`)
- Build system: **autotools** — `./configure` at `generic.lua:6`, timestamp
  guard at `:7-8`
- Would install: `bin/*` (useradd, usermod, chpasswd, …), `etc/login.defs`,
  `lib/libshadow.la`. No pkg-config file.
- Requires: `shadow@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | Bionic has no `shadow.h`. |
| aarch64-android24 | **WILL NOT BUILD** | Same wall; it is a header-availability gap, not an API level. |
| aarch64-android35 | **WILL NOT BUILD** | Same wall. Bionic has never shipped `shadow.h`. |
| x86_64-android35 | **WILL NOT BUILD** | Same wall. |
| x86_64-mingw | WILL NOT BUILD, for a different reason | mingw-w64 has no `shadow.h` either, and shadow's `configure` treats a non-POSIX host as unsupported: it wants `getopt_long`, `crypt(3)` and a real passwd database. |
| clang-native | WILL BUILD | glibc has `shadow.h` and `libcrypt`. |

**API level notes.** `topackage.md:73` records "Shadow 4.20.3 (blocked:
Android Bionic lacks shadow.h required by configure)". I confirmed the gap is
real and is *not* an API-level one: I searched the NDK 28.2 sysroot
`usr/include/` and there is no `shadow.h` at any API level, so **21, 24 and 35
behave identically**. The same absence is worth naming precisely because
`packages/xml-parser/generic.lua:21` already reasons about it: "Bionic has no
crypt.h or shadow.h", and turns the shadow macros off with
`-D_I_CRYPT_H=0` on the make line. That is a legitimate *consumer* workaround
— a macro that guards an `#include` — and it is exactly the mechanism that
would make a `shadow.h` consumer work.

**Why the recipe cannot fix it.** `configure` needs `shadow.h` to *decide*
whether `getspnam`/`sgetpwent` exist, and shadow's own `lib/getdef.c`,
`lib/chpw.c` and friends include it. There is no `--without-shadow-header`
style switch: shadow treats it as mandatory POSIX. Passing a cache answer
(`ac_cv_header_shadow_h=yes`) would only move the failure to compile time.
AGENTS.md forbids both `sed`-ing a header into existence and patching
upstream, so blocked is the honest verdict.

**Risks / what a reviewer should check.**
1. **The recipe is unadorned and that is correct.** Unlike `util-linux`, where
   the recipe turns off optional features that hit Bionic gaps (see
   `packages/util-linux/stage1.md`), shadow has no optional feature that
   removes the `shadow.h` dependency. Nothing to add; the blocker is
   structural.
2. `make` at `generic.lua:9` is bare (serialises by default). Cosmetic, same
   as `sed` and `tar`.
3. shadow additionally wants `crypt(3)` for its password-hashing helpers, and
   **Bionic has no separate `-liconv`-style split but also no `crypt(3)` in
   libc at all**. Even if `shadow.h` were supplied, `libcrypt` would be the
   next wall. Worth recording so nobody treats a `shadow.h` shim as the last
   step.

**How to verify once built (valid only for `clang-native`).**
- `bin/useradd`, `bin/chfn`, `bin/chsh`, `etc/login.defs`
- `file bin/useradd` on clang-native → `ELF 64-bit LSB pie executable, x86-64`
- `strings bin/useradd | grep -m1 4.20.3`
- No `lib/pkgconfig/*.pc` is expected
- The Android rows cannot be verified because the build never completes; the
  evidence to record instead is the configure error naming `shadow.h`, which is
  what `topackage.md:73` already cites