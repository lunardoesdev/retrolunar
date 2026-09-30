# e2fsprogs build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.47.3
- Build system: autotools
- Installs: `lib/libext2fs.so`, `lib/libcom_err.so`, `lib/libss.so`, `lib/libe2p.so` (shared — `--enable-elf-shlibs`). **No `libblkid`, no `libuuid`, no `libss`-adjacent blkid/uuid pair**: the recipe passes `--disable-libblkid --disable-libuuid`, so upstream never builds them (they are gated on the `@BLKID_CMT@`/`@UUID_CMT@` configure substitutions); `include/ext2fs/ext2fs.h` and friends; `sbin/mke2fs`, `sbin/e2fsck`, `sbin/debugfs`, `sbin/dumpe2fs`, `sbin/resize2fs`, `sbin/chattr`, `sbin/lsattr`; `lib/pkgconfig/*.pc`
- Requires: `e2fsprogs@source` only — note it does **not** require zlib, bzip2, xz or util-linux

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **UNCERTAIN** | **The fetch defect is fixed.** `source.lua:6` now points at the kernel.org mirror, which I re-verified returns 200 with the real 1.47.3 tree. Whether the *build* then succeeds is unverified and not expected to: see the risks section — `lib/mke2fs/` reaches for glibc interfaces Bionic lacks. Treat this as "source is available, not yet built". |
| aarch64-android24 | **UNCERTAIN** | Same as the API-21 row: the fetch now works, the build is unverified. |
| aarch64-android35 | **UNCERTAIN** | Same as the API-21 row: the fetch now works, the build is unverified. |
| x86_64-android35 | **UNCERTAIN** | Same as the API-21 row: the fetch now works, the build is unverified. |
| x86_64-mingw | **UNCERTAIN** | Same as the API-21 row: the fetch now works, the build is unverified. |
| clang-native | **UNCERTAIN** | Same as the API-21 row: the fetch now works, the build is unverified. |

## The one useful finding: the blocker is now fixable, and topackage.md is out of date

topackage.md:19 says e2fsprogs is blocked because "upstream tarball URLs
return 404", which reads as *no source exists anywhere*. **That is no
longer true, and I verified it:**

```
404  https://downloads.sourceforge.net/project/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz
200  https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz
```

Ted Ts' own kernel.org mirror carries the identical 1.47.3 tarball. **So
the recorded blocker contradicts what I can now reach: the source is
available, and the recipe's URL is simply the wrong one.** Changing the
one URL in `source.lua:5` is the whole fix at the fetch level. I have not
changed it — this file is a forecast, not an edit — but this is a
topackage.md correction the builder should make.

Whether the *build* then succeeds on Android is a separate and still-open
question; see below.

## Risks / what a reviewer should check

- **Expect a new wall now that the URL is fixed.** e2fsprogs is a
  filesystem library: `lib/ext2fs/` and `lib/support/` use
  `linux/fs.h`, `linux/mount.h`, `linux/fs/ext2.h` and blkid's
  `<blkid/blkid.h>`, and `lib/mke2fs/` reaches for `ioctl` codes and
  `getmntent`-family interfaces. Bionic's `linux/fs.h` is a reduced NDK
  header, and `getmntent` is a glibc-ism Bionic does not have. The recipe
  already disables `libblkid`/`libuuid`/`uuidd`/`fsck` (`generic.lua:11-14`)
  to lean on util-linux, which removes the worst of it, but the `mke2fs`
  side remains unexamined. **Expect this to be blocked again after the URL
  fix, for a different reason.**
- **`--sysconfdir="$OUT/etc"` at `generic.lua:10`** puts `mke2fs.conf` in
  the staging tree, which is right: `$OUT/etc` is merged into the prefix's
  `etc`. Worth knowing that the resulting `mke2fs` will look for its config
  relative to its compiled-in prefix.
- **`--enable-elf-shlibs` makes this the second shared-library package**
  after binutils in this prefix (`generic.lua:11`). Everything else is
  static. Deliberate — e2fsprogs' ABI is used by other tools — but it means
  a consumer needs the `.so` at runtime, which on Android means an rpath or
  an `LD_LIBRARY_PATH` that this prefix does not arrange. Worth a
  reviewer's attention.
- **No zlib/bzip2/xz in the require list**, yet mke2fs supports compressed
  extents. The result is a smaller feature set than upstream intends.
  Consistent with "smallest necessary flags", but a real reduction.

## How to verify once built

Not verifiable until the URL is fixed. After that:

- `lib/libext2fs.so`, `lib/libcom_err.so`
- `include/ext2fs/ext2fs.h`
- `sbin/mke2fs`, `sbin/e2fsck`
- `lib/pkgconfig/ext2fs.pc` and `pkg-config --modversion ext2fs` → `1.47.3`
- `file lib/libext2fs.so` → Android ELF
- **Do not run any of the binaries here** — they are filesystem tools and
  the repo forbids executing target binaries
