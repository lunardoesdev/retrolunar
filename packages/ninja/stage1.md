# ninja build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.13.2 (git tag archive)
- Build system: **python build script, no autotools and no cmake** —
  `configure.py` generates a `build.ninja` and the recipe runs `ninja -j1`.
  So the autotools timestamp guard does not apply.
- Installs: `bin/ninja`, a single static target executable. No library, no
  headers, no `.pc`.
- Requires: **none.** `ninja@source` only — note it needs no `require()`,
  because it is built by a python script, and the system provides `python3`
  and a host `ninja` as tools.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `posix_spawn` is `__INTRODUCED_IN(28)`. I verified both halves in the NDK: `$SYSROOT/usr/include/spawn.h:60` declares `posix_spawn(...) __INTRODUCED_IN(28)`, and `llvm-nm` on the sysroot's `libc.a` finds one match. Ninja calls it **unconditionally** — unlike `make`, which guards the same call with a configure test and falls back to `fork`/`exec`. So there is no build-system-level way to avoid it in this recipe. Recorded at `topackage.md:62`. |
| aarch64-android24 | **WILL NOT BUILD** | Same; still below 28. |
| aarch64-android35 | WILL BUILD | At API 35 the declaration is visible and the symbol is in libc. The `CFLAGS="$CXXFLAGS"` line at `generic.lua:7` is the other thing to check: ninja's sources are C++, and `configure.py` merges `CFLAGS` into its C++ flags, so passing the system's `$CXXFLAGS` (which carry `-I$PREFIX/include` and `-DANDROID` but *not* the C-only `-isystem $SYSROOT/usr/include`) is the documented way to avoid the libc++ include-order breakage AGENTS.md:245-248 describes. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | **WILL NOT BUILD** | Different reason: ninja's process handling is POSIX, and `posix_spawn` has no Winsock/PE equivalent in ninja. Even the API question does not arise. Ninja does not build for Windows with its own build script. |
| clang-native | WILL BUILD | As above; native glibc has `posix_spawn` unconditionally. |

**API level notes — the cleanest in the shard.** The blocker is exactly
`posix_spawn`, so the divider is **21 and 24 fail, 35 compiles.** The
`_POSIX_SPAWN` availability is a compile-time property, not a runtime one, so
there is no partial success. This is the same class as `less` (API 26) and
unlike `kbd`/`kmod`/`inetutils` (symbols Bionic lacks at *every* level).
**So `aarch64-android35` genuinely unblocks this package** — worth knowing
before anyone reads `topackage.md:62` and concludes it is dead.

**Risks / what a reviewer should check.**

1. **The `CFLAGS="$CXXFLAGS"` override is the load-bearing line and it is
   correct, with a comment saying why** (`:6-7`). ninja's `configure.py` is a
   build-time Python script, so a host `python3` is required — and `/usr/bin/python3`
   exists on this host, so that part is fine. But the fact that the build
   depends on a *host* `python3` and a *host* `ninja` with no recipe-level
   check is worth recording: a builder on a host without `ninja` installed
   would fail at `ninja -j1` with a confusing error.
2. **The recipe does not pass `--bootstrap`**, so ninja self-bootstraps using
   the *host* ninja, then rebuilds itself with the target compiler. That is
   the standard and correct flow. Worth confirming in the log: there should be
   two compile passes, and the second must be with the cross compiler. A build
   that produced a *host* binary would be the failure mode to look for —
   `$OBJDUMP -f bin/ninja` settles it.
3. **`-DANDROID` comes from the system's `$CXXFLAGS`**
   (`aarch64-android24/generic.lua:69`), and ninja's `configure.py` also emits
   its own `--platform=linux` at `:7`. On Android that combination is what
   produces a Linux-platform ninja, which is the intent. Nothing to fix, but
   worth knowing the two settings are independent.
4. **`topackage.md:62` is accurate and precisely stated** — *"Android 24 NDK
   hides posix_spawn APIs introduced in API 28"*. It is correct, and it does
   not mention that API 35 would work. That omission is the useful finding
   here, not a defect in the entry.
5. **`ninja` in a target prefix is a build tool**, same category as `make` and
   `meson`. Nothing on the target runs it.

6. **DEFERRED, not blocked — this package is buildable today.** `posix_spawn`
   is `__INTRODUCED_IN(28)` (`spawn.h:60`), and `aarch64-android35` exists in
   this tree, so `ninja` **builds on `aarch64-android35` right now**; only
   `android21` and `android24` sit below the line. `topackage.md:62` reads as
   though the package were dead, which understates it: the blocker is a
   two-API-level gap, not a missing platform facility. A reviewer compiled
   probes and confirmed API 26/28/35 all succeed while 21/24 fail.

**How to verify once built** (on `aarch64-android35` or `clang-native`).

- `bin/ninja` exists.
- `file bin/ninja` reports
  `ELF 64-bit LSB pie executable, ARM aarch64, for Android 35, built by NDK r28c`
  on the Android system.
- `$OBJDUMP -f bin/ninja` shows the target machine — **this is the check that
  catches a failed self-bootstrap** (a host binary would show
  `elf64-x86-64`).
- `llvm-nm --undefined-only bin/ninja | grep -cw posix_spawn` must be
  non-zero on API 35, and the link must resolve — that is the symbol the whole
  blocker is about.
- On `aarch64-android21`/`24`, the expected and recorded failure is a compile
  or link error naming `posix_spawn`. Anything else is a new problem.
- **Do not run `bin/ninja`.**
