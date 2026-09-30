# sed build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.10 (`ftp.gnu.org/gnu/sed/sed-4.10.tar.xz`)
- Build system: **autotools** — `./configure` at `generic.lua:6`
- Installs: `bin/sed`, `bin/sed.exe`-free POSIX build, `share/info/sed.info`
  (a C program). **No library, no headers, no pkg-config file.**
- Requires: `sed@source` only (`generic.lua:1`). No package dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:6` passes bare `$AUTOCONF_CONFIGURE_FLAGS`, i.e. `--host/--build/--prefix` from `packages/aarch64-android21/generic.lua:103-105` and nothing else. sed 4.10 is plain C99; it uses `ioctl`, `tcgetattr`, `sigaction`, `getpwnam`, `glob` and `fnmatch`. Bionic has all of those at API 21. Nothing in `lib/` needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | sed's `configure` has a `MINGW` branch and its `win32/` compatibility files; `--host=x86_64-w64-mingw32` from `packages/x86_64-mingw/generic.lua:54-56` selects it. |
| clang-native | WILL BUILD | Native; no extra flags needed. |

**API level notes.** **No new wall.** The AGENTS.md:368 list
(`stderr` as a real symbol, `POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`,
`mblen`, `getpass`, `O_BINARY`) does not contain anything sed 4.10 uses. The
one item worth naming because it is adjacent: Bionic's `stderr` exists as a
macro-backed variable rather than a linkable symbol, and AGENTS.md records that
as an API-21 wall — but sed only *writes* to `stderr` via `<stdio.h>`, never
takes its address as an extern, so the wall does not apply.

**Risks / what a reviewer should check.**
1. **`make` at `generic.lua:9` has no `-j1`.** Every other recipe in this tree
   spells out `make -j1` or `cmake --build ... --parallel 1`; a bare `make`
   serialises by default so the build is still single-job, but the rule in
   AGENTS.md ("`make -j1` or the build tool's equivalent single-job option")
   is met by default rather than by intent. Same observation applies to the
   `make` at `shadow/generic.lua:9`, `sysklogd/generic.lua:9`, `tar`, `texinfo`,
   `util-linux` and `xz`. Cosmetic, not a correctness issue.
2. **The recipe is bare.** No `--disable-nls`, no program selection. sed builds
   `bin/sed` plus the `sed-help` helper and the Info manual. That is fine, but
   a reviewer should confirm the Info build does not need makeinfo from this
   prefix — it does not, since sed ships a pre-built `.info` and only rebuilds
   it when the sources are newer.
3. **Version 4.10 is current** (released 2023; the 4.9 series is the previous
   line), so no upgrade pressure.

**How to verify once built.**
- `bin/sed`, `share/info/sed.info`; no `lib/lib*.a` and no `.pc` — their
  absence is correct, not a failure
- `file bin/sed` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for
  Android <level>`
- `llvm-objdump -f bin/sed | head` → `elf64-littleaarch64` on aarch64 targets
- `bin/sed --version` cannot be run (target binary; emulation is forbidden) —
  check the string statically instead:
  `strings bin/sed | grep -m1 'GNU sed'`