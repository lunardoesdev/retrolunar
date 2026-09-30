# gdbm build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.26
- Build system: autotools
- Installs: `lib/libgdbm.so` (**shared** — `--disable-static` at `generic.lua:9`), `lib/libgdbm_compat.so`; `include/gdbm.h`, `include/gdbm-ndbm.h`, `include/gdbm-compat.h`; `bin/gdbm`, `bin/gdbm_dump`, `bin/gdbm_load`, `bin/gdbmtool`; **no pkg-config file**
- Requires: `gdbm@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `src/*.c` is portable C89 using `<fcntl.h>`, `<unistd.h>`, `<sys/stat.h>`, `<sys/types.h>`, `<stdlib.h>`, `<string.h>` and `<limits.h>`. gdbm's only optional extras are the ndbm and db compatibility layers, both of which are header-only shims over gdbm itself (`gdbm-ndbm.h` maps the ndbm API onto gdbm's). `--enable-libgdbm-compat` (`generic.lua:10`) turns on the compat library and needs nothing external. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | gdbm's on-disk format is explicitly byte-order-independent (it encodes the byte order in the header), so there is no host-endianness dependency. |
| x86_64-mingw | **UNCERTAIN** | gdbm 1.26's configure does have a `mingw*` branch and builds `gdbm.dll`. The recipe passes no `--enable-shared`/`--disable-static` adjustment for it, so the mingw build would also be shared-only. Whether the DLL installs and links usefully in this prefix is unverified. Flagged, not claimed. |
| clang-native | WILL BUILD | Native; topackage.md:29 records GDBM 1.26 as `[x]` with no blocker note. |

## API level notes

**21 is the floor and gdbm clears it.** gdbm's file locking uses `fcntl`
and its mmap path uses `mmap`, both ancient in Bionic. There is no
`nl_langinfo`, no `getgrent`, no `scandir`, no `argp_parse` anywhere in the
library — I would expect a database library not to need them, and the
absence of any Bionic-specific recipe file corroborates that.

## Risks / what a reviewer should check

- **`--disable-static` makes this one of only two shared-library packages
  in the shard** (the other is `e2fsprogs`, via `--enable-elf-shlibs`).
  Everything else here is static. The recipe gives no reason, unlike
  `binutils` and `e2fsprogs` which both explain theirs. **On Android a
  shared `libgdbm.so` with no rpath needs `LD_LIBRARY_PATH` at consumer
  link time**, which this prefix does not arrange. If there is a reason —
  gdbm's on-disk format is stable and a shared gdbm lets several tools
  share one cache — it belongs in a comment. As it stands this looks like
  an oversight rather than a decision. **This is the most substantive thing
  in this file.**
- **`--enable-libgdbm-compat` adds a second shared library**,
  `libgdbm_compat.so`, and therefore a second rpath problem. If the static
  question above is resolved, this one resolves with it.
- **`bin/gdbmtool` is a curses application.** gdbm 1.26's `gdbmtool` uses
  ncurses, and this prefix has `packages/ncurses` (topackage.md:61,
  `[x]`). The recipe does **not** require ncurses, so configure's
  `AC_CHECK_LIB([ncursesw]...)` will fail and gdbmtool is built without
  curses (gdbm falls back to a line-based interface). That is a silent
  feature reduction, not a build failure — worth a reviewer's note since
  the alternative would be adding a real dependency.
- **No pkg-config file**, so a consumer links `-lgdbm` and must know to add
  `-lgdbm_compat` for the compat API. A readme note.

## How to verify once built

- `lib/libgdbm.so` — **a `.so`, not a `.a`**, which is the direct evidence
  for the `--disable-static` question above
- `include/gdbm.h`, `include/gdbm-ndbm.h`, `include/gdbm-compat.h`
- `bin/gdbm`, `bin/gdbmtool`
- `readelf -h lib/libgdbm.so` → `Machine: AArch64`, `Type: DYN`
- `readelf -d lib/libgdbm.so | grep SONAME` → `libgdbm.so.6`
- No `.pc`; consumers link `-lgdbm`
