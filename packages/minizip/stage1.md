# Minizip build forecast — `minizip`

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.1 (tracks zlib; see "What this package is")
- Build system: **autotools, ungenerated.** `contrib/minizip/configure.ac`
  (786 bytes) and `Makefile.am` (818 bytes) ship; **no `configure`** (verified
  ABSENT in the unpacked tree).
- Requires: `zlib` and `minizip@source` (`generic.lua:1-2`). `Makefile.am:25`
  links `-lz`; `minizip.pc.in:9-10` ships `Libs: -lminizip`, `Libs.private: -lz`.
- Would install: `lib/libminizip.{a,so}`, `include/minizip/*.h`,
  `lib/pkgconfig/minizip.pc`.

## What this package is, and how it relates to `packages/zlib/`

**Minizip is not an upstream project of its own.** It is the `contrib/minizip/`
directory *inside* the zlib release tarball, maintained by the zlib project and
versioned in lockstep with it — `configure.ac:4` is literally
`AC_INIT([minizip], [1.3.1], [bugzilla.redhat.com])`. There is no separate
minizip release and no upstream project page to track. The version therefore
tracks zlib's.

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
because `Makefile.am:7-8,10-11` puts `../..` on the include and library path
and links `-lz`.

**The real cost of separate packaging is duplication of the *fetch*, not of the
build.** Both recipes download the identical zlib tarball from the identical
URLs into their own `dl/`. That is wasteful and worth knowing about, but it is
the correct shape: `packages/zlib/` is not this package's to depend on for its
sources (it is a *build* dependency, satisfied by `require("zlib")`), and
coupling two `source.lua` files to one tarball would make the zlib version bump
a two-package change. `source.lua` says so in a comment.

Note this is **not** the same thing as `minizip-ng`, which topackage.md already
marks done — that is a distinct modern project with its own releases.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | `./configure` does not exist. The recipe stops on the first line after the copy; nothing compiles. No API-level question is reached. |
| aarch64-android24 | WILL NOT BUILD | Same: missing generated `configure`. |
| aarch64-android35 | WILL NOT BUILD | Same: missing generated `configure`. |
| x86_64-android35 | WILL NOT BUILD | Same: missing generated `configure`. |
| x86_64-mingw | WILL NOT BUILD | Same: missing generated `configure`. `configure.ac:19-26` does branch on `*-mingw*` to set `WIN32` and compile `iowin32.c` (`Makefile.am:13-16`), so the configure logic itself is mingw-aware — but there is no script to run it. |
| clang-native | WILL NOT BUILD | Same: missing generated `configure`. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

## The blocker, in full

`contrib/minizip/` contains `configure.ac` (786 bytes) and `Makefile.am`
(818 bytes) but **no generated `configure`**. Verified by listing the directory:
the 22 files present are `Makefile`, `Makefile.am`, `configure.ac`,
`iowin32.{c,h}`, `ioapi.{c,h}`, `mztools.{c,h}`, `minizip.c`, `miniunz.c`,
`unzip.{c,h}`, `zip.{c,h}`, `crypt.h`, `minizip.pc.in`, two `.1` man pages, and
three `.txt` files. `configure` is not among them, and neither are `aclocal.m4`,
`config.h.in` or `Makefile.in`.

So building it needs `autoreconf` (or `autoconf` + `automake` + `libtoolize` —
`configure.ac:7` calls `LT_INIT`, so libtool is required too, and
`packages/libtool` does exist in this tree). **`autoreconf` is not one of the
build-body verbs AGENTS.md permits** (only `cp`, `./configure`, `cmake`, `make`,
`make install`, `ninja`, `touch`, `find`, `mkdir`, cat-heredocs). This is the
clean case the hygiene rule was written for: the only upstream-supported build
needs a tool that generates a build system, which is not a patch, not a sed, and
not something a recipe may smuggle in via a shell function.

**The alternative makefile does not help.** `contrib/minizip/Makefile` is a
2012-era hand-written file. Its `all` (`:10`) builds `miniunz` and `minizip` —
the two **demo programs**, and `Makefile.am:3-5` / `configure.ac:9-17` confirm
those are gated behind `--enable-demos`. It has **no `install` target** (the
only other rule is `clean`, `:28-29`), it links `../../libz.a` directly
(`:4-5`), so it needs zlib built *in place* above it rather than installed to a
prefix, and `make install` on it would do nothing. It cannot produce a staged
`libminizip`.

## If this is to be revisited

Two clean options, neither of which belongs in `generic.lua`:

1. Build the four library sources directly with `cmake`, in the same shape
   `packages/lz4/generic.lua` uses for lz4's hand-written `lib/Makefile`
   (`make -C lib PREFIX="$OUT" …`). That means hand-writing a makefile, which is
   a fork, not a recipe.
2. Run `autoreconf` in `source.lua`. `@source` never compiles and is not bound
   by the build-body verb list — but it would make the fetch step generate files
   that differ from the release tarball, which is exactly the kind of hidden
   behaviour AGENTS.md's design principle rules out.

Both are director-level decisions. `stage1.md` records the facts; it does not
pre-empt them.

## API-level notes

**Not reached.** Nothing compiles, so the API level is untested for this
package. For the record, the sources' libc surface is small and Bionic-clean:
`ioapi.c` is `fopen`/`fread`/`fwrite`/`fclose`/`remove` plus the Windows
`_WIN32` variants, and `Makefile.am:18-23` lists exactly four library sources
(`ioapi.c`, `mztools.c`, `unzip.c`, `zip.c`) — no `getpass`, no `nl_langinfo`,
no `posix_spawn`. If option 1 or 2 above is taken, API 21 is unlikely to be the
wall, but that is a prediction, not a measurement, and is deliberately not
graded here.