# readline build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 8.3 (`ftp.gnu.org/gnu/readline/readline-8.3.tar.gz`)
- Build system: **autotools** — the recipe runs `./configure` at `generic.lua:10`
- Installs: `lib/libreadline.a`, `include/readline/readline.h`,
  `include/readline/history.h`, `lib/pkgconfig/readline.pc`, `lib/libtinfo.a`,
  and the `readline` example tool
- Requires: `termcap` (`generic.lua:1`, **exists** in `packages/termcap`),
  `readline@source` (`generic.lua:2`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:10` passes `--without-curses`, so the recipe resolves termcap from the in-prefix `termcap` package rather than ncurses; termcap's own `generic.lua:8` already sets `CC="$CC -std=gnu89"` for its *own* build, not for consumers. readline 8.3's `configure` uses only autoconf standard checks, all link-only under `-DCMAKE_...`/autoconf's static path. No API-24+ symbol. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; readline has no arch-specific code. |
| x86_64-mingw | WILL BUILD | `--without-curses` plus termcap. readline's `configure` sets `LIBTOOL_DEPS`; on `WIN32` it skips termcap entirely and uses the stub in `compat/`, so the termcap dependency is unused but harmless. |
| clang-native | WILL BUILD | Native; `--prefix=$OUT` comes from `$AUTOCONF_CONFIGURE_FLAGS` (`packages/clang-native/generic.lua:52`). |

**API level notes.** No new wall. readline 8.3 calls only `isatty`, `read`,
`write`, `getenv`, `signal`/`sigaction`, `tputs`/`tgoto` — all present at API 21.
The recipe's real environment dependency is the `export CFLAGS="$CFLAGS -fPIC"`
at `generic.lua:8`, and that is a **documented recipe-local workaround, not a
smell**: AGENTS.md's own exception list names readline as the case for it,
because `packages/python` links readline's objects into a shared module. It is
system-neutral — `-fPIC` is correct on every target — so it belongs here.

**Risks / what a reviewer should check.**
1. **`make -j1` is present** (`generic.lua:13`), which satisfies the
   serial-build rule; good.
2. **8.3 is not the newest readline.** The 8.2 series and 8.3 are the current
   upstream line; worth confirming whether a newer 8.x exists before treating
   this pin as current.
3. `Requires.private: termcap` in the upstream `.pc` is why `termcap` exists as
   a package at all — see `packages/termcap/stage1.md`, which hand-writes the
   `.pc` because upstream ships none. That pairing is load-bearing: if
   `termcap.pc` were missing, readline's `.pc` would advertise an unresolvable
   `Requires.private`.
4. The autotools timestamp guard is present (`generic.lua:11-12`), correctly
   naming `config.h.in` — readline does use that name.

**How to verify once built.**
- `lib/libreadline.a`, `include/readline/readline.h`,
  `include/readline/history.h`, `lib/pkgconfig/readline.pc`
- `pkg-config --modversion readline` → 8.3
- `llvm-objdump -f lib/libreadline.a | head` on the Android targets →
  `elf64-littleaarch64` (and `elf64-x86-64` on x86_64-android35)