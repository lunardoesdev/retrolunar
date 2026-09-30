# pkgconf forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.0.7 (GitHub release asset, `.tar.xz`)
- Build system: autotools
- Installs: `bin/pkgconf`, the `pkgconf.pc` self-descriptor, and the man page.
  No library, no headers.
- Requires: `pkgconf@source` only.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `nl_langinfo`, exactly as for `less`. I verified the gate: `$SYSROOT/usr/include/langinfo.h:97` declares it `nl_langinfo(nl_item) __INTRODUCED_IN(26)`, so at API 21 the declaration is invisible and the call does not compile. Recorded at `topackage.md`. |
| aarch64-android24 | **WILL NOT BUILD** | Same; still below 26. `topackage.md` records this as the blocker: *"Bionic introduced nl_langinfo in API 26; API24 compilation fails"*. |
| aarch64-android35 | WILL BUILD (compile) | At API 35 the declaration is visible. pkgconf's own configure probes for `nl_langinfo`, so on a system where it is absent the probe should simply say "not available" — **but the recorded evidence says the API-24 failure is a compilation failure, not a configure probe**, which means the call is *not* behind a `HAVE_NL_LANGINFO` guard in 3.0.7. Worth confirming in the build log. |
| x86_64-android35 | WILL BUILD (compile) | As above. |
| x86_64-mingw | UNCERTAIN | The `nl_langinfo` wall is a Bionic one and does not apply. pkgconf on Windows is normally built as MSYS2 tooling, not as a PE binary. What would settle it: whether `./configure` accepts the target and whether the code compiles. |
| clang-native | WILL BUILD | glibc declares `nl_langinfo` unconditionally. |

**Blocker, faithfully recorded.** `topackage.md` records pkgconf 3.0.7 as
blocked with the same root cause as `less` (685) and `gawk`: **Bionic
introduced `nl_langinfo` in API 26, so API-24 compilation fails.** The entry
is accurate and names the API level, which is more precise than the entries
for `kbd`/`kmod` (which name a symbol absent at *every* level). The distinction
matters: **an `android26`-or-later target would fix this package**, and this
tree has none below 35.

**API level notes.** The cleanest divider in the shard, alongside `less`:
**21 and 24 fail, 35 compiles.** The gate is `__INTRODUCED_IN(26)` at
`langinfo.h:97`. Neither `armv7a-*` nor `i686-*` changes it, because the guard
is API-level, not ABI-level.

**Risks / what a reviewer should check.**

1. **pkgconf is a *host* tool, and this is the one package in the shard where
   that matters most.** Every system in this tree exports
   `PKG_CONFIG_LIBDIR` and relies on a **host** `pkg-config`/`pkgconf` to read
   `.pc` files. `packages/aarch64-android24/generic.lua:83-87` sets
   `PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig;…"` — and that is read by a *host*
   binary, because a target binary must never be executed here. So the
   `bin/pkgconf` this recipe installs into `$PREFIX/bin` is **not** what builds
   the tree. Installing it on the target is of niche value. Worth stating so
   nobody adds `require("pkgconf")` to a recipe expecting it to provide the
   build-time pkg-config.
2. **The compile-vs-probe question in the android35 row is the open one.**
   If pkgconf 3.0.7's `nl_langinfo` call *is* properly guarded by a configure
   check, then the API-24 failure recorded in `topackage.md` must have a
   different cause, and the entry's root-cause attribution would be wrong.
   **What would settle it: read `main.c`/`parser.c` for the call site and see
   whether it sits behind `#ifdef HAVE_NL_LANGINFO`.** That is a one-file read
   and it either confirms or corrects the recorded blocker.
3. **`less` and `pkgconf` share a root cause, and so does `gawk`** which is
   also in the backlog. All three would be fixed by a single
   `aarch64-android26`-or-later target. That is a tree-level observation worth
   raising, and it is cheaper than any patching.
4. **Correcting the root cause — the recorded blocker names the right symbol
   but the wrong mechanism, and a reviewer's correction of it was only half
   right.** `topackage.md` attributes the failure to `nl_langinfo`. That is
   the right symbol, but the call is reached through a fallback rather than a
   bare unguarded use, and the distinction decides whether the package is
   fixable. In `libpkgconf/fragment.c:1093-1107`:
   ```c
   #if HAVE_DECL_NL_LANGINFO_L
       cached = codeset_is_utf8(nl_langinfo_l(CODESET, loc));
   #else
       cached = codeset_is_utf8(nl_langinfo(CODESET));
   #endif
   ```
   The guard is `HAVE_DECL_NL_LANGINFO_L` (probed at `configure.ac:36`) — not
   `HAVE_NL_LANGINFO` — and it covers the **`nl_langinfo_l`** call only. The
   `#else` branch's `nl_langinfo(CODESET)` at **`fragment.c:1105` carries no
   guard of its own.** Both symbols are `__INTRODUCED_IN(26)` in Bionic
   (`langinfo.h:97` and `:98`), so below API 26 the probe yields
   `HAVE_DECL_NL_LANGINFO_L` = 0, the `#else` branch is taken, and the
   unguarded `nl_langinfo` is compiled. **So the WILL NOT BUILD verdict stands
   for android21/24, but the mechanism is the unguarded fallback — not a
   missing guard on the symbol the entry names, and not a
   `HAVE_NL_LANGINFO` macro that does not exist in this source.** What would
   settle a re-check: read `build/libpkgconf/config.h` for
   `HAVE_DECL_NL_LANGINFO_L` and confirm it is 0 on android24.
5. `topackage.md`'s entry is accurate as far as it goes. Its one omission is
   that it does not note that API 35 would work, which is the useful part.

**How to verify once built** (`clang-native` today, `aarch64-android35` once
this is revisited).

- `bin/pkgconf` exists; `share/man/man1/pkgconf.1` exists.
- `pkgconf.pc` is installed — this package's self-descriptor, and a nice touch
  worth confirming.
- `file bin/pkgconf` reports the target machine on a cross system.
- On `aarch64-android21`/`24`, the expected and recorded failure is a
  compile error naming `nl_langinfo`. **Before assuming that is the whole
  story, confirm the call site is unguarded** (risk 2) — if it is guarded, the
  real blocker is elsewhere and the entry needs correcting.
- On `clang-native`, `$OBJDUMP -f bin/pkgconf` shows `elf64-x86-64` and the
  binary is runnable — but it is still a target-prefix tool, so static
  verification is the convention here.
