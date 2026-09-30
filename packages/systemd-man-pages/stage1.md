# systemd-man-pages build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 262 (`anduin.linuxfromscratch.org/LFS/systemd-man-pages-262.tar.xz`)
- Build system: **none — pure data.** No `configure`, no `Makefile`, no
  compiler of any kind. `generic.lua:5-6` is one `mkdir` and one `cp`.
- Installs: `share/man/man1/*.1.gz`, `man2`, `man3`, `man5`, `man7`, `man8`
  (roff, pre-compressed). **No library, no headers, no pkg-config file, no
  tools.**
- Requires: `systemd-man-pages@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | One `mkdir` and one `cp`. Nothing reads a sysroot, so no Bionic API-level wall can apply. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** **Not applicable, and this is the design, not an
oversight.** The recipe has no compiler in it, so there is no architecture to
be sensitive to and no way for a target fact to leak in. `$CC`, `$CXX`,
`$CFLAGS`, `$SYSROOT`, `$CMAKE_FLAGS` and `$AUTOCONF_CONFIGURE_FLAGS` are all
untouched, and correctly so. The API level is not even nominally a variable
here — nothing in the recipe *could* observe it. The installed tree is
byte-identical on all six systems, and there is no architecture check to
perform.

**Risks / what a reviewer should check.**
1. **This package is not the same thing as `systemd`.** `topackage.md:76`
   records systemd 262 as *blocked* ("upstream requires glibc >=2.34 or musl
   >=1.2.6, not Bionic") and, separately, marks Systemd Man Pages 262 as
   `[x]` done. That is consistent and correct: the man pages are standalone
   roff files with no relationship to systemd's C build. A reviewer skimming
   the backlog should not conflate the two entries.
2. **The man pages document systemd**, which does not exist in this prefix.
   That is intentional — they are documentation, consumed by `man`, and cost
   nothing — but it is worth stating so nobody later "fixes" it by trying to
   add a systemd dependency.
3. **The LFS mirror is the source**, not upstream. systemd publishes man pages
   inside the main tarball, not as a separate `systemd-man-pages-*.tar.xz`.
   The URL is therefore tied to LFS's `anduin.linuxfromscratch.org`; if that
   mirror reorganises its layout the URL breaks the same way util-linux's
   per-minor-version paths did (see `packages/util-linux/source.lua:6` and the
   note there).
4. **No `.pc`, no `bin/`, no `lib/`** — their absence is correct. A reviewer
   verifying this package should look for `share/man/`, not for a library.

**How to verify once built.**
- `share/man/man1/systemd.1.gz`, `share/man/man5/systemd.service.5.gz`,
  `share/man/man8/systemd-sysusers.8.gz`
- `ls share/man | tr '\n' ' '` should list `man1 man2 man3 man5 man7 man8`
- `gzip -t share/man/man1/systemd.1.gz` → exit 0 proves the roff is intact
  (a **host** tool reading a data file, not an emulation)
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**,
  which is the correct result and the check that no toolchain accidentally got
  involved
- The freshness stamp `$NESTDIR/<sys>/.retrolunar-systemd-man-pages` should
  report `skip ... (fresh)` on a rerun.