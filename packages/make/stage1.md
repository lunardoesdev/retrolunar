# make build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.4.1 (matches the LFS pin)
- Build system: autotools
- Installs: `bin/make`, `share/info/make.info`, `share/man/man1/make.1`. No
  library, no headers, no `.pc`.
- Requires: `make@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe is a bare `./configure $AUTOCONF_CONFIGURE_FLAGS` with no switches (`:6`) — make needs none. The one thing worth watching is `src/`: make 4.4 is a C program that uses `fork`/`execvp`/`waitpid` and, on systems that have it, `posix_spawn`. Bionic has `fork`/`execvp` at every level; `posix_spawn` is `__INTRODUCED_IN(28)` (verified: `$SYSROOT/usr/include/spawn.h:60`), and make guards that path with a configure test, so it falls back to `fork`/`exec` below 28. That is a degradation, not a failure. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above, and the fastest spawn path is available here. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | GNU make on mingw is well-trodden; make has its own job-server and uses `_spawnvp` from the CRT there. |
| clang-native | WILL BUILD | As above; native host. |

**API level notes.** The API level is a *performance* variable here, not a
correctness one, and it is worth contrasting with `ninja` — see risk 1.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **This package is the sharpest contrast in the shard with the `ninja`
   blocker, and the pair is worth reading together.**
   `topackage.md:62` records ninja as blocked: *"Android 24 NDK hides
   posix_spawn APIs introduced in API 28."* I confirmed that gate directly.
   Make calls `posix_spawn` **behind a configure test with a `fork`/`exec`
   fallback**; ninja calls it **unconditionally**. So the same platform fact
   blocks one and not the other. That is not luck — it is the difference
   between a portable program and one that assumed. A reviewer should hold
   this in mind before treating "API 28+" as a general unblock rule.
2. **make is a build tool installed into a target prefix, which is odd but
   deliberate** in this tree: the Android systems' `$CMAKE_FLAGS` deliberately
   pin `CMAKE_MAKE_PROGRAM=$(command -v make)` precisely so cmake uses the
   *host* make rather than `$PREFIX/bin/make`, which would be a target binary
   (AGENTS.md:311-314, and the comment at
   `aarch64-android24/generic.lua:127-130`). So the target make exists but is
   never used by the build itself. Worth knowing so nobody "simplifies" that
   `CMAKE_MAKE_PROGRAM` line.
3. **`make` at `:9` is not `make -j1`.** For a package that *is* make, this is
   the one recipe where that is least concerning, but it is still a rule
   deviation and it is recursive here: make spawning make jobs in parallel is
   exactly what the serial-build rule is trying to prevent.
4. **`topackage.md:54` records this as built** with the exact `file` output for
   `bin/make`. Consistent, and it is a good reference string to compare
   against.
5. No switches at all in the recipe. That is correct for make — but it means
   the docs (`make.info`) are built by the top-level make, and GNU make's info
   build does not self-bootstrap the way m4's did. No no-emulation risk here.

**How to verify once built.**

- `bin/make` exists; `share/info/make.info` and `share/man/man1/make.1` exist.
- `file bin/make` reports `ELF 64-bit LSB pie executable, ARM aarch64, for
  Android 24, built by NDK r28c` — the exact string `topackage.md:54` records.
- `$OBJDUMP -f bin/make` shows the target machine.
- `llvm-nm --undefined-only bin/make | grep -cw posix_spawn` is the direct
  check of the API-level note: **1** on android35 (the fast path compiled in),
  **0** on android21/24 (the fallback was selected). This is the single most
  informative check in this file.
- `llvm-nm --undefined-only bin/make | grep -cw 'fork\|execvp'` must be
  non-zero at every API level — that is the fallback that keeps it working.
- **Do not run `bin/make`.** It is a target binary.
