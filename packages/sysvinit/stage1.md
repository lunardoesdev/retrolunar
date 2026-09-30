# sysvinit build forecast — BLOCKED on Android

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.14
  (`github.com/slicer69/sysvinit/releases/download/3.14/sysvinit-3.14.tar.xz`)
- Build system: **plain make** — there is no `configure`; `generic.lua:6-7`
  runs bare `make` then `make install ROOT="$OUT" usrdir=`
- Would install: `sbin/init`, `sbin/kill`, `sbin/last`, `sbin/mesg`, `sbin/sulogin`,
  `sbin/wall`. No library, no `.pc`.
- Requires: `sysvinit@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `sys/kd.h` is absent from the NDK sysroot. |
| aarch64-android24 | **WILL NOT BUILD** | Same; not an API-level gap. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | WILL NOT BUILD | mingw-w64 has no `sys/kd.h` and no `linux/` at all; sysvinit is Linux/BSD-only. |
| clang-native | WILL BUILD | glibc has `sys/kd.h` with `struct kd_type`, `kd_type_t` and `KIOCGWINSZ`. |

**API level notes.** `topackage.md:77` records "SysVinit 3.14 (blocked: Android
NDK sysroot lacks sys/kd.h required by init.c)". Confirmed: there is no
`sys/kd.h` anywhere in the NDK 28.2 sysroot, so **all four Android rows fail
identically regardless of API level** — this is a header-availability wall, not
one of the API-21/24/26/28/35 symbol gates. `init.c` includes it for
`KIOCGWINSZ`, used to size the console window; the header is Linux-specific and
Bionic has never had a use for it.

**Risks / what a reviewer should check.**
1. **This is the one recipe in the shard with no `./configure` at all**, so
   there is no autotools timestamp guard and none is needed
   (`generic.lua:6-7`). The `ROOT="$OUT" usrdir=` form is the classic sysvinit
   install invocation and is correct for this project's `$OUT` convention.
2. **No `Makefile` line ordering problem**, but note that `make` here is a
   bare invocation, which serialises by default and satisfies AGENTS.md's
   single-job rule by default rather than by intent.
3. **Beyond `sys/kd.h`, sysvinit has other Bionic exposures that would be the
   next wall**: `init.c` and `shutdown.c` use `setsid`, `kill(-1, SIGTERM)`,
   `reboot(RB_AUTOBOOT)` and `sync()`, and the login path wants
   `getpriority`/`setpriority` and a utmp/wtmp record. None of these are
   API-21 blockers individually, but `RB_AUTOBOOT` and the `linux/reboot.h`
   constants are another Linux-only header. So fixing `sys/kd.h` alone would
   not make this build on Android — worth recording so nobody books it as a
   one-line fix.
4. `shutdown.c` also does a `PATH`-walking search for a shutdown binary, which
   is fine at build time (never executed).

**How to verify once built (valid only for `clang-native`).**
- `sbin/init`, `sbin/kill`, `sbin/last`
- `file sbin/init` on clang-native → `ELF 64-bit LSB executable, x86-64`
- `strings sbin/init | grep -m1 sysvinit`
- No `.pc` expected; `sbin/` rather than `bin/` is the sysvinit convention and
  is correct here since `usrdir=` is emptied