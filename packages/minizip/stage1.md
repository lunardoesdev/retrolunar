# Minizip build forecast — `minizip` — **WILL NOT BUILD on any system here**

- Recipe: `generic.lua` (a legible refusal, in the shape `packages/lapack/`
  uses), source `source.lua`
- Version pinned: 1.3.1 (tracks zlib; see "What this package is")
- Build system: **autotools, ungenerated.** `contrib/minizip/configure.ac`
  (786 bytes) and `Makefile.am` (818 bytes) ship; **`configure` does not**
  (verified ABSENT, along with `aclocal.m4`, `config.h.in` and `Makefile.in`).
- Requires: `zlib` and `minizip@source` (`generic.lua:1-2`)
- Would install: `lib/libminizip.{a,so}`, `include/minizip/*.h`,
  `lib/pkgconfig/minizip.pc`

## What this package is, and how it relates to `packages/zlib/`

**Minizip is not an upstream project of its own.** It is the `contrib/minizip/`
directory *inside* the zlib release tarball, maintained by the zlib project and
versioned in lockstep with it — `configure.ac:4` is literally
`AC_INIT([minizip], [1.3.1], [bugzilla.redhat.com])`. There is no separate
minizip release and no upstream project page to track, so the version tracks
zlib's.

**A separate package is warranted, and it does not duplicate `packages/zlib/`.**
The two build different libraries from disjoint source sets:

| | `packages/zlib/` | `packages/minizip/` |
|---|---|---|
| sources | `adler32.c`, `deflate.c`, `inflate.c`, … | `ioapi.c`, `mztools.c`, `unzip.c`, `zip.c` |
| artifact | `libz.a` / `libz.so` | `libminizip.a` / `libminizip.so` |
| headers | `zlib.h`, `zconf.h` | `minizip/zip.h`, `unzip.h`, `ioapi.h`, `mztools.h`, `crypt.h` |
| build | cmake (`CMakeLists.txt`) | autotools (needs generating) |

zlib's own `CMakeLists.txt` **never descends into `contrib/`** — grepping it for
`contrib` returns nothing, and `packages/zlib/generic.lua:6` passes
`-DZLIB_BUILD_EXAMPLES=OFF` with no contrib involvement. So minizip's sources
are additional, not a re-build of zlib's output. `packages/zlib/` is required
because `Makefile.am:7-8,10-11` puts `../..` on the include and library path and
`Makefile.am:25` links `-lz`.

**The real cost is duplication of the fetch, not of the build.** Both recipes
download the identical zlib tarball from identical URLs into their own `dl/`.
That is wasteful and worth recording, but it is the correct shape:
`packages/zlib/` is a *build* dependency here (satisfied by `require("zlib")`),
not the source of these files, and coupling the two `source.lua` files to one
tarball would make a zlib version bump a two-package change.

This is **not** the same thing as `minizip-ng`, which `topackage.md` already
marks done — that is a distinct modern project with its own releases.

## The blocker

**One unsanctioned verb stands between this tree and a working package.**

`contrib/minizip/` ships `configure.ac` (786 bytes) and `Makefile.am`
(818 bytes) but **no generated `configure`**. So the autotools route needs
`autoreconf` — and `libtool` as well, because `configure.ac:7` calls `LT_INIT`.
`autoreconf` is a *code generator*, like the `configure` it produces, and it is
not among the permitted build-body verbs (AGENTS.md: `cp`, `./configure`,
`cmake`, `make`, `make install`, `ninja`, `touch`, `find`, `mkdir`,
cat-heredocs).

**The alternatives are closed, not merely unchosen:**

- **No cmake path.** `contrib/minizip/` ships no `CMakeLists.txt`. Verified by
  listing the directory: 22 files, none of them a cmake file.
- **No install target in the hand-written makefile.**
  `contrib/minizip/Makefile` is 2012-era and hand-written. Its complete rule set
  is `all`, `miniunz`, `minizip`, `test`, `clean` — `grep -nE '^install'`
  returns nothing. Its `all` (`:10`) builds `miniunz` and `minizip`, which are
  the **demo programs** (`Makefile.am:3-5` gates them on `--enable-demos`), and
  it links `../../libz.a` directly (`:4-5`), so it needs zlib built *in place*
  rather than installed to a prefix. It produces executables, not a library, and
  `make install` on it would do nothing.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | No `configure` to run. `autoreconf` is not a permitted build-body verb. The recipe refuses at `generic.lua` with an explanatory message rather than attempting a doomed `./configure`. |
| aarch64-android24 | WILL NOT BUILD | Same. |
| aarch64-android35 | WILL NOT BUILD | Same. |
| x86_64-android35 | WILL NOT BUILD | Same. `configure.ac:19-26` does branch on `*-mingw*` to set `WIN32` and compile `iowin32.c` (`Makefile.am:13-16`), so the configure *logic* is portable-aware — but there is no generated script to run it. |
| x86_64-mingw | WILL NOT BUILD | Same: missing generated `configure`. |
| clang-native | WILL NOT BUILD | Same: missing generated `configure`. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

All six rows share one cause, so unlike 7-Zip there is no per-arch divergence to
report: the blocker is the missing generated `configure`, which is a property of
the tarball and identical for every system.

## The consistency question: `cmph` vs `minizip`

Both need `autoreconf`. They cannot both be right, so the choice is explicit.

`packages/cmph/generic.lua:36` is the **only** build body in this repo that
invokes it:

```
$ grep -lE '^\s*autoreconf' packages/*/generic.lua
packages/cmph/generic.lua          ← the only hit
```

Everything else that mentions autoreconf does so in a *comment*, choosing the
other build system instead. The clearest precedent is **wolfssl**, which is
ACCEPTed and whose `stage2.md:25` states the rule in as many words:

> This is the "tarball ships no generated build system" case, handled by
> choosing the other build system rather than by invoking `autoreconf`.

**Adjudication: minizip's WILL NOT BUILD is right and cmph's WILL BUILD is the
outlier.** autoreconf is a verb the project has not sanctioned; minizip has no
alternative build system to fall back to, while cmph's situation is exactly the
one wolfssl resolved by switching build systems. cmph's recipe should be
revisited, not this verdict softened.

**If the director amends AGENTS.md to permit `autoreconf`** (with the
`autoconf@native` / `automake@native` / `libtool@native` / `m4@native` requires
that cmph already gets right, and which all exist in this tree), then **minizip
becomes buildable** and all six rows flip. `autoreconf -fi` in
`contrib/minizip/` is the only thing between this package and a staged
`libminizip.a`; there is nothing else in the way. That is a rule decision for
the director, not something to pre-empt in a recipe.

## API-level notes

**Not reached.** Nothing compiles, so no API level has been tested, and this
forecast deliberately does not pretend otherwise. For the record the sources'
libc surface is small: `Makefile.am:18-23` lists exactly four library sources
(`ioapi.c`, `mztools.c`, `unzip.c`, `zip.c`), `ioapi.c` is `fopen`/`fread`/
`fwrite`/`fclose`/`remove` plus Windows `_WIN32` variants, and there is no use
of `getpass`, `nl_langinfo` or `posix_spawn`. If `autoreconf` is ever sanctioned,
API 21 is unlikely to be the wall — but that is a prediction, not a measurement.