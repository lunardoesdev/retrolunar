# vim build forecast

- Recipe: `generic.lua`, source `source.lua` (fetch-by-**git**)
- Version pinned: 9.2.1143, from the git tag `v9.2.1143` of
  `github.com/vim/vim` — `source.lua:7` does
  `git clone --depth=1 --branch "$tag" "$git" src`
- Build system: **none in the ordinary sense** — vim's `configure` is a
  hand-written shell script (`generic.lua:6-7` says so explicitly), so
  `$AUTOCONF_CONFIGURE_FLAGS` does not apply and every option is passed by hand
- Installs: `bin/vim`, `bin/vimdiff`, `bin/vimtutor`, `bin/xxd`,
  `share/vim/vim92/**` (syntax, colorschemes, runtime), `share/man/man1/vim.1.gz`
- Requires: `vim@source` only (`generic.lua:1`). No package dependencies —
  `--with-features=normal` keeps the X11/clipboard toolkits out.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--host=aarch64-linux-android` is passed at `generic.lua:22`, and the recipe comment at `generic.lua:12-14` records why it is mandatory: vim's configure **runs a test program** to decide whether it is cross-compiling and reports "cannot run C compiled programs" without `--host`. That is exactly the emulation question AGENTS.md forbids — passing `--host` makes configure *assume* cross instead of *proving* it, which is the correct resolution. The feature set is `normal`, so no `Xlib`, no `gtk`, no `libcaca`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same as the aarch64 rows, now that `--host="$HOST_TRIPLET"` replaced the hardcoded literal — this system exports `HOST_TRIPLET="x86_64-linux-android"`, so configure targets x86_64 as it should. **An earlier version of this row said WILL BUILD *and* flagged the hardcoded `--host` in risk 2, i.e. it named the defect and predicted success anyway.** With the literal, configure would have built an aarch64 tree into an x86_64 prefix. The recipe is fixed; the row now follows the fix. |
| x86_64-mingw | UNCERTAIN | As above; `--host=aarch64-linux-android` would be wrong, and vim's mingw path is the least-exercised of its configurations. |
| clang-native | WILL BUILD | Same. `clang-native` exports `HOST_TRIPLET="$BUILD_TRIPLET"` = `x86_64-pc-linux-gnu`, so `--host="$HOST_TRIPLET"` names the machine it is actually on. `--host` is still worth passing: vim's configure *runs* a test program to decide whether it is cross-compiling, and naming the host makes it assume cross rather than prove it, which is what AGENTS.md's no-emulation rule requires. |

**API level notes.** **No new wall, with `--with-features=normal` doing the
work.** That feature level is what keeps the risky subsystems out: `+clientserver`,
`+xterm_clipboard` and `+gui` would each reach for X11 or an at-spi dependency,
and `+terminal` (the `:terminal` feature, which is in `huge` but not `normal`)
would pull in `forkpty`/`openpty`. With `normal`, the compiled surface is
`fileio.c`, `os_unix.c`, `term.c`, `eval.c` and the regexp engine, using
`read`/`write`/`open`/`fstat`/`ioctl`/`sigaction`/`fork`/`execvp` — all present
at API 21. vim does use `getpwuid`, `tcgetpgrp` and `gettimeofday`, none of
which are API-gated. **`os_unix.c` also uses `mchdir`/`realpath` and, notably,
`readlink`** — present at 21. Nothing needs an API introduced after 21, so the
API level is inert.

**Risks / what a reviewer should check.**
1. **The git fetch is deliberate and correct.** `source.lua:6-8` guards with
   `if [ ! -d src ]` for idempotency, exactly as AGENTS.md prescribes, and
   `generic.lua:16-19` records *why*: the release archive "ships a prebuilt
   `src/configure`", whereas the git tag has none — the tag is a source
   checkout that expects `./configure` to be generated, and vim's tree does
   carry the generated script at the tag. This is the AGENTS.md-sanctioned
   "tarball is known-incomplete, use git" case, and the comment explains it.
2. **`--host` is now `--host="$HOST_TRIPLET"`, and this file found the defect
   before the fix landed.** It was `aarch64-linux-android`, hardcoded, in a
   recipe that claims to be a generic fallback. AGENTS.md:196-204 requires
   machine identities to come from `$HOST_TRIPLET`, which every system
   exports. The consequence was worse than an inconsistency: on
   `x86_64-android35` it configured an aarch64 tree into an x86_64 prefix, and
   on `x86_64-mingw` it handed an aarch64 triplet to
   `x86_64-w64-mingw32-gcc`. The substitution is safe rather than risky:
   `aarch64-android21/24/35` all export `HOST_TRIPLET="aarch64-linux-android"`,
   so the one family that worked expands to exactly the same literal. **The
   process lesson is the part worth keeping: this stage1 named the defect in
   risk 2 and then rated `x86_64-android35` WILL BUILD in the table anyway.
   A forecast that identifies a defect and then predicts success past it is
   the worst combination in this pipeline, and the table is what the builder
   reads first.**
3. **`--with-tlibdir="$PREFIX/lib"` (`generic.lua:25`) is deliberate and
   documented** at `generic.lua:8-10`: modern vim refuses to configure without
   it, and pointing it at the in-prefix terminfo makes vim's runtime lookup use
   `packages/ncurses` rather than a host database. Referencing `$PREFIX` — not
   `$OUT` — is correct here because it is a *search* path, per AGENTS.md:117.
4. **The deliberate deviation from LFS** is recorded at `generic.lua:16-19`:
   LFS appends a `SYS_VIMRC_FILE` define to `src/feature.h` to move the vimrc
   to `/etc`, and that edits an upstream source, which this project does not do.
   The default prefix location is kept instead. **That is the right call and
   the comment is exactly what AGENTS.md asks for** — a reviewer should
   preserve it rather than "fixing" it toward the LFS recipe.
5. **`make` and `make install` are bare** (`generic.lua:26-27`), serialising by
   default. Cosmetic.

**How to verify once built.**
- `bin/vim`, `share/vim/vim92/syntax/syntax.vim`,
  `share/vim/vim92/defaults.vim`, `share/man/man1/vim.1.gz`
- `file bin/vim` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for
  Android <level>` — `topackage.md:86` records exactly this string for a
  verified build, stripped
- `llvm-objdump -f bin/vim | head` → `elf64-littleaarch64`
- `bin/vim --version` **cannot be run** (target binary; emulation forbidden).
  Verify statically instead:
  `strings bin/vim | grep -m1 'VIM - Vi IMproved'` and
  `strings bin/vim | grep -m1 'Included patches: 1-1143'` for the pin
- `test -f $PREFIX/share/vim/vim92/syntax/syntax.vim` → true; a missing runtime
  directory means `make install` did not complete even though `bin/vim` exists
- Check risk 2 concretely: `llvm-nm -u bin/vim | grep -c X11` should be **0**
  with `--with-features=normal`, proving no GUI toolkit leaked in