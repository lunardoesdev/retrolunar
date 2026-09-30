# sqlite build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3500400 — i.e. SQLite **3.50.4**, encoded in upstream's
  YYYYDDD style (`sqlite.org/2025/sqlite-autoconf-3500400.tar.gz`)
- Build system: **autotools** — `./configure` at `generic.lua:6`. This is the
  `sqlite-autoconf-` amalgamation package, which is the one variant of SQLite
  that ships a generated `configure`.
- Installs: `lib/libsqlite3.a`, `include/sqlite3.h`, `include/sqlite3ext.h`,
  `lib/pkgconfig/sqlite3.pc`
- Requires: `sqlite@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-shared --enable-static` (`generic.lua:6`) plus the autotools timestamp guard at `:7-8`. The amalgamation is one big C file (`sqlite3.c`) plus `shell.c`, and the library build compiles only `sqlite3.c`. SQLite uses `fopen`/`fread`/`fwrite`/`mmap`/`fcntl`/`unistd`, all present at API 21. It does use `getcwd`, `readlink` and `timespec_get`, none of which are API-24+. **`-DHAVE_USLEEP=1`-style defaults are not an issue**: SQLite's own configure handles a missing `usleep` by substituting `sleep()`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. SQLite has no arch-specific code. |
| x86_64-mingw | WILL BUILD | `--host=x86_64-w64-mingw32` from `packages/x86_64-mingw/generic.lua:54` selects the Win32 branch of the amalgamation, which is well-trodden upstream. |
| clang-native | WILL BUILD | Native. |

**API level notes.** **No new wall, and this one is worth checking carefully
because SQLite is a common source of them.** The specific traps and why none
apply here: SQLite wants `pread`/`pwrite` (present at API 21),
`fdatasync` (present), `getrandom` (present, though SQLite probes for it and
falls back to `/dev/urandom`), and `nl_langinfo` — which **is** an API-26
symbol. SQLite uses `nl_langinfo` only in `shell.c` (for `printf`'s `%_` and
locale-aware date output) behind a configure check, not in the library
amalgamation. Since the static library target compiles `sqlite3.c` alone, the
API-26 symbol is never referenced by `libsqlite3.a`. This is the clearest case
in the shard of "the blocked list would be right if the recipe built the shell,
and wrong because it does not".

**Risks / what a reviewer should check.**
1. **`make -j1` is explicit** (`generic.lua:9`) — correct per AGENTS.md.
2. **`shell.c` is still compiled by `make`, even if not installed usefully.**
   The recipe does not pass `--disable-readline`, so the shell links against
   the readline in `$PREFIX` if `readline.pc` is visible, or falls back to
   plain `stdin` if not. Either way `make install` puts `bin/sqlite3` in `$OUT`.
   That binary is dead weight in a target prefix but harmless. A reviewer
   wanting it gone would add `--disable-readline`, which is an upstream option,
   not a patch.
3. **The `version` field is upstream's number, not a marketing version.**
   `3500400` = 2025 day 040. `pkg-config --modversion sqlite3` will report
   `3.50.4`, **not** `3500400` — do not treat that mismatch as a bug. The
   freshness stamp and the recipe both track `3500400`.
4. **`sqlite-autoconf-` is the right variant.** The plain `sqlite-src-` and
   `sqlite-autoconf-` packages both exist; only the autoconf one ships
   `configure`, and the recipe depends on that. Do not "simplify" the URL to
   the canonical sqlite.org download link, which serves the *amalgamation
   zip* (`sqlite-amalgamation-*.zip`) with no build system at all.

**How to verify once built.**
- `lib/libsqlite3.a`, `include/sqlite3.h`, `include/sqlite3ext.h`,
  `lib/pkgconfig/sqlite3.pc`
- `pkg-config --modversion sqlite3` → `3.50.4` (see risk 3)
- `llvm-objdump -f lib/libsqlite3.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libsqlite3.a | grep -c sqlite3_open` → non-zero,
  proving the amalgamation linked rather than just compiling
- `strings lib/libsqlite3.a | grep -m1 '3.50.4'` for the version stamp
- `find $PREFIX/lib -name 'libsqlite3.so*'` must be **empty**