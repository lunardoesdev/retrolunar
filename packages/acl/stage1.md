# acl build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 2.3.2
- Build system: autotools
- Installs: `lib/libacl.a` **and** `lib/libacl.so` (no `--disable-shared`, so both), `include/sys/acl.h`, `include/acl/libacl.h`, `include/acl/*.h`; `lib/pkgconfig/libacl.pc`; `bin/getfacl`, `bin/setfacl`
- Requires: `attr` (exists, 2.5.2), `acl@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | libacl is a thin wrapper over `acl_get_file`/`acl_set_file` in libattr plus `listxattr`/`getxattr`/`setxattr`. `libattr/generic.lua:8-13` builds attr with no Android-specific file, and topackage.md:8 records Attr 2.5.2 as `[x]`, so the same sysroot works one level down. ACL 2.3.2 has no `#include` of anything glibc-only; its own `libacl/attr_utils.c` uses only `<sys/xattr.h>`, `<stdlib.h>`, `<string.h>`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | No arch-conditional code in libacl. |
| x86_64-mingw | WILL BUILD (moderate confidence) | ACL 2.3.2's autotools has no `mingw*` branch, and libacl itself is POSIX `xattr` calls. The tools `getfacl`/`setfacl` are plain C. Nothing in the tree references `nl_langinfo`, `argp_parse` or `scandir`. Moderate because `getfacl` calls `getline` and locale functions whose mingw support I did not verify. |
| clang-native | WILL BUILD | glibc has everything. |

## API level notes

Nothing in libacl is gated above API 21. It calls `listxattr`, `getxattr`,
`setxattr`, `removexattr` and `strerror`, all present in Bionic's libc at
every level. The API level is not a variable for this package.

## Risks / what a reviewer should check

- **The `-Wall` only, no `-Werror`**: `AM_CFLAGS` is just `-Wall` in
  `libacl/Makefile.am`, so a warning will not stop the build.
- **`getfacl`/`setfacl` are installed target binaries.** Nothing here runs
  them. If the prefix is meant to carry no ACL tools, there is no configure
  flag for it; it would need the elfutils-style per-directory install.
- **`xattr` is required and is not optional** in the ACL 2.3.x
  configure: without it, configure errors. Since `attr` builds on all
  targets, this should hold, but it is the single point of failure.

## How to verify once built

- `lib/libacl.a`, `include/sys/acl.h`, `include/acl/libacl.h`
- `bin/getfacl`, `bin/setfacl`
- `readelf -h lib/libacl.a` shows `Machine: AArch64` on Android targets
- No `.pc` file — a consumer uses `-lacl` with `-I$PREFIX/include`
