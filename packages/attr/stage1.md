# attr build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 2.5.2
- Build system: autotools
- Installs: `lib/libattr.a` **and** `lib/libattr.so` (no `--disable-shared`, so both), `include/attr/`, `include/attr/xattr.h`; `lib/pkgconfig/libattr.pc`; `bin/getfattr`, `bin/setfattr`
- Requires: `attr@source` only — no other package

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | libattr is the `getxattr`/`setxattr`/`listxattr`/`removexattr` syscall wrappers. `lib/libattr.c` includes only `<stdlib.h>`, `<string.h>`, `<unistd.h>`, `<sys/types.h>`, `<sys/xattr.h>`, `<errno.h>` and `system.h`. Every one of those is in the NDK r28b sysroot, and the `system.h` selection is done by attr's own `m4/attr_xattr.m4`, not by the build system. topackage.md:8 records Attr 2.5.2 as `[x]` with no blocker note, which corroborates this. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | No arch-conditional code. |
| x86_64-mingw | WILL BUILD (moderate confidence) | attr 2.5.2's configure has no `mingw*` branch, and the xattr calls are POSIX. The `getfattr`/`setfattr` tools are plain C. Moderate because I did not verify attr's own `system.h` path for a non-Linux host. |
| clang-native | WILL BUILD | glibc, and attr's autoconf finds the real `getxattr` family. |

## API level notes

Nothing gated above API 21. All five xattr entry points have been in Bionic
since the beginning, and attr's configure only *link*-tests them, never
runs them, so cross-compiling is fine.

## Risks / what a reviewer should check

- **attr is the base of the ACL chain** (`packages/acl/generic.lua:1`
  requires it), so a silent regression here breaks ACL silently. Its
  artifact check is the load-bearing one.
- **`getfattr`/`setfattr` are installed target binaries** and nothing runs
  them. No configure flag suppresses them.
- **The recipe passes no `--disable-nls`.** attr 2.5.2 defaults NLS off for
  a non-GNU host, so this should be a non-issue, but the tools' `ls.c` does
  use `nl_langinfo`-adjacent locale code behind that guard. If the guard
  ever flips, API 26 becomes the floor.

## How to verify once built

- `lib/libattr.a`, `include/attr/xattr.h`
- `bin/getfattr`, `bin/setfattr`
- `llvm-nm lib/libattr.a | grep getxattr` shows the wrapper defined
- No `.pc` file — consumers use `-lattr` with `-I$PREFIX/include`
