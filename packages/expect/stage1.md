# expect stage1 build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 5.45.4
- Build system: autotools
- Installs: `bin/expect`; `include/expect/*.h`; `lib/expect.exp` (the Tcl library); `share/man/man1/expect.1`; **no `.pc`**
- Requires: `tcl` (exists, 8.6.16), `expect@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (configure)** | topackage.md:22 records "blocked: bundled tclconfig/config.sub has no aarch64 support". Expect ships its **own bundled** `tclconfig/` — a complete, frozen Tcl 8.5 configure tree — and `configure` runs `config.sub` on `--host` to canonicalise `aarch64-linux-android`. A `config.sub` old enough to predate aarch64-as-a-host returns "cannot canonicalize" and configure aborts. The prefix's own `packages/tcl` is fine (topackage.md:79 records it `[x]`); the failure is in expect's vendored copy, which `--with-tcl` does not touch. |
| aarch64-android24 | **WILL NOT BUILD (configure)** | Same. |
| aarch64-android35 | **WILL NOT BUILD (configure)** | Same. |
| x86_64-android35 | **WILL NOT BUILD (configure)** | Same blocker as aarch64, different message. I ran the bundled script myself against the real `$HOST_TRIPLET` rather than reasoning about the 2003 table: `./tclconfig/config.sub x86_64-linux-android` exits 1 with ``Invalid configuration `x86_64-linux-android': system `android' not recognized``. The **machine** half (`x86_64`) is recognised; the **system** half (`android`) is absent from a 2003 `basic_system` table entirely. `configure:8453` wraps that in `as_fn_error "$SHELL config.sub $host_alias failed"`, so the row aborts at configure before any Makefile exists. An earlier version of this file claimed the row got *past* config.sub because the script "has no aarch64 but does handle x86_64/i86"; that was wrong and is corrected here. |
| x86_64-mingw | **UNCERTAIN** | mingw's `x86_64-w64-mingw32` triplet is old enough that a pre-aarch64 `config.sub` handles it, so the recorded blocker may not apply. What I could not settle: expect 5.45.4's C sources use `<pty.h>`-style terminal control and `termios` in a way that MinGW's CRT may not match, and the recipe passes no `--disable-*` for that. Flagged, not claimed. |
| clang-native | **UNCERTAIN** | `x86_64-pc-linux-gnu` is a triplet every `config.sub` handles, so the recorded blocker does not apply. Whether expect 5.45.4 builds against the prefix's Tcl 8.6.16 is unverified. |

**The `armv7a-*` and `i686-*` rows.** I ran the bundled `config.sub` against
all four Android triplets myself; every one exits 1, and only the two
non-Android triplets return 0:

```
aarch64-linux-android   rc=1  machine `aarch64-linux' not recognized
arm-linux-androideabi   rc=1  system `androideabi' not recognized
x86_64-linux-android    rc=1  system `android' not recognized
i686-linux-android      rc=1  system `android' not recognized
x86_64-w64-mingw32      rc=0
x86_64-pc-linux-gnu     rc=0
```

So every Android family fails at configure — aarch64 on the *machine* half and
the rest on the *system* half — and `armv7a-android*` and `i686-android*` are
**WILL NOT BUILD (configure)** for the same reason as `x86_64-android35`.

## API level notes

Both blockers are **build-tooling** problems, not API-level ones.
Expect's own C code (`exp_*.c`, `pty.c`) uses `termios`, `forkpty`-style
calls and `select` — all present in Bionic at API 21 — so were the
`config.sub` blocker fixed, 21 would likely be the floor. Worth separating:
there is no missing libc symbol here to work around.

## Risks / what a reviewer should check

