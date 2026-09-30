# libarchive build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.8.1 (GitHub release asset `.tar.xz`)
- Build system: autotools (the recipe uses `./configure`, not the CMake build
  upstream also ships)
- Installs: static `libarchive.a`, `archive.h`/`archive_entry.h`,
  `libarchive.pc`, and the `bsdcpio.h` public header. The `bsdtar`, `bsdcp`
  and `bsdcat` tools are off (`--disable-bsdtar --disable-bsdcp
  --disable-bsdcat`), so nothing but the library is installed.
- Requires: `zlib`, `bzip2`, `xz`, `lz4`, `zstd` — **all five exist** in
  `packages/`. Each is a real link dependency of the resulting archive.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe contains the one real platform workaround and it is the load-bearing line. `generic.lua:9-10` appends `-I$PWD/contrib/android/include` to `CPPFLAGS` and exports it, because `archive.h` pulls in libarchive's private Android syscall wrappers (`android_lf.h`) as soon as `__ANDROID__` is defined, but only the NDK build adds that directory and the CMake path guards the include on a variable this repo's toolchain file deliberately leaves unset. AGENTS.md:253-262 calls this exact case out and says to add the private include path by hand, preferring `./configure` over cmake because Autotools always reads `CPPFLAGS` while cmake's initialisation is policy-gated (CMP0126). **The recipe follows that advice precisely** — it is a textbook use of the documented pattern, not a hack. The five backends resolve through the system `PKG_CONFIG_LIBDIR`. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The `contrib/android` include is inert here (`__ANDROID__` undefined), so that part is fine. The open question is the five backends: this tree's `zlib` installs as `libzlib` on mingw, and libarchive's configure looks for `libz`. libpng hit exactly this and solved it with symlinks (`packages/libpng/generic.lua:9-14`); libarchive has no such step. What would settle it: one `./configure` under `x86_64-mingw` and a look for a zlib detection failure. The build would still configure, likely with the zlib backend silently disabled. |
| clang-native | WILL BUILD | As above; no Android include needed and the host zlib is `-lz`. |

**API level notes.** libarchive is one of the more demanding cross-compile
targets in the tree, but the recipe removes the demand: all three command-line
tools are disabled, and those are the parts that would open files with
`O_BINARY`-style platform conditionals and read `/etc/mime.types`. The
remaining `libarchive` core is portable C plus the private Android wrappers.
No API-gated symbol in the built code. `armv7a-android*` and `i686-android*`
match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`--without-xml2 --without-expat` at `generic.lua:21` are load-bearing
   and correct.** libarchive can filter xar via libxml2 and 7zip via expat;
   neither is a declared dependency, and pulling either in would add an
   undeclared `.pc` requirement. Keeping them out is right.
2. **`export CPPFLAGS` is the one export in the recipe, and it is permitted.**
   AGENTS.md:218-222 forbids exporting search flags *in general*, with an
   explicit exception for "recipe-local workarounds with a comment explaining
   why". This is exactly that: a private include path this prefix must
   provide, commented with the reason and the CMP0126 reasoning. The general
   rule still holds — `LDFLAGS`, `CFLAGS` and `CXXFLAGS` are untouched.
3. **A static archive with five backends has five link-order obligations.**
   `libarchive.a` will carry undefined `z_*`, `bz2*`, `lzma_*`, `LZ4_*` and
   `ZSTD_*` symbols. `libarchive.pc`'s `Requires.private` (or `Libs.private`)
   must name all five or every consumer fails at link. This is the same latent
   class as the lcms2 and abseil `-llog` findings — the package builds, and the
   consumer is where it breaks. Worth checking explicitly.
4. `make -j1` is correct here (`:23`), unlike kbd/less/kmod.
5. `topackage.md` records this as built with all five backends, consistent with
   the recipe's `require()` list.

**How to verify once built.**

- `lib/libarchive.a` exists; `include/archive.h` and `include/archive_entry.h`
  exist.
- `pkg-config --modversion libarchive` reports 3.8.1.
- `pkg-config --static --libs libarchive` mentions **all five** of zlib,
  bzip2, lzma, lz4 and zstd. A missing one is the failure that will bite
  consumers.
- `llvm-nm -u lib/libarchive.a | grep -c 'LZ4_\|ZSTD_\|lzma_\|BZ2_\|inflate'`
  should be non-zero, proving the backends really compiled in.
- `ls $OUT/bin/` must be empty — a `bsdtar` here means `--disable-bsdtar`
  regressed.
- `$OBJDUMP -f lib/libarchive.a` prints `elf64-littleaarch64` on Android.
