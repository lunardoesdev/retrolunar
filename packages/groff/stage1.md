# groff build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.24.2 (LFS pins 1.23.0; the recipe uses the newer stable)
- Build system: autotools
- Installs: `bin/groff`, `bin/troff`, `bin/groffer`, `bin/nroff`, `bin/tmacs`, `bin/neqn`, `bin/refer`, `bin/tbl`, `bin/eqn2html`, `bin/hyphen`, `bin/lookbib`; `share/groff/*` (font data, macro sets, device drivers); `info/*.info`; man pages; **no library, no `.pc`**
- Requires: `groff@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (documented blocker)** | topackage.md:35 records it precisely and the recipe's own comment (`generic.lua:4-8`) repeats it with citations: groff renders its own manual and example documents **using the groff it has just built** (`Makefile.am:497` `GROFFBIN = $(abs_top_builddir)/groff`, consumed at `doc/doc.am:39` and used in the rules at `doc/doc.am:173-174` and `:392-397`), and `make install` wants those rendered files (`doc/doc.am:130`, `:139`, `:178`). So the build cannot finish without executing an aarch64 binary on this x86_64 host — which AGENTS.md forbids outright. **The recipe's comment is the best-documented blocker in the backlog; nothing is missing from it.** |
| aarch64-android24 | **WILL NOT BUILD (documented blocker)** | Same. |
| aarch64-android35 | **WILL NOT BUILD (documented blocker)** | Same. Not API-level-related. |
| x86_64-android35 | **WILL NOT BUILD (documented blocker)** | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD (documented blocker)** | Same. Independently, groff is a Unix typesetting system and does not build for PE targets. |
| clang-native | **UNCERTAIN** | On `clang-native` the built `groff` *is* executable on the build host, so the self-rendering step would work in principle. But groff's sources use `<pwd.h>`, `<sys/utsname.h>`, `<termios.h>`, `<sys/ioctl.h>`, `termios`-based `tty` handling and `uname` — all present on this host. Unverified. |

## API level notes

**The blocker is not an API-level one and not a Bionic gap — it is
"groff executes itself".** That distinction matters for whoever picks this
up: no new `aarch64-androidNN` system directory helps, and no cache answer
helps. The only fixes are upstream (render the docs with a *host* groff
before cross-compiling) or dropping the documentation from the build
entirely. groff 1.24.2 has a `--disable-doc` that the recipe does **not**
pass; whether that also skips the `doc/webpage.ps` self-render is the
first thing a reviewer should check, and it is a configure flag rather
than a patch, so it would be within the rules.

## Risks / what a reviewer should check

- **The `touch doc/gnu.eps` at `generic.lua:15`** solves a *different*
  problem — the netpbm dependency — and the comment is clear about it. The
  two workarounds should not be confused: the `touch` handles the
  `xpmtoppm`/`pnmtops` case, and it does **not** touch the self-render
  blocker.
- **`PAGE=letter ./configure`** (`generic.lua:14`) is a groff-specific
  build variable, correctly identified as such in the comment. It is not a
  toolchain flag and correctly does not go in `$AUTOCONF_CONFIGURE_FLAGS`.
  (LFS uses US letter; groff's default is A4.)
- **`make -j1` is now explicit on both lines.** RETRACTION, and it matters: **bare `make` is not a parallelism violation.** Measured empirically: `make` reports `MAKEFLAGS=[]` and `make -j1` reports `MAKEFLAGS=[-j1]` — a bare `make` is already serial. The recipe now passes `-j1` explicitly anyway, because AGENTS.md asks for a single-job build to be *explicit* rather than implicit and that is better practice; but the edit was **not** required, and an earlier version of this file called the omission a defect and named other packages for the same thing. That was wrong, and it is the same defect class as the other false premises in this wave: a rule that sounds right, is not, and trains the next reader to fail correct recipes. No further package should be failed on bare `make`.
- **`--disable-doc` is the lead.** If groff 1.24.2's `--disable-doc`
  removes `doc/` from `SUBDIRS` (as libunwind's does, per
  `packages/libunwind/stage1.md`), then the self-render disappears with it
  and this package becomes buildable. That is a one-flag change, in
  `generic.lua`, entirely within the no-patch rule. **I regard this as the
  most promising unblock in the whole a–g shard** and I have not applied
  it, per scope.

## How to verify once built

Not verifiable on any cross target today. After a `--disable-doc` change,
if that resolves it:

- `bin/groff`, `bin/troff`, `bin/groffer`
- `share/groff/1.24.2/` font/device data, and `bin/groff -V` output would
  confirm the version (on the host only)
- `file bin/groff` → Android ELF on a cross target, x86_64 on
  `clang-native`
- `share/man/man1/groff.1` — **absent** if `--disable-doc` is used, which
  is the visible consequence of the fix
