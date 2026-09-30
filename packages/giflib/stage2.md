ACCEPT

# giflib 5.2.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/giflib/`. I did not build.

*(An earlier draft of this review rejected the recipe on a
`PREFIX="$OUT"`-on-the-make-line reading. That was wrong: I had not read the
recipe. It reads the system variables deliberately and correctly, and the
verdict is ACCEPT.)*

## What the recipe gets right

- **The comment identifies the build system correctly and that matters.**
  giflib ships a plain hand-written `Makefile`, not an autotools one, so
  there is no `./configure` and — correctly — **no `touch aclocal.m4 configure
  config.h.in` line**. The guard is only mandated *after a `./configure`*; a
  package with no configure has nothing to guard. The absence is right, and the
  comment is what makes it obviously deliberate rather than forgotten.
- `make -j1 CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" PREFIX="$OUT"` is the
  correct treatment of a hand-written makefile. This is exactly the case
  AGENTS.md describes for the FFmpeg family: a non-autoconf build script does
  not understand `--host`/`--build`, so the machine facts are spelled its own
  way — and here they are spelled by *reading the system's own variables*,
  which is the ideal form. Nothing is hardcoded.
- `PREFIX="$OUT"` is necessary, not redundant: giflib's `Makefile:17` defaults
  `PREFIX = /usr/local`, so without the override the install would escape the
  prefix entirely. This is the install target, which is allowed to be `$OUT`.
- **The narrow install targets are a genuinely good call.**
  `Makefile:133` reads `install: all install-bin install-include install-lib`,
  so a plain `make install` would also install `gif2rgb` and `giftext` — two
  target programs. The recipe uses `install-lib install-include` instead, which
  is the ordinary upstream way to install a library-only subset. That is
  exactly the "smallest necessary set" discipline AGENTS.md asks for.
- `make -j1` on the compile; the second `make` invokes only install targets
  (`install-lib`, `install-include`), so it is not a parallel build.
- `require("zlib")` is a real dependency, `packages/zlib` exists, and giflib
  does link it. `require("giflib@source")` names no missing package.

## Non-blocking observations

- The comment says IGRAPHICS and the man pages stay off by default. Worth
  keeping that claim honest in the build record: check that `include/igraphics/`
  and `share/man/` are **absent** from `$OUT`. If either is present, the
  makefile's defaults are not what the comment says.
- `make install-lib install-include` has no `-j1`. That is fine — they are
  install-only targets — but if the makefile ever grew a compile step under
  `install-lib`, the flag would matter. `install-lib: libgif.a` depends on the
  archive, so confirm `lib/libgif.a` exists rather than assuming the second
  `make` did nothing.

## Carried to the build

- `lib/libgif.a` — `llvm-objdump -f lib/libgif.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Also check `ls lib/libgif.so*`; if a shared object appears, the backlog line's "static" is incomplete and the makefile built both.
- `include/gif_lib.h` — `[ -f include/gif_lib.h ]`. That is the entire public header set for giflib 5.x, so its absence is the whole failure.
- `include/igraphics/` and `share/man/` must be **absent** — their presence means `install-include` pulled more than the library header, contradicting the recipe comment.
- `bin/` must be **absent** — `install-lib install-include` deliberately skips `install-bin`. A `gif2rgb` or `giftext` binary here means the narrow install regressed, and both would be target programs nothing could run.
- No `.pc` unless the tarball proves otherwise; per the backlog, a missing `pkg-config --modversion giflib` is correct.
