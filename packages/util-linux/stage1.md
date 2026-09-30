# util-linux build forecast — BLOCKED on Android

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.42.4
  (`mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-2.42.4.tar.xz`
  — the per-minor-version layout matters; the `v2.41.1` path 404s)
- Build system: **autotools** — `./configure` at `generic.lua:19-27`,
  timestamp guard at `:28-29`
- Would install: `bin/*` (lsblk, blkid, mount, umount, more's siblings, …),
  `lib/libmount.so.1`, `lib/libblkid.so.1`, `lib/libsmartcols.so.1`,
  `include/libmount.h`, `include/blkid.h`, `include/libsmartcols.h`,
  `lib/pkgconfig/*.pc` for the three libraries
- Requires: `util-linux@source` (`generic.lua:1`) and `ncurses`
  (`generic.lua:2`, **exists** in `packages/ncurses`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `versionsort` — see below. |
| aarch64-android24 | **WILL NOT BUILD** | Same; not API-gated. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | WILL NOT BUILD | util-linux is POSIX/Linux; its configure rejects a Windows host outright. |
| clang-native | WILL BUILD | glibc has `versionsort` in `<dirent.h>` (glibc 2.37+); on an older glibc the same configure probe reports it missing and util-linux falls back to its own `scandir`. |

**API level notes — the blocker, confirmed against the tree.**

`topackage.md:84` records the blocker and I re-verified every part of it:

- `libmount/src/tab_parse.c:893` reads
  `n = scandirat(dd, ".", &namelist, mnt_table_parse_dir_filter, versionsort);`
- **The call is not behind any `#if`.** I grepped `tab_parse.c` for
  `HAVE_VERSIONSORT` / `ifdef VERSIONSORT` and got no hits.
- `versionsort` is a **glibc extension**. In the NDK 28.2 sysroot:
  `grep -rn versionsort usr/include/` returns **nothing**, and
  `llvm-nm -D libc.so | grep -c versionsort` returns **0**. It is neither
  declared nor exported, at any API level. So this is a wall on *all four*
  Android rows, not an API-21/24 symbol gate.
- util-linux bundles no replacement, so there is no `-D` that helps.

**The recipe's existing workarounds are all still present and all correct.**
This is the most substantial workaround set in the shard, and each is
load-bearing:

- `--without-cap-ng` (`generic.lua:20`): libcap is not in this prefix **and has
  no reachable upstream source** (`topackage.md:47`), so `setpriv` cannot be
  built. Not a Bionic gap — a missing package.
- `--disable-asciidoc` (`:21`): stops man pages being regenerated. Without it
  make would try to run `a2x`, which is not in the prefix.
- `--disable-pylibmount`, `--disable-liblastlog2`, `--disable-libuuid`
  (`:22-24`): those libraries are not in the prefix.
- `--disable-more`, `--disable-vipw` (`:25-26`): this is the **Bionic gap** the
  recipe comment at `generic.lua:15-18` describes. `more` and `vipw` fall back
  to the editor path `_PATH_VI`, declared in glibc's `<paths.h>` and **absent
  from Bionic**. Both have upstream `meson_options.txt` feature switches, so
  they are turned off rather than patched — which is exactly the AGENTS.md
  preference.
- `--disable-nls` (`:27`): no gettext in the prefix.

**This is good design and should be recorded as such.** Turning a Bionic gap
into an upstream feature switch, rather than a `sed` or a cache answer, is the
pattern AGENTS.md asks for.

**Risks / what a reviewer should check.**
1. **A fourth Bionic gap may be lurking behind the one that blocks.** The
   recipe already handles `_PATH_VI`; util-linux's `libsmartcols` and `libblkid`
   also reach for `SMART_*` ioctls from `<linux/hdreg.h>` and `sys/statfs`
   constants. Those are normally behind feature tests, but I could not compile
   to confirm — so fixing `versionsort` is **not** guaranteed to be the last
   wall. Say so before booking the work.
2. The `ncurses` require (`generic.lua:2`) exists and is real: util-linux's
   `lib/colors.c` needs terminfo. On Android the Android systems do not ship
   terminfo, so this resolves to `packages/ncurses` in `$PREFIX`, which is the
   intended design.
3. `make` at `generic.lua:30` is bare (serialises by default); cosmetic.

**How to verify once built (valid only for `clang-native`).**
- `lib/libmount.so.1`, `lib/libblkid.so.1`, `include/libmount.h`,
  `lib/pkgconfig/libmount.pc`
- `pkg-config --modversion libmount` → 2.42.4
- `file lib/libmount.so.1` on clang-native → `ELF 64-bit LSB shared object, x86-64`
- `llvm-nm -D lib/libmount.so.1 | grep -c versionsort` — should be **non-zero**
  on glibc ≥ 2.37, and the lib's own fallback is used otherwise
- No Android verification is possible: record the compile error naming
  `versionsort` at `tab_parse.c:893` instead