# libxslt build forecast

- Recipe: `generic.lua` only — no Android-only switch is needed. Source:
  `source.lua`.
- Version pinned: **1.1.45** (download.gnome.org). Note `1.1.44` is absent from
  the upstream directory; 1.1.45 is the newest published release.
- Build system: **autotools**, generated `configure` ships in the tarball
  (1,519,992 bytes; `configure` = 554,746, `configure.ac` = 16,150,
  `aclocal.m4` = 71,303, 2,218 files extracted).
- Config template: **`config.h.in`** — `configure.ac:10` is
  `AC_CONFIG_HEADERS(config.h)` and the file exists (6,244 bytes). Two *other*
  `.h.in` files exist (`libxslt/xsltconfig.h.in`,
  `libexslt/exsltconfig.h.in`) but both are `@VAR@` substitution files
  configured via `AC_CONFIG_FILES`, not autoheader templates, so they do not
  belong in the timestamp guard.
- Sub-configured: **no** — `grep -c AC_CONFIG_SUBDIRS configure.ac` is `0`.
  One `configure`, one template, 16 `Makefile.in` files swept by the guard.
- Cross-hostility: **none** — `grep -c AC_RUN_IFELSE configure.ac` is `0`.
- Installs: `lib/libxslt.a`, `lib/libexslt.a`, `include/libxslt/*.h`,
  `include/libexslt/*.h`, `lib/pkgconfig/libxslt.pc`, `lib/pkgconfig/libexslt.pc`,
  `bin/xsltproc`.
- Requires: **libxml2** (exists — added by this same batch), `libxslt@source`.

## Inherits libxml2's iconv conclusion

libxslt does not do its own iconv check (no `iconv` reference anywhere in
`libxslt/`, `libexslt/` or `xsltproc/`), so it inherits libxml2's outcome
wholesale: **API >= 28 builds with iconv, API < 28 builds with the built-in
ISO-8859-X tables**, and neither is a blocker for libxslt. The one thing that
*would* break is a missing libxml2 entirely, and `require("libxml2")` puts it
in the prefix first.

libxml2 is located by `PKG_CHECK_MODULES([LIBXML], [libxml-2.0 >= 2.15.1])` at
`configure.ac:405-413`, which is non-fatal and satisfied by the `.pc` file
libxml2 installs. The `xml2-config` fallback at `configure.ac:420-437` is not
reached, because the pkg-config branch leaves `LIBXML_LIBS` non-empty — and
that matters, because `AC_PATH_TOOL` (`configure.ac:332`) would not find
`$PREFIX/bin` on `PATH` anyway.

## The two host-side features

**Python is not optional here — this is the one real cross-build trap.**
Unlike libxml2 2.15.4, this libxslt still probes Python whenever the option is
merely *unset*: `configure.ac:190-198` runs
`PKG_CHECK_MODULES([PYTHON], [python-${PYTHON_VERSION}])` with **no
action-if-not-found**, which expands to a hard `as_fn_error`. Every system in
this tree points `PKG_CONFIG_LIBDIR` at `$PREFIX` only and clears
`PKG_CONFIG_PATH` (e.g. `packages/clang-native/generic.lua:34-37`), so a host
`python-3.x.pc` is never visible. Without `--without-python`, configure aborts
on **every** system in the tree, including clang-native. This is why the flag
lives in the system-neutral `generic.lua` and not in an Android file: it is a
property of this release's probe, not of any target.

**The debugger is already off by default**, and the recipe says so.
`configure.ac:267` tests `if test "$with_debugger" != "yes"`, so an unset option
leaves `WITH_DEBUGGER=0` and no `WITH_DEBUGGER` define
(`libxslt/xsltconfig.h.in:86-87` then compiles the debugger out). The recipe
still passes `--without-debugger` so the intent survives an upstream default
flip; a reviewer should know the flag is currently a no-op, not a fix.

The **profiler** is left at its default (on, `configure.ac:280-287`). It is
not host-side: it is pure C calling `clock_gettime`/`gettimeofday`
(`libxslt/xsltutils.c:2142-2170`), and `clock_gettime(CLOCK_MONOTONIC, ...)`
was probed and links at API 21 (rc=0).

