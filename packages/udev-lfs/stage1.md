# udev-lfs build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 20230818 (`anduin.linuxfromscratch.org/LFS/udev-lfs-20230818.tar.xz`)
- Build system: **none — pure data.** No configure, no compile. `generic.lua:12-20`
  is four `mkdir`s and five `cp`s.
- Installs: `lib/udev/rules.d/*.rules` and `lib/udev/rules.d/network/*.rules`,
  `usr/share/udev/write_cd_rules`, `usr/share/udev/write_net_rules` (POSIX
  shell scripts), `usr/share/doc/udev-20230818/*.txt` plus the two generators.
  **No library, no headers, no pkg-config file, no binaries.**
- Requires: `udev-lfs@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `mkdir` and `cp` only. The two generators are shell scripts that are *installed*, never executed at build time, so nothing reads a sysroot. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above — and note `.rules` files are text; the fact that udev is a Linux concept does not stop them being copied. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** Not applicable, by construction. Nothing is compiled, so
there is no architecture check to perform and no way a target fact could leak
in — `$CC`, `$CXX`, `$CFLAGS`, `$SYSROOT` and `$CMAKE_FLAGS` are untouched, and
correctly so. The installed tree is byte-identical on all six systems.

**Risks / what a reviewer should check.**
1. **The recipe deliberately does not use upstream's own `Makefile.lfs`**, and
   the reason is recorded at `generic.lua:9-11`: that Makefile installs from a
   versioned subdirectory (`udev-lfs-20230818/*.rules`), but the flat LFS
   release tarball `source.lua:10` strips to the top level, so that path does
   not exist. Hand-writing the `mkdir`/`cp` lines is therefore the *correct*
   response to a packaging mismatch, not a workaround to be cleaned up. The
   bare `cp *.rules` globs depend on that flat layout, so anyone who changes
   `source.lua` must change `generic.lua` with it.
2. **`cp *.rules` and `cp *.txt` are unguarded globs**
   (`generic.lua:15-16`). If a future LFS tarball adds or removes a file
   matching those patterns, the recipe silently changes shape — and if it
   removes *all* of them, `cp` fails on an empty expansion. Worth a `find`
   listing when verifying a bump.
3. **This is a rules-and-scripts package for a Linux facility that does not
   exist in this prefix** — there is no udev here, and `write_cd_rules` /
   `write_net_rules` are generators udev's Makefile would normally run on the
   build host. They are installed as scripts for completeness. That matches what
   `topackage.md:80` records ("data only, no binaries") and is not a defect.
4. **No `.pc`, no `bin/`, no `lib/*.so`** — correct. Verify the *absence*, as
   with the other data packages.

**How to verify once built.**
- `lib/udev/rules.d/55-lfs.rules`, `lib/udev/rules.d/network/55-lfs.network`,
  `usr/share/udev/write_cd_rules`, `usr/share/udev/write_net_rules`,
  `usr/share/doc/udev-20230818/*.txt`
- `ls lib/udev/rules.d/ | wc -l` should be non-zero and every entry should end
  `.rules`
- `test -x usr/share/udev/write_net_rules` → true; these are scripts and
  should keep their mode through the `cp`
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**, the
  check that proves no toolchain got involved
- `diff` the installed tree against `$NESTDIR/source/udev-lfs/` to confirm
  every file landed and nothing was compiled — the two trees should match
  file-for-file.