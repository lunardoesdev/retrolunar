# less build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 685 (greenwoodsoftware.com, the current stable)
- Build system: autotools
- Installs: `bin/less`, `bin/lesskey`, `share/man/man1/less.1`. No library, no
  headers, no `.pc`.
- Requires: `less@source`, `ncurses` (exists). ncurses is **not** passed to
  configure explicitly — the recipe relies on `less`'s own `--with-termcap`
  autodetection finding it through the system search paths.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `charset.c:432` calls `nl_langinfo`. I verified the gate in the NDK sysroot: `$SYSROOT/usr/include/langinfo.h:97` declares it as `nl_langinfo(nl_item) __INTRODUCED_IN(26)`, inside the API-26 availability guard. At API 21 the declaration is not visible, so the call does not compile. `topackage.md:45`. |
| aarch64-android24 | **WILL NOT BUILD** | Same — still below 26. |
| aarch64-android35 | WILL BUILD (compile) | At API 35 `nl_langinfo` is declared. The *rest* of less is portable C, and the recipe does nothing arch- or platform-specific that could fail. What a run would still need is ncurses from the prefix, which is there. |
| x86_64-android35 | WILL BUILD (compile) | As above; same API level, no 32/64-bit difference in less. |
| x86_64-mingw | UNCERTAIN | The `nl_langinfo` wall is a Bionic one and does not apply. But less on Windows needs its own console handling, and `--with-termcap` will look for a terminfo database that a mingw prefix may not have. What would settle it: one `./configure` under `x86_64-mingw`. The compile itself should be fine. |
| clang-native | WILL BUILD | glibc declares `nl_langinfo` unconditionally, and the host is the platform less was written for. This is the one system that certainly works today. |

**API level notes.** This is the cleanest API-level story in the shard, and the
verdict table divides exactly where the guard does: **API 21 and 24 fail,
API 35 compiles.** `nl_langinfo` is `__INTRODUCED_IN(26)` (verified at
`langinfo.h:97`), so anything at 26 or above is fine — but this tree has no
API-26-or-higher Android system except 35, so in practice the divider is
21/24 versus 35. `armv7a-android*` and `i686-android*` match `aarch64-*`
because the guard is API-level, not ABI-level.

**A finding worth recording: the recorded blocker is still exact, and the
recipe does not pretend otherwise.** `generic.lua:9` is a bare
`./configure $AUTOCONF_CONFIGURE_FLAGS` with **no** switch attempting to work
around `nl_langinfo`. `topackage.md:45` says the only fixes are raising the
API level or patching the call site, both out of scope. The recipe and the
entry agree.

**Risks / what a reviewer should check.**

1. **The most interesting fact about this package: it is the only one in the
   shard where raising the target API level genuinely fixes it.** kbd, kmod and
   inetutils are blocked on symbols Bionic does not have *at any* level;
   less is blocked on one that is merely gated. So if someone wants a working
   `less`, the honest fix is an `aarch64-android35` target, not a source
   patch. `topackage.md:45` says exactly this ("the only fixes are raising the
   target API level or patching the call site").
2. **This is a pager, and a pager is a poor fit for this prefix** — worth
   saying before anyone spends effort. Nothing on the target would use
   `bin/less`; it is a terminal program for a phone.
3. `ncurses` is required but its path is not given to configure. less's
   `configure` will look for `libncurses` via its own search, and the system
   `LDFLAGS`/`CPPFLAGS` point at `$PREFIX` (so `-I$PREFIX/include` finds
   `ncurses.h`). The link name is the risk: this tree's ncurses installs
   `libncursesw.a` plus a `libncurses.so` symlink
   (`packages/ncurses/generic.lua:30`), and less's `--with-termcap` probe asks
   for `-lncurses`. The symlink makes that resolve. Good — but it is a
   dependency on a *symlink* in another package, which is worth naming.
4. `make` at `generic.lua:11` is not `make -j1` — same rule deviation as kbd
   and kmod.

7. **The backlog entry is DEFERRED, not blocked — this package is buildable
   today.** `nl_langinfo` is `__INTRODUCED_IN(26)` in Bionic
   (`langinfo.h:97`), and `aarch64-android35` exists in this tree, so `less`
   **builds on `aarch64-android35` right now**; only `android21` and
   `android24` sit below the line. The entry reads as though the package were
   dead, which is misleading: the only thing keeping it off the low-API
   targets is the absence of an `android26`-or-later system in this tree. What
   would settle it: one `aarch64-android35` build.

**How to verify once built** (`clang-native` today, `aarch64-android35` once
the entry is revisited).

- `bin/less` and `bin/lesskey` exist.
- `share/man/man1/less.1` exists.
- `$OBJDUMP -f bin/less` shows the target machine.
- `nm bin/less | grep ncurses` should show real ncurses symbols (T), not
  unresolved ones — that is what proves the termcap probe found the prefix's
  ncurses rather than nothing.
- On `aarch64-android21`/`24`, the expected failure is a compile error at
  `charset.c` naming `nl_langinfo`. Anything else is a new problem.