## Verdict

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL BUILD** | With the `--without-python` from `generic.lua`, the only libxml2 dependency is satisfied by the API-21 build above (iconv off, ISO-8859-X tables in). `configure.ac:190`'s Python probe is skipped. No `AC_RUN_IFELSE` (`grep -c` = `0`), so no configure probe runs a target binary. `--with-crypto` is off (`configure.ac:205`) and `--with-plugins` is off (`configure.ac:449-451`), so neither libgcrypt nor a shared-library plugin path is pulled in. libxml2 is found by pkg-config against `$PREFIX`. |
| aarch64-android24 | **WILL BUILD** | As above; API 24 is still below libxml2's iconv gate but that only affects libxml2's own encoding tables, not libxslt's build. |
| aarch64-android35 | **WILL BUILD** | As above. |
| x86_64-android35 | **WILL BUILD** | As above; every gate is a libc API-level gate, not an architecture one. |
| x86_64-mingw | **WILL BUILD** | No Android gate. libxml2's mingw recipe supplies a mingw libxml2, and `PKG_CHECK_MODULES` finds it through `$PREFIX/lib/pkgconfig`. `--without-python` is required here for the same reason as everywhere: mingw also clears `PKG_CONFIG_PATH`. `configure.ac:193-197` adds `-no-undefined -shrext .pyd` to `PYTHON_LDFLAGS` only inside the Python branch that `--without-python` skips. |
| clang-native | **WILL BUILD** | The dangerous one, and it is precisely why `--without-python` is in the generic recipe: on a glibc host a `python-3.x.pc` often exists on the system, but `packages/clang-native/generic.lua:34-37` sets `PKG_CONFIG_LIBDIR` to `$PREFIX` only, so it is invisible and the unguarded probe at `configure.ac:192` would abort configure. With the flag, no Python probe runs at all. `$AUTOCONF_CONFIGURE_FLAGS` here carries `--build` only, so this builds natively. |

armv7a and i686 behave exactly like their aarch64/x86_64 counterparts.

## API-level notes

**None of them bite this package.** libxslt's own sources reference none of the
API-gated symbols — `grep -rE '\b(mblen|getpass|posix_spawn|process_vm_readv|
POSIX_MADV_|nl_langinfo|iconv_open)\b' libxslt/ libexslt/ xsltproc/` returns
nothing. The only libc calls on a hot path are `clock_gettime`/`gettimeofday`
in the profiler, and `clock_gettime` links at API 21 (probed, rc=0). The API-28
iconv gate is entirely libxml2's, already accounted for.

## Risks / what a reviewer should check

1. **`--without-python` is load-bearing, not cosmetic.** Removing it fails
   configure on all six systems. This is the single most important line in the
   recipe and the comment says why.
2. **Version coupling to libxml2.** `configure.ac:25` requires
   `LIBXML_REQUIRED_VERSION=2.15.1`. This is why the sibling libxml2 recipe
   pins 2.15.4 rather than the newest 2.14.x. libxslt 1.1.45 and libxml2
   2.15.4 are a matched pair.
3. **`--without-debugger` is currently a no-op** (upstream default is already
   off at `configure.ac:267`). The recipe says so; a reviewer should not
   "fix" it into a different flag.
4. **The autotools guard is correct**: `config.h.in` is the real autoheader
   template, it exists, the project is not sub-configured, and the two
   `xsltconfig.h.in`/`exsltconfig.h.in` files are correctly *not* in the touch
   list because they are `AC_CONFIG_FILES` substitution files, not templates.
5. **No `android.lua` is intentional.** There is no switch here that is correct
   for Android and wrong elsewhere — the one dangerous probe is disabled for
   every system. Writing an `android.lua` that merely repeated the generic build
   would be a second copy to keep in sync.

## How to verify once built

- `lib/libxslt.a` and `lib/libexslt.a` exist; `bin/xsltproc` exists.
- `pkg-config --modversion libxslt` reports `1.1.45`.
- `grep -c '$OUT' lib/pkgconfig/libxslt.pc` is `0`, proving the loader rewrite
  ran.
- `pkg-config --static --libs libxslt` must name `libxml-2.0` (via
  `Requires.private`) and nothing from the host.
- The configure log must **not** contain `checking for python-` — that string
  appearing at all means `--without-python` did not take effect and configure
  is one `python-N.pc` away from aborting.
- `llvm-nm -u lib/libxslt.a` must show `xmlXPathCompOpEval` (and other
  `xml*` symbols) undefined, proving it links against this tree's libxml2 and
  not a system one.