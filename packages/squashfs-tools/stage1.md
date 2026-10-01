# squashfs-tools build forecast

- Recipe: `generic.lua` + `android.lua`, source `source.lua`
- Version pinned: 4.7.2 (latest tag; `README` in the tarball root says "The
  latest Squashfs-tools release is 4.7.2")
- Build system: **hand-written Makefile, not autotools.** There is no
  `configure`, no `configure.ac`, no `aclocal.m4`, no `Makefile.in` and **no
  config template of any name** in the tree. `squashfs-tools/Makefile:1-3`
  carries its own `RELEASE_VERSION`/`RELEASE_DATE` and
  `squashfs-tools/version.mk` is included at `Makefile:449` purely to fill in
  `VERSION`/`DATE` strings. The autotools timestamp guard does not apply:
  there is nothing to guard.
- Installs: `bin/mksquashfs`, `bin/unsquashfs`, `bin/sqfstar` (symlink),
  `bin/sqfscat` (symlink), and four `.1.gz` man pages.

## Directory shape

The GitHub archive unpacks to `squashfs-tools-4.7.2/`, and the Makefile is in
the **`squashfs-tools/` subdirectory** of that. `source.lua` strips only the
outer directory, so `$OUT/squashfs-tools/` contains
`squashfs-tools/` (the sources) plus `generate-manpages/`,
`Documentation/manpages/`, `README`, `INSTALL`. The recipe `cd`s into it,
which is required, not cosmetic: `Makefile:571` calls
`generate-manpages/install-manpages.sh $(shell pwd)/.. …` and
`install-manpages.sh` then checks
`[ -f $1/squashfs-tools/generate-manpages/functions.sh ]` and aborts
otherwise. From the subdirectory, `pwd/..` is the wrapper root, which is
exactly what that test expects.

## Dependencies, and which exist

Every compressor is a make variable that adds a library to `LIBS`:

| compressor | Makefile | `LIBS` entry | package | in prefix? |
|---|---|---|---|---|
| gzip (also `COMP_DEFAULT`, `Makefile:88`) | `:34` `GZIP_SUPPORT = 1` | `:276` `-lz` | `zlib` | **yes** |
| xz | `:56` `XZ_SUPPORT = 1` | `:317` `-llzma` | `xz` | **yes** |
| lz4 | `:73` `LZ4_SUPPORT = 1` | `:300` `-llz4` | `lz4` | **yes** |
| zstd | `:80` `ZSTD_SUPPORT = 1` | `:329` `-lzstd` | `zstd` | **yes** |
| lzo | `:64` `LZO_SUPPORT = 1` | `:288` `-llzo2` | `lzo` | **NO** |

So it needs **zlib, lz4, lzma and zstd, and optionally lzo**. zlib, lz4,
lzma and zstd are all in this prefix; **lzo is not** (no `packages/lzo`,
same absent package lzop and lrzip want — see `packages/lzop/stage1.md`).
The recipe passes `LZO_SUPPORT=0`, which is a command-line make variable and
therefore overrides `Makefile:64`'s own `LZO_SUPPORT = 1`; `COMP_DEFAULT`
stays `gzip`, which is still selected, so `Makefile:433-437`'s consistency
checks (`COMP_DEFAULT` must name a selected compressor) pass.

`:271` `LIBS = -lpthread -lm` is unconditional, and `Makefile:483`/`:566` put
`$(LIBS)` verbatim on both link lines. See Wall 1.

`Makefile:126` `XATTR_OS_SUPPORT = 1` adds `xattr_system.c`,
`read_xattrs.c`, `unsquashfs_xattr_system.c` — Linux `getxattr`/`setxattr`,
present in Bionic at every level. `Makefile:184-186` confirms no switch is
needed.

## Wall — `LIBS = -lpthread` and Bionic has no libpthread

`squashfs-tools/Makefile:271` is a plain `=`:

```
LIBS = -lpthread -lm
```

and it is **not** behind any conditional. `Makefile:483` (mksquashfs) and
`:566` (unsquashfs) both link with `$(CC) $(LDFLAGS) $(EXTRA_LDFLAGS) … $(LIBS) -o $@`.

This is fatal on every Android target, and the reason is a platform fact,
probed rather than assumed:

- The NDK 28.2.13676358 sysroot has **no `libpthread*`** anywhere under
  `usr/lib` — not in `aarch64-linux-android/`, not in its `lib32`, not in
  `x86_64-linux-android/`, not in its `lib32`.
- `aarch64-linux-android21-clang p.c -lpthread` →
  `ld.lld: error: unable to find library -lpthread`, and identically at
  API 24 and API 35. Every Android level, because Bionic keeps threads in
  libc.
- `… -pthread` links cleanly at API 21 and API 24 — the flag is fine, the
  *library name* is what does not exist.

`thread.c` and `nprocessors_compat.c` call `pthread_create`/`pthread_join`,
which are in Bionic's libc, so **no link flag is needed at all** once
`-lpthread` is gone. `android.lua` therefore restates `LIBS` without it (a
command-line `LIBS=` overrides `Makefile:271`; nothing upstream is edited).
`x86_64-mingw` and `clang-native` both have a real libpthread, so they use
`generic.lua` unchanged.

## Man pages would run target binaries — switched off

`Makefile:167` defaults `USE_PREBUILT_MANPAGES = n`. With `n`,
`install-manpages.sh` looks for `help2man` and, finding it, runs
`./mksquashfs-manpage.sh` over **the freshly built mksquashfs / unsquashfs /
sqfstar / sqfscat** to render the manuals. That is running target binaries,
which this repo never does — it is the same wall as groff rendering its own
examples or `file` generating `magic.mgc`. Both recipes pass
`USE_PREBUILT_MANPAGES=y`, which takes the pages shipped in
`Documentation/manpages/`. `help2man` is in fact absent from the native
prefix, so the script would have fallen back anyway, but with `error`
messages on stderr; `y` makes the behaviour explicit.

The script still needs `gzip` in `PATH` (`install-manpages.sh`, the loop over
`for i in gzip`) and copies from `../../Documentation/manpages`, which
`source.lua`'s `--strip-components=1` preserves.

## API level notes

No level-gated symbol appears anywhere in the sources:

- `nl_langinfo` (API 26), `mktime_z` (API 35), `posix_spawn` (API 28),
  `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass`, `O_BINARY`:
  **zero hits** across `squashfs-tools/*.c` and `*.h`.
- `mknod` and `lchown` appear in `unsquashfs.c`; both are in Bionic at every
  level.

So the API level is not a variable for this package. The Android wall is the
library name, and it is the same at 21, 24 and 35.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `Makefile:271` `LIBS = -lpthread -lm` reaches both link lines (`:483`, `:566`) and Bionic has no libpthread at any level — `ld.lld: error: unable to find library -lpthread`, confirmed at API 21. `android.lua` exists precisely to restate `LIBS` without it; with that file the remaining Android-specific risk is nil (no gated symbols, xattr is in libc). Recorded as WILL NOT BUILD because the *generic* path cannot link, and the forecast must describe the package as pinned. |
| aarch64-android24 | **WILL NOT BUILD** | Identical, same line, same probe at API 24. |
| aarch64-android35 | **WILL NOT BUILD** | Identical, same line, same probe at API 35. Nothing in the tree is gated at 26 or 35, so 35 differs from 21 in nothing relevant. |
| x86_64-android35 | **WILL NOT BUILD** | Same `-lpthread` wall; no arch-conditional code in the tree. |
| x86_64-mingw | **UNCERTAIN** | `-lpthread` resolves here (mingw-w64's winpthreads), so `Makefile:271` is fine and `generic.lua` is the right recipe. Uncertain, not WILL BUILD, for three reasons I did not verify: (1) `packages/zlib` builds zlib with cmake and, per AGENTS.md, **mingw zlib installs as `libzlib`, not `libz`** — `Makefile:483` hardcodes `-lz`, so the link would fail exactly the way libpng's did before its documented symlink workaround; (2) `thread.c`/`nprocessors_compat.c` use POSIX threads and mingw's winpthreads is a partial emulation — plausible but unverified; (3) `xattr_system.c` needs `<sys/xattr.h>`, whose mingw story I did not check. |
| clang-native | **UNCERTAIN** | `-lpthread`, `-lz`, `-llz4`, `-llzma`, `-lzstd` all resolve on glibc once the four compressor packages are in the prefix, and nothing in the tree is API- or arch-gated. Uncertain only because this recipe was **not built** — it needs `zlib`, `xz`, `lz4` and `zstd` present in `clang-native`, which the recipe requires but which I did not confirm are already built there. |

## Risks / what a reviewer should check

- **`android.lua` restates `LIBS`.** That is deliberate: `Makefile:271` is a
  plain `=`, so a command-line `LIBS=` overrides it without editing upstream,
  and the restated list (`-lm -lz -llz4 -llzma -lzstd`) is exactly what
  `Makefile:271,276,300,317,329` produce for the selected compressors minus
  `-lpthread`. A reviewer should check the two lists still agree if the
  compressor selection ever changes. `-pthread` is deliberately *not* added:
  the thread calls are libc symbols on Bionic and the system's `LDFLAGS`
  already carry `-lm`.
- **No `config.h.in` / `config.hin` anywhere.** Claimed from the tree, not
  assumed: there is no `configure`, no `configure.ac` and no `config*`
  header template in the 193-file tarball index. This package therefore has
  no autotools timestamp guard, and the recipe correctly has none.
- **No build-system flag comes from a system here.** This Makefile honours
  `$CC`, `$CFLAGS` and `$LDFLAGS` from the environment, which is why the
  recipe passes none of its own for those. `Makefile:271` of note:
  `CFLAGS ?= -O2` then `CFLAGS += …`, so the system's `CFLAGS` wins on `?=`
  and the `-D` defines are appended — correct, and it means
  `-D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE` still reach every object.
- **`EXTRA_LDFLAGS`** (`Makefile:483`, `:566`, empty by default) exists as a
  link hook but is not needed by either recipe.
- **No target binary is ever executed.** `USE_PREBUILT_MANPAGES=y` is what
  guarantees this; the default `n` would run the built tools. Nothing else in
  the Makefile runs anything.
- **`Makefile:449` includes `version.mk`.** With `RELEASE_VERSION` set at
  `Makefile:2` the `$(shell git …)` branches at `Makefile:456-472` are not
  taken, so no git call happens at build time.

## How to verify once built

- `bin/mksquashfs`, `bin/unsquashfs`, and the symlinks `bin/sqfstar`,
  `bin/sqfscat` (all four, scoped as `ls $OUT/bin | grep -cE
  '^(mksquashfs|unsquashfs|sqfstar|sqfscat)$'` — expect 4; do **not** count
  `$PREFIX/bin` as a whole, it holds every package's tools)
- `share/man/man1/{mksquashfs,unsquashfs,sqfstar,sqfscat}.1.gz` — 4 files
- `mksquashfs --help` is *not* a valid check: it runs a target binary.
  Verify statically instead: `readelf -h bin/mksquashfs` → `Machine:
  AArch64`, and `llvm-nm bin/mksquashfs | grep -c ' T main'`
- Expected artifact count is **8** (4 binaries incl. symlinks, 4 man pages).
  Stated explicitly so a reader can compare rather than infer.
