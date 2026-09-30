# termcap build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.1 (`ftp.gnu.org/gnu/termcap/termcap-1.3.1.tar.gz`)
- Build system: **autotools** — `./configure` at `generic.lua:9`, timestamp
  guard at `:10-11`
- Installs: `lib/libtermcap.a`, `include/termcap.h`, `include/termcap_sun.h`,
  and **a hand-written `lib/pkgconfig/termcap.pc`** (`generic.lua:16-17`).
  Upstream ships no `.pc` at all.
- Requires: `termcap@source` only (`generic.lua:1`). No dependencies — this is
  the leaf that lets readline avoid pulling ncurses in.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:8` sets `export CC="$CC -std=gnu89"`, which is load-bearing and documented at `generic.lua:6-7`: termcap 1.3.1 predates prototypes, and the NDK clang defaults to C23 where an unprototyped definition or a K&R declaration is an error. AGENTS.md names this exact case in its "Old C code" rule, so the workaround is prescribed rather than improvised. Under `-std=gnu89` the sources are plain old C using `tgetent`/`tgetstr`/`tgetnum`/`tgoto`, plus `getenv`, `malloc` and `FILE*` — all present at API 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. termcap's `configure` has a CYGWIN/MSDOS branch; mingw takes the generic path and the sources are portable C. |
| clang-native | WILL BUILD | Native; the `-std=gnu89` is harmless there too — it applies to every system rather than only some, which is the system-neutral behaviour AGENTS.md wants. |

**API level notes.** **No new wall.** termcap is a lookup-table library over
`TERM`: it reads an environment variable and a terminfo/termcap file, and
otherwise calls only `fopen`, `fgets`, `malloc`, `realloc`, `free`, `getenv`
and `toupper`. Nothing API-24+, nothing locale-dependent, nothing POSIX beyond
C89. The `-std=gnu89` at `generic.lua:8` is a *language* wall, not an API-level
one, and it is the same wall on all six systems.

**Risks / what a reviewer should check.**
1. **The hand-written `.pc` at `generic.lua:16-17` is load-bearing, not
   decoration.** `packages/readline/generic.lua:1` requires termcap and
   readline's generated `readline.pc` carries `Requires.private: termcap`. If
   this `.pc` were missing, readline would still build and install, and the
   breakage would surface later at *consumer* link time. The `printf` writes
   `prefix=$PREFIX` (`$PREFIX`, not `$OUT`), which is correct: the emitter
   rewrites `$OUT` to `$PREFIX` in staged `.pc` files anyway, and writing
   `$PREFIX` directly avoids depending on that rewrite for a file this recipe
   authors itself.
2. **The `.pc` does not declare the terminfo database location**, which is
   correct — termcap has no such dependency, it is pure C.
3. `make` at `generic.lua:12` is bare (serialises by default). Cosmetic, as in
   `sed`, `tar`, `shadow`, `sysklogd`, `texinfo`, `util-linux`, `xz`.
4. **Termcap is deprecated in favour of terminfo** and this package is 1999
   code. It is here as a leaf dependency for readline, which is a legitimate
   reason, but a reviewer should know it will never be updated upstream.
5. `--disable-shared --enable-static` (`generic.lua:9`) matches the tree-wide
   convention; a shared `libtermcap.so` would be dead weight in a target prefix.

**How to verify once built.**
- `lib/libtermcap.a`, `include/termcap.h`, `lib/pkgconfig/termcap.pc`
- `pkg-config --modversion termcap` → `1.3.1`
- `llvm-objdump -f lib/libtermcap.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libtermcap.a | grep -c 'tgetent\|tgoto'` → non-zero
- `pkg-config --libs readline` (with readline also built) must succeed — that
  is the end-to-end check that `Requires.private: termcap` resolves
- `grep -m1 '^prefix=' lib/pkgconfig/termcap.pc` must show the **nest** path,
  not the `mktemp` staging path under `$NESTDIR/tmp`