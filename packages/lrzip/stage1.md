# lrzip build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 0.7.3 (v0.7.3, the latest GitHub release of
  `ckolivas/lrzip`; releases v0.651/v0.650 carry no assets)
- Build system: autotools. The release ships a generated `configure`
  (704990 bytes), `aclocal.m4` (42526 bytes), `Makefile.in` and four
  sub-directory `Makefile.in`s, so no autoreconf bootstrap is needed.
- Config template: **`config.h.in`** — `configure.ac:21` is
  `AC_CONFIG_HEADERS([config.h])` with no explicit template argument, so the
  automake default name applies. The file is present (8696 bytes) and is an
  entry in the 126-file tarball index.
- Sub-configured: **yes, four sub-Makefiles from one configure.**
  `configure.ac:134-140` `AC_CONFIG_FILES` covers `Makefile`,
  `lzma/Makefile`, `lzma/C/Makefile`, `doc/Makefile` and `man/Makefile`, and
  the tree carries a `Makefile.in` in each of those five places
  (`Makefile.in`, `doc/Makefile.in`, `lzma/Makefile.in`,
  `lzma/C/Makefile.in`, `man/Makefile.in`). It is `AC_CONFIG_SUBDIRS`-free,
  so there is no second `configure`/`aclocal.m4` — but the
  `find . -name 'Makefile.in' | xargs touch` sweep must cover all five, which
  it does.
- Installs: `bin/lrzip`, `bin/lrztar`, `bin/lrunzip`, `bin/lrzcat`,
  `bin/lrzuntar`, man pages under `share/man/man1` and `man5`, and
  `share/doc/lrzip/`.

## Wall 1 — CONFIRMED: a hard `AC_CHECK_LIB([pthread], ...)` aborts configure

**The claim is true, and the version I am fetching carries it.**

`configure.ac:113-114`:

```
AC_CHECK_LIB(pthread, pthread_create, ,
AC_MSG_ERROR([Could not find pthread library - please install libpthread]))
```

and in the shipped `configure`, the generated form at **`configure:19381-19389`**:

```
if test "x$ac_cv_lib_pthread_pthread_create" = xyes
then :
  printf "%s\n" "#define HAVE_LIBPTHREAD 1" >>confdefs.h
  LIBS="-lpthread $LIBS"          <-- configure:19385
else $as_nop
  as_fn_error $? "Could not find pthread library - please install libpthread" "$LINENO" 5   <-- configure:19388
fi
```

Both branches are fatal on Android, and **answering the cache variable is
not a fix**, exactly as the brief says:

- **Unanswered**, `ac_cv_lib_pthread_pthread_create=no`, and
  `configure:19388` calls `as_fn_error`, which exits configure. The build
  never starts.
- **Answered `ac_cv_lib_pthread_pthread_create=yes`** (a system-level
  `export ac_cv_lib_pthread_pthread_create=yes`, the trick this repo already
  uses for `ac_cv_func_ffsl`), `configure:19385` runs
  `LIBS="-lpthread $LIBS"` — the found-action **prepends `-lpthread` to
  `LIBS` unconditionally**. `LIBS` is then on every subsequent link line
  (it is what automake puts at the end of every `LINK`/`CCLD`), so the
  configure error is traded for a link error later, in `make`, for the same
  missing library. Nothing in the tree removes it again: `LIBS` is only ever
  appended to (`configure.ac:130` `LIBS="$PTHREAD_LIBS $LIBS"`), never
  reset.

The reason `-lpthread` cannot resolve is a platform fact, verified rather
than assumed:

- The NDK 28.2.13676358 sysroot
  (`…/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib`) contains **no
  `libpthread*`** under `aarch64-linux-android/`, `aarch64-linux-android/32/`,
  `x86_64-linux-android/` or its `lib32`. A `find` for `libpthread*` over the
  whole `usr/lib` tree returns nothing.
- `aarch64-linux-android21-clang p.c -lpthread` →
  `ld.lld: error: unable to find library -lpthread`, and the same at API 35.
  So it is not an API-21-only wall; it is every Android level, because Bionic
  keeps threads in libc.
- By contrast `… -pthread` links cleanly at API 21 and API 24. That is the
  difference between the flag and the library name, and it is why ISA-L's
  *different* pthread probe (below) is not a wall.

So: **no recipe can make lrzip 0.7.3 build for any Android target.** The
fix is upstream (drop the `AC_CHECK_LIB(pthread, …)` error, or make it
`-pthread`), and the no-patch rule means this package stays blocked on
Android until upstream does it.

Note that the *second* pthread probe in the same file is harmless:
`configure.ac:129-132` calls `AX_PTHREAD`, and its failure arm
(`configure:19829-19831`) just sets `PTHREAD_LIBS=""`/`PTHREAD_CFLAGS=""`
with no error. `AX_PTHREAD` would in fact succeed on Android, because it
probes with `-pthread`. It is the hand-written `AC_CHECK_LIB` eleven lines
earlier that is fatal.

## Wall 2 — the LZO dependency, absent from this prefix

Independent of the pthread wall, `configure.ac:121-122` is:

```
AC_CHECK_LIB(lzo2, lzo1x_1_compress, ,
	AC_MSG_ERROR([Could not find lzo2 library - please install liblzo2-dev]))
```

Also fatal. `ls packages | grep -i lzo` returns nothing: there is no
`packages/lzo`. The recipe carries `require("lzo")`, which is correct and
does not resolve today — the same absent package lzop needs, and the reason
both recipes name the same package name. See `packages/lzop/stage1.md` for
what adding liblzo2 2.10 would involve.

