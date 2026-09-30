ACCEPT

# libarchive — stage 2 review

## What the recipe gets right

- **`make -j1` at lines 15 and 16** — serialised correctly.
- The guard at lines 13-14 is the standard form and libarchive ships a
  top-level `config.h.in`.
- **`--disable-bsdtar --disable-bsdcp --disable-bsdcat --disable-tests` is the
  libseccomp-class fix, applied correctly**: libarchive's `bsdtar`/`bsdcp`/
  `bsdcat` are `bin_PROGRAMS` and would be built and installed by a bare
  `make all`; `tests/` is a separate subdirectory. All four switches are real
  upstream options.
- **`--with-pic`** plus `--enable-static --disable-shared` gives a PIC static
  archive, which is what the rest of the prefix needs for linking into shared
  modules.
- `--without-xml2 --without-expat` keeps two optional dependencies this tree
  does not have.
- **The `CPPFLAGS` line is a correctly-justified exception.**
  `generic.lua:11-12` is
  `CPPFLAGS="$CPPFLAGS -I$PWD/contrib/android/include"; export CPPFLAGS`, and
  the comment above it explains exactly why: libarchive's `archive.h` pulls in
  its private Android syscall wrappers when `__ANDROID__` is defined, and its
  own NDK build adds that directory while the cmake toolchain here leaves the
  variable unset. That is AGENTS.md:219-222's "recipe-local workaround with a
  comment explaining why" used precisely as intended, and AGENTS.md:262 notes
  that Autotools always reads `$CPPFLAGS` where cmake would not.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## One thing to note

The `-I$PWD/contrib/android/include` is added on **every** system, including
`clang-native` and `x86_64-mingw`, where `__ANDROID__` is undefined and the
directory is unused. Harmless — the flags simply resolve nothing — but it
means the recipe carries an Android-specific include on non-Android systems.
The forecast should say that is deliberate (the alternative is an
`android.lua`, and the cost of splitting is not worth one unused `-I`).

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libarchive.a` | `ls $PREFIX/lib/libarchive.*` — static and PIC |
| `$PREFIX/include/archive.h`, `archive_entry.h` | `test -f $PREFIX/include/archive.h` |
| `$PREFIX/lib/pkgconfig/libarchive.pc` | `pkg-config --modversion libarchive` |
| compression backends linked | `llvm-nm --undefined-only $PREFIX/lib/libarchive.a \| grep -cE 'Bz2_|LZ4_|ZSTD_'` → 3 non-zero, proving `require("bzip2") require("lz4") require("zstd")` all resolved |
| no CLI installed | `test ! -e $PREFIX/bin/bsdtar`, proving `--disable-bsdtar` took |
