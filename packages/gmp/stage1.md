# gmp build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 6.3.0
- Build system: autotools
- Installs: `lib/libgmp.so`, `lib/libgmpxx.so` (**shared** — `--disable-static` at `generic.lua:10`); `include/gmp.h`, `include/gmpxx.h`; `share/info/gmp.info`, `share/info/gmpxx.info`; `share/doc/gmp-6.3.0/`; **no `.pc`**
- Requires: `gmp@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | GMP's sources are assembly plus C; the assembly is generated per-arch by GMP's own `configure` from `*.asm` templates, and the AArch64 templates are maintained and tested upstream. GMP's C files use only `<stdio.h>`, `<string.h>`, `<stdlib.h>`, `<ctype.h>`, `<errno.h>` and, on Unix, `<unistd.h>`/`<sys/types.h>`. `--enable-cxx` (`generic.lua:9`) builds `libgmpxx`, which is ordinary C++ over the C library with no platform dependency. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | GMP has mature x86_64 assembly templates. |
| x86_64-mingw | **UNCERTAIN** | GMP has a `MINGW` path in its `configure` and its x86_64 assembly works there, but the shared-library build under `--disable-static`-style flags is a different shape, and MinGW's `gmp.h` installation interacts with any host GMP. GMP is famously fussy about being the only copy on the include path. Flagged, not claimed. |
| clang-native | WILL BUILD | Native; topackage.md:32 records GMP 6.3.0 as `[x]` with no blocker note. |

## API level notes

**21 is the floor and GMP clears it.** GMP is arithmetic; it has no
platform surface beyond its own assembly selection. Worth noting
explicitly, because "big number library" usually implies a wall and there
isn't one here.

## Risks / what a reviewer should check

- **`--disable-static` at `generic.lua:10` makes this a shared-library
  package**, one of three in the shard (`binutils`, `gdbm`,
  `e2fsprogs`, plus this = four). Unlike `binutils` and `e2fsprogs`, the
  recipe gives **no reason at all**. On Android a shared `libgmp.so` with
  no rpath needs `LD_LIBRARY_PATH` at consumer link time. **This looks like
  an oversight rather than a decision, and is the most substantive finding
  in this file.** Compare `libevent`, `flac`, `c-ares` and the rest, all of
  which are explicitly `--enable-static --disable-shared --with-pic`.
  `gdbm/stage1.md` records the same concern for the neighbouring `g`.
- **`make -j1 install-html` at `generic.lua:13` is a second install step
  with no comment.** It installs the Info HTML manuals, which requires
  `makeinfo` or the pre-generated HTML. If gmp's release ships only `.info`
  and not `.html`, this step will need `makeinfo` from the build host.
  Worth a reviewer's check, since a missing `makeinfo` would fail the
  build at the very last step, after everything else succeeded.
- **`--docdir="$OUT/share/doc/gmp-6.3.0"` at `generic.lua:11` hardcodes
  the version** in the path, same wart as `gettext`. A version bump that
  forgets it puts the docs under the old name.
- **`--enable-cxx` builds `libgmpxx`, which needs the target's C++
  runtime.** The NDK provides `libc++`/`libc++.so`, so this is fine, but
  it means GMP is the only package in the shard that requires a C++ ABI on
  the target. A pure-C consumer of `libgmp` is unaffected.
- **The recipe uses `$AUTOCONF_CONFIGURE_FLAGS` correctly**, and it now
  carries a touch guard naming gmp's actual template. `configure.ac` is
  `AC_CONFIG_HEADERS(config.h:config.in)`, so the template is **top-level
  `config.in`** — a spelling unique in this tree, distinct from `config.hin`,
  `configh.in` and `config.in.h`. **There is no `config.h.in` anywhere in
  gmp**, and an earlier version of this file claimed the release shipped one
  while simultaneously reporting that the recipe had no guard at all; that
  self-contradiction is a plausible origin for the blanket
  `touch config.h.in` this whole wave is cleaning up. Corrected here and the
  guard added.

## How to verify once built

- `lib/libgmp.so`, `lib/libgmpxx.so` — **`.so`, not `.a`**, which is the
  evidence for the `--disable-static` concern
- `include/gmp.h`, `include/gmpxx.h`
- `readelf -h lib/libgmp.so` → `Machine: AArch64`, `Type: DYN`
- `readelf -d lib/libgmp.so | grep SONAME` → `libgmp.so.10`
- `share/doc/gmp-6.3.0/` present — check the version in the name
- `share/info/gmp.info` present
- No `.pc`; consumers link `-lgmp`