The other three `AC_CHECK_LIB` calls all have packages here:
`configure.ac:115-116` `-lm` (math, in Bionic's separate libm, which every
Android system already carries in `LDFLAGS`), `:117-118` `-lz` → `zlib`
(present), `:119-120` `-lbz2` → `bzip2` (present), `:123-124` `-llz4` → `lz4`
(present).

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `configure.ac:113-114` aborts configure: `ac_cv_lib_pthread_pthread_create=no` (Bionic has no libpthread at any level) → `configure:19388` `as_fn_error`. Answering the cache variable makes it worse, not better: `configure:19385` puts `-lpthread` on every later link. Second, independent blocker: `-llzo2` (`configure.ac:121`) with no lzo in the prefix. |
| aarch64-android24 | **WILL NOT BUILD** | Same two walls, same two lines. API 24 is irrelevant here: nothing below is level-gated. |
| aarch64-android35 | **WILL NOT BUILD** | Same two walls. lrzip's own sources (`*.c`, `*.h` at top level) contain **zero** references to `nl_langinfo`, `mktime_z`, `posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass` or `O_BINARY`, so 35 differs from 21 in nothing that matters. |
| x86_64-android35 | **WILL NOT BUILD** | Same two walls; `configure.ac:45-57` sets `-DNOJIT` for any `host_cpu` that is not `i686`/`amd64`/`x86_64`, which is a supported path, not an obstacle. |
| x86_64-mingw | **UNCERTAIN** | The pthread wall does **not** apply: mingw-w64 ships a real `libpthread` (winpthreads), so `configure.ac:113` resolves. The **lzo2 wall does** apply — `packages/lzo` does not exist, so `configure.ac:121` aborts for want of a dependency, not for want of a platform feature. Uncertain rather than WILL NOT BUILD because it is a missing *package*, which is a fixable prefix state, not a platform limit. Separately unverified: `man/Makefile.am:13` runs `pod2man` (present in the native prefix) and the tree's console/terminal code. |
| clang-native | **UNCERTAIN** | glibc has libpthread, so `configure.ac:113` resolves. The **lzo2 wall does** apply for the same missing-package reason. Also unverified: `configure.ac:52-56` is `AC_PREREQ([2.71])`, the newest requirement of the four packages here, and the shipped `configure` was generated by a matching autoconf — the version skew that produces the `aclocal-1.17` re-runs the timestamp guard exists for is likeliest here. |

## API level notes

lrzip's top-level sources have **no** use of any API-gated symbol:

- `nl_langinfo` (API 26), `mktime_z` (API 35), `posix_spawn` (API 28),
  `process_vm_readv`, `POSIX_MADV_*`, `mblen`/`getpass` (API 21 walls):
  zero hits across `lrzip.c`, `util.c`, `stream.c`, `main.c`, `rzip.c`,
  `aes.c`, `sha4.c`, `md5.c`, `gcm.c`, `filters.c`, `runzip.c`, `date`
  helpers and every header.
- The bundled `lzma/` (LZMA SDK, `lzma/C/*.c`) is pre-7-Zip C with its own
  compat shims; `lzma/C/Makefile.am:3-5` defines `_REENTRANT`,
  `_FILE_OFFSET_BITS=64` and `_LARGEFILE_SOURCE` itself.

So on Android the API level is *not* the obstacle — the two configure-time
library checks are, and neither is level-dependent.

## Risks / what a reviewer should check

- **This recipe cannot succeed on any Android target today.** That is the
  point of the forecast, not a defect to be worked around. Reviewer should
  REJECT any attempt to "fix" it by exporting
  `ac_cv_lib_pthread_pthread_create=yes` at the system level: per
  `configure:19385` that converts a configure abort into a link failure and
  would break the next package that links anything.
- **`require("lzo")` does not resolve.** Same as lzop; both recipes name the
  same absent package.
- **`perl@native` is required and it exists.** `man/Makefile.am:6`
  `BUILT_SOURCES = lrunzip.1 lrzcat.1 lrztar.1 lrzuntar.1 lrz.1` are
  generated by the `.1.pod.1: pod2man` rule at `man/Makefile.am:12-13`.
  `pod2man` is a host perl script and **is present** at
  `nest/clang-native/bin/pod2man` (19895 bytes), so `@native` is right and
  nothing target-side is executed.
- **No library is installed.** `Makefile.am:34` and `:62` are
  `noinst_LTLIBRARIES = libtmplrzip.la` / `liblzma.la` — both `noinst`, so
  no `liblrzip.*` is ever installed. `bin_PROGRAMS = lrzip` (`:65`) is the
  only artifact. A reviewer should not look for a library.
- **Host programs that must not be built.** `Makefile.am:100`
  `check_PROGRAMS = tests/match_test …` and `:114` `check-local` — none is
  in `all`, and the recipe runs plain `make`, so they are not built. Note
  `Makefile.am:118-125`-style `%.run: %` recipes would RUN target binaries;
  they are only reachable from `make check`/`test`/`perfs`, which the recipe
  never invokes.
- **`config.h.in` is the right template name here**, unlike lzop's
  `config.hin`. Both spellings appear in these two adjacent packages.

## How to verify once built

- `bin/lrzip`, `bin/lrztar`, `bin/lrunzip`, `bin/lrzcat`, `bin/lrzuntar`
- `share/man/man1/lrzip.1` … and `share/man/man5/lrzip.conf.5`
- `readelf -h bin/lrzip` → `Machine: AArch64` on Android targets
- No `lib/liblrzip*` — correct, they are `noinst`
- `share/doc/lrzip/lrzip.conf.example` from `doc/Makefile.am`