- **The `$(TCLSH)` execution: the mechanism in this file was wrong, and the
  fix has moved.** The alarming-looking `pkgIndex.tcl` rule
  (`Makefile.in:328-330`) is **not** in the install chain — `binaries`
  depends on `pkgIndex.tcl-hand` (`Makefile.in:217`), which writes the file
  with plain shell `echo` and runs no interpreter, and `install-lib-binaries`
  only installs the file `-hand` already produced (`:558-559`). The real
  execution is `install-libraries: libraries $(SCRIPTS)` (`:231`), where
  `$(SCRIPTS)` runs `$(TCLSH) fixline1` to generate timed-run, timed-read,
  ftp-rfc, autopasswd, lpunlock and weather (`:35`, `:382-383`). So a host
  interpreter is still required, and `pkgIndex.tcl-hand` alone does not cover
  it. The recipe therefore keeps `--with-tcl="$PREFIX/lib"` for the link line
  and overrides only the interpreter with `make install
  TCLSH_PROG="$NATIVE_PREFIX/bin/tclsh8.6"`, since `TCLSH_PROG` is a plain `=`
  variable (`Makefile.in:172`).** A previous version of this file also
  recorded the `$(TCLSH)` argument on the `x86_64-android35` row, which never
  reaches `make install` at all — see that row above. `tcl.m4:578-606`
  resolves `TCLSH_PROG` from `TCL_BIN_DIR`, and `Makefile.in:328-330` pipes
  `echo pkg_mkIndex . lib/expect.so` into it during `make install`. With
  `--with-tcl=$PREFIX/lib` that is the **target** `tclsh8.6`. The recipe now
  requires `tcl@native` and points `--with-tcl` at `$NATIVE_PREFIX/lib` so
  TEA finds a host interpreter. **I could not settle whether that is
  sufficient**: `AC_SUBST(TCLSH_PROG)` is unconditional, so a `TCLSH_PROG=`
  environment override is discarded and the only lever is the directory
  `--with-tcl` names. What would settle it: run `configure` and read the
  `checking for tclsh` line. If it still prints a path under `$NESTDIR`
  rather than a bare `tclsh8.6`, the package is not cross-buildable here.
- **The bundled `tclconfig/` is still a real blocker for aarch64.** The
  recipe's `--with-tcl`/`--with-tclinclude` point at a directory, but expect
  still uses its own bundled `configure` machinery rather
  than deferring to the installed `tclConfig.sh`. That is a known expect
  Tcl — but expect still uses its own bundled `configure` machinery rather
  than deferring to the installed `tclConfig.sh`. That is a known expect
  packaging quirk. **The realistic unblock is using expect 5.45.4's `git`
  branch, whose `tclconfig` is newer**, or an expect release after 5.45.4
  that refreshes it. I did not check whether a newer expect exists, since
  5.45.4 is what the recipe pins and the LFS list agrees.
- **`--enable-shared` at `generic.lua:10`** makes `libexpect` a shared
  object. Expect's package exports a Tcl-loadable `expect.so`; the recipe
  disables rpath (`--disable-rpath`), so a *running* `expect` would need
  `LD_LIBRARY_PATH`. On Android that is awkward. Worth a reviewer's
  judgement on whether shared is the right choice here.
- **`--mandir="$OUT/share/man"` at `generic.lua:11`** hardcodes a layout
  rather than deriving it. Harmless but it is a target fact written into
  the recipe, which AGENTS.md discourages; `--mandir` is not a toolchain
  fact so it does not belong in `$AUTOCONF_CONFIGURE_FLAGS`, but it also
  need not be spelled out.
- **Dejagnu depends on this package's *concept* but not on it**
  (see `packages/dejagnu/stage1.md`), so expect being blocked does not
  break dejagnu.

## How to verify once built

Not verifiable on any Android target today. On a host where the bundled
`config.sub` copes:

- `bin/expect`
- `include/expect/expect.h`, `lib/expect.exp`
- `share/man/man1/expect.1`
- `file bin/expect` → Android ELF if it ever builds
- `lib/pkgIndex.tcl` — its presence is the proof that a **host** tclsh ran
  `pkg_mkIndex`; if it exists while a target tclsh was the one invoked, the
  build did something forbidden
- No `.pc`; expect is a program plus a Tcl library
