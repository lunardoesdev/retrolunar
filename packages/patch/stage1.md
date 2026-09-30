# patch build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.8 (ftp.gnu.org, `.tar.xz`)
- Build system: autotools
- Installs: `bin/patch`, `share/man/man1/patch.1`, `share/info/patch.info`. No
  library, no headers, no `.pc`.
- Requires: `patch@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe is a bare `./configure $AUTOCONF_CONFIGURE_FLAGS` with no switches (`:6`). GNU patch is a small C program over file I/O: `open`, `read`, `write`, `stat`, `rename`, `utime`. Nothing API-gated. Its test suite is not built by `make install`. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. patch uses `chmod`/rename semantics that mingw provides via its CRT emulation, and GNU patch is built on Windows by MSYS2 routinely. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. This is the plainest package in the shard after the
pure-data ones. The only file-related wall worth naming is `O_BINARY`, and GNU
patch does not use it — it opens files in text mode and its CRLF handling is
its own portable logic, not a platform `open` flag.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **A `patch` binary in a target prefix is a developer tool with no target
   use.** Like `lfs-bootscripts` and `less`, it is staged as a tool nothing on
   Android will run. Worth stating so nobody treats it as a validation of the
   toolchain. (It is, however, genuinely useful on `clang-native`.)
2. **The recipe passes no switches at all**, which is correct for patch and
   matches `make` and `libffi` in this shard. The comment block is absent
   though — a reader cannot tell whether the absence is considered or
   accidental. One line saying "no switches needed" would match the house
   standard for explicit intent.
3. **`--version` output and the info file**: patch's `make install` installs
   `patch.info` from the shipped `doc/`, and the timestamp guard at `:7-8`
   covers the `Makefile.in` dependency. No no-emulation risk: patch's docs are
   not self-bootstrapped the way m4's were.
4. **`topackage.md:65` records this as built** with no caveats. Consistent.
5. `make` at `:9` is not `make -j1` — the usual rule deviation, and harmless
   for a program this small.

**How to verify once built.**

- `bin/patch` exists; `share/man/man1/patch.1` and `share/info/patch.info`
  exist.
- `file bin/patch` reports `ELF 64-bit LSB pie executable, ARM aarch64, for
  Android 24, built by NDK r28c`.
- `$OBJDUMP -f bin/patch` shows the target machine.
- `llvm-nm --defined-only bin/patch | grep -cw main` non-zero (trivially true;
  the useful check is the next one).
- `llvm-nm -u bin/patch | grep -cE 'pthread_create|getopt_long'` non-zero,
  confirming it linked against this x86-64/host glibc rather than statically.
- **Do not run `bin/patch`.** Static inspection only.
