# kbd build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.10.0 (mirrors.edge.kernel.org `.tar.xz`)
- Build system: autotools
- Installs: `bin/` console tools (`setfont`, `setxkbmap`, `loadkeys`,
  `dumpkeys`, `kbdcomp`, `consoletrans`, `ctr`), `share/` data tables,
  `include/` headers. No `.pc`; kbd installs no library.
- Requires: `kbd@source` only. No package dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `src/libcommon/error.c:18` and `:35` use `program_invocation_short_name`, a glibc-ism. I verified the gap: `llvm-nm --defined-only` on the sysroot's `libc.a` gives **zero** matches for `program_invocation_short_name`, and no NDK header declares it. This is not an API-level gate — the symbol is absent at every level. Recorded at `topackage.md:43`. |
| aarch64-android24 | **WILL NOT BUILD** | Same. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | UNCERTAIN | `program_invocation_short_name` is not a Bionic problem here, but mingw-w64 does not provide it either (it is a GNU-ism, not a POSIX one). kbd is also heavily console-oriented and much of it is Linux-specific. What would settle it: one `./configure` under `x86_64-mingw` and a look at which sources it selects. |
| clang-native | WILL BUILD | glibc **does** provide `program_invocation_short_name` — it is a glibc extension. The package is a Linux-console tool, so natively it is exactly what it was written for. |

**API level notes.** The blocker is not API-gated, so **no Android API level
fixes it**. Raising the target to 35 changes nothing. The only fixes are
guarding the call site in upstream source (forbidden, AGENTS.md:28-29) or
shipping a shim. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The recipe's one thoughtful decision is still there and is correct.**
   `generic.lua:6-10` explains that LFS strips `resizecons` with `sed`, and
   that this recipe does **not** need to: `configure.ac:153-154` sets
   `RESIZECONS_PROGS=yes` only for i386/x86_64, and aarch64 falls through to
   the `[*]` case at `:155` which sets it to `no`. So `resizecons` is already
   excluded and the upstream source is left alone. That is exactly the right
   call — it removes a `sed` (which AGENTS.md forbids) by reading the
   configure logic instead of patching around it. A reviewer should re-check
   those three `configure.ac` lines if kbd is ever updated to a version where
   the arch condition changes.
2. **`--disable-vlock` is the only switch, and it is right**: vlock needs PAM,
   which is not in this prefix. But it is the *only* thing the recipe does
   about the platform, and the `program_invocation_short_name` wall is not
   addressed at all. So this recipe is honest about what it cannot fix.
3. **kbd is arguably the wrong package for this prefix at all.** It is a Linux
   virtual-console toolset; `loadkeys`/`setfont` manipulate console font maps
   and keymaps that do not exist on Android. Even if the symbol wall were
   solved, nothing on the target would call it. That is worth saying out loud
   before anyone spends effort on it.
4. `make` at `generic.lua:11` is not `make -j1` — a rule deviation from
   AGENTS.md:225-229, harmless in practice but worth normalising.
5. `topackage.md:43` names the blocker with file and line and it matches this
   reading. **The entry is accurate, not stale.**

**How to verify once built** (only `clang-native` today).

- `bin/loadkeys` and `bin/setfont` exist under `$NESTDIR/clang-native/`.
- `$OBJDUMP -f bin/loadkeys` shows `elf64-x86-64`.
- `nm bin/loadkeys | grep program_invocation_short_name` shows it as **U**
  (undefined, resolved from glibc) natively, and would show `U` with no
  resolution on Android.
- On Android, the expected and recorded failure is a compile error in
  `src/libcommon/error.c` naming `program_invocation_short_name`.
