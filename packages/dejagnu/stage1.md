# dejagnu build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.6.3
- Build system: autotools
- Installs: `bin/runtest` (the DejaGNU driver), `bin/spectest`, `bin/summarize`, `bin/identfr`, `bin/expecttest`; `share/site-toplevel/` and `share/site_expect/` Tcl libraries; `info/` pages; **no `.pc`, no C library**
- Requires: `tcl` (exists, 8.6.16), `dejagnu@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | **DejaGNU 1.6.3 compiles nothing at all on a plain build.** The tree's only C sources are `stub-loader.c` and `testglue.c`, and `Makefile.am:229` puts the single compiled object (`unit`) behind `make check`, which this repo never runs. `make` has no compilation target, no host interpreter is needed at build time (`configure.ac` probes only awk/cc/cxx), and the installed tree is a pure Tcl/awk/shell data package — byte-identical on every system. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same: nothing is compiled, so there is no arch or libc exposure. |
| x86_64-mingw | WILL BUILD | Same: nothing is compiled. `configure.ac` only probes awk/cc/cxx, all of which exist on mingw-w64. |
| clang-native | WILL BUILD | Native; topackage.md:17 records DejaGNU 1.6.3 as `[x]`. |

## API level notes

**No architecture or API-level check applies.** DejaGNU 1.6.3 compiles
nothing on a plain build, so the install is byte-identical on all six
systems — closer to a data package than any other entry in this shard.
An earlier version of this file told a story about `utils/socket.c` and a
`HAVE_SOCKET` conditional. **Both are pre-1.6 code and neither exists in
1.6.3**; that was a fabricated risk and it is withdrawn. The correct,
stronger fact is the one above.

## Risks / what a reviewer should check

- **DejaGNU is a *test driver*, and this repo's rule is that upstream test
  suites must not be built or run on the target.** DejaGNU itself is not
  run here; it is installed so that *other* packages' test suites can be
  driven on a real device later. That is a legitimate use and worth the
  readme saying so explicitly, because a reviewer skimming might otherwise
  read "DejaGNU installed on an Android target" as a mistake.
- **`--with-tcl` is not passed**, so DejaGNU's configure finds Tcl through
  the prefix's `$PKG_CONFIG_LIBDIR` and the default search. Compare
  `packages/expect/generic.lua:8-12`, which *does* pass
  `--with-tcl="$PREFIX/lib"` and `--with-tclinclude="$PREFIX/include"`
  explicitly. The asymmetry is defensible (expect has a hand-tuned Tcl
  layout; DejaGNU just needs the library) but it is an asymmetry.
- **`tcl` is a real dependency and it is in the prefix.** If `packages/tcl`
  is ever removed, this recipe fails at `make`, not at `configure`, because
  the Tcl libraries install as `.tm` files into the data dir.
- **The `remote_expect` support links `expect`**, which in this prefix is
  a *different* package (`packages/expect`) — and expect is on adder C's
  shard with a recorded blocker. DejaGNU's own `remote_expect` is a
  separate mechanism, so there is no cycle; worth confirming nobody
  assumes one.

## How to verify once built

- `bin/runtest`
- `share/site-toplevel/*.tcl`, `share/site_expect/*.tcl`
- `file bin/runtest` → Android ELF for cross targets
- `tclsh` from the prefix can `source` a `site-toplevel` file without error
  (run this on the *host* with the native tcl, not on the target)
- No `.pc`; DejaGNU is scripts plus one Tcl extension
