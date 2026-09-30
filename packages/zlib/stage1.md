# zlib build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.1
- Build system: **CMake** (`generic.lua:7`). zlib 1.3.1 ships both a hand-written
  `configure` and a `CMakeLists.txt`; the recipe takes CMake, so no autotools
  timestamp guard applies.
- Installs: `lib/libz.a`, `include/zlib.h`, `include/zconf.h`,
  `lib/pkgconfig/zlib.pc`
- Requires: `zlib@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library is `adler32.c`, `compress.c`, `crc32.c`, `deflate.c`, `gzclose.c`, `gzlib.c`, `gzread.c`, `gzwrite.c`, `infback.c`, `inffast.c`, `inflate.c`, `inftrees.c`, `trees.c`, `uncompr.c`, `zutil.c` — **plus the `gz*.c` file-I/O layer**. The `gz*.c` sources are the only place zlib touches the filesystem, and they use `open`/`read`/`write`/`close`/`lseek`/`stat`, all present at API 21. `-DZLIB_BUILD_EXAMPLES=OFF` (recipe comment `generic.lua:6`: "examples cannot run on the build host") drops `example/minigzip` and `example/example`, which are the only host programs. Nothing API-24+. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | As above, but see risk 3: the default zlib install uses `lib/zlib` or `zlib1.dll`, and there is a name-mismatch trap recorded in AGENTS.md:263-265. |
| clang-native | WILL BUILD | Native; CMake finds the system-installed zlib's paths for `zconf.h` if the vendored one is absent — it is present, so no lookup occurs. |

**API level notes.** **No new wall.** zlib's libc surface is the C89 set:
`malloc`/`free`, `memcpy`/`memcmp`, `strlen`, `fopen`/`fread`/`fwrite`/`fclose`,
`open`/`read`/`write`/`close`, `time`, `gettimeofday` (in `gzwrite.c` for the
gzip header timestamp). `time()` and `localtime` are present at API 21, and zlib
does **not** call `mktime`, `mktime_z` or `nl_langinfo`. The API level is
inert.

**Risks / what a reviewer should check.**
1. **The two-URL mirror at `source.lua:6` is the documented AGENTS.md pattern**
   (`|| curl ...` on one line): `zlib.net/fossils/` first, the GitHub release
   second. Both are the same 1.3.1 tarball. Good.
2. **`-DZLIB_BUILD_EXAMPLES=OFF` is the load-bearing flag** and the reason is
   recorded: the example programs are host executables. This is the ordinary
   upstream switch, not a workaround.
3. **The library name trap is real here and it is *this* package that causes
   it.** `packages/libpng/generic.lua` symlinks `libz.* → libzlib.*` in `$PREFIX`
   because mingw's zlib installs as `libzlib`. zlib's own CMake installs
   `libz.a` on Unix and `zlib1.dll`/`libzlib.a` on Windows depending on
   `CMAKE_INSTALL_NO_R` — so **on `x86_64-mingw` the archive may land as
   `libzlib.a` rather than `libz.a`**, and a consumer hardcoding `-lz` would
   fail to link. That is why the mingw row is UNCERTAIN rather than WILL BUILD:
   I could not inspect the archive name without building. **What would settle
   it:** read `packages/libpng/generic.lua`'s symlink step, which already
   encodes the assumption, and check whether zlib's CMake on Windows sets
   `CMAKE_INSTALL_NO_R`.
4. **No `-DBUILD_SHARED_LIBS=OFF`.** zlib's CMake honours
   `BUILD_SHARED_LIBS`, but `CMAKE_INSTALL_NO_R` is zlib's own idiom and
   defaults to `ON`, which forces **static** regardless. So the archive is
   static by default here — correct, and worth recording because it is a
   different mechanism from the rest of the tree.
5. **1.3.1 is the current stable release** (2024); there is no 1.3.2. No
   upgrade pressure.

**How to verify once built.**
- `lib/libz.a` (Unix) or `lib/libzlib.a` (see risk 3), `include/zlib.h`,
  `include/zconf.h`, `lib/pkgconfig/zlib.pc`
- `pkg-config --modversion zlib` → `1.3.1`
- `llvm-objdump -f lib/libz.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/zlib.a 2>/dev/null || llvm-nm --defined-only lib/libzlib.a | grep -cE 'deflate|inflate'` → non-zero. Note the fallback: **the library filename is itself part of the verification** for risk 3.
- `find $PREFIX/lib -name '*.so*'` → **empty**; a shared object means
  `CMAKE_INSTALL_NO_R` stopped applying
- `test -f $PREFIX/include/zconf.h` → true; a missing `zconf.h` is a classic
  consumer-side breakage with zlib and worth checking explicitly