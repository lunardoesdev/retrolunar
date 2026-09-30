REJECT

# zstd 1.5.7 — stage 2 review

Reviewed against AGENTS.md, the recipe, and the unpacked tree at
`nest/source/zstd/`. I did not build.

**Adder A's finding #8 asks that zstd's from-source make be preserved. The
*intent* is right and load-bearing, but the recipe's comment describes a
mitigation that is not in the command line, so the safeguard is not actually in
place.** That is the finding.

## Required changes

### 1. `packages/zstd/generic.lua:6-8` — the comment claims a flag the recipe never passes

```
        # The release tarball ships prebuilt object files for common targets,
        # so the lib Makefile is told to compile from source rather than pick
        # one up. PREFIX and LIBDIR are what its install rules expect.
        make -C lib PREFIX="$OUT" LIBDIR="$OUT/lib" HAVE_LZMA=0 HAVE_ZLIB=0 ZLIB_PREFIX="$PREFIX"
```

Two things are wrong with that comment, and the second is the one that matters:

1. **The prebuilt objects are not there.** I checked the tree this recipe
   actually builds from:
   ```
   $ find nest/source/zstd -name '*.o' | wc -l
   0
   ```
   There is no `.o` anywhere in the 1.5.7 release tree. So the premise of the
   comment does not hold for this version.

2. **No variable on the make line tells the Makefile to compile from source.**
   The line passes `PREFIX`, `LIBDIR`, `HAVE_LZMA`, `HAVE_ZLIB` and
   `ZLIB_PREFIX` — none of which has anything to do with object-file selection.
   What actually guarantees a from-source build is zstd's own pattern rules:
   `lib/Makefile:52-53` derives `ZSTD_LOCAL_OBJ` from `ZSTD_LOCAL_SRC` via
   `%.c → %.o`, and `:221` defines `$(ZSTD_STATICLIB_DIR)/%.o : %.c`. There is no
   `.o` to pick up, so the pattern rule is the only path — which means the
   safeguard is structural, not a flag, and the comment should say *that*.

   The hazard adder A is worried about is real in principle: a stale `.o` left
   in the tree by a previous run, or a future release that does ship them,
   would be linked into `libzstd.a` by the `%.o` rules without any arch check
   and would silently put an x86-64 object in an aarch64 archive. But as the
   recipe stands, nothing *prevents* it — it is prevented by the tarball
   happening to be clean.

**Replace lines 6-8 with:**

```
        # zstd's lib Makefile derives every object from source with a %.c -> %.o
        # pattern rule (lib/Makefile:52-53, :221), so the 1.5.7 release tree
        # builds from source: it ships no prebuilt .o files (verified). That
        # matters on a cross build, because a stale host object would be
        # archived into libzstd.a with no architecture check anywhere. If a
        # future release ever does ship .o files, delete them before building
        # rather than relying on a flag - this Makefile has no switch for it.
        # HAVE_LZMA/HAVE_ZLIB are 0 because neither lzma nor zlib is a
        # dependency of anything in this prefix yet; PREFIX and LIBDIR are
        # what its install rules expect.
```

### 2. `HAVE_LZMA=0 HAVE_ZLIB=0` on the `programs` lines is fine, but state it once

Lines 11-12 pass the same four variables to `programs`, where `HAVE_LZMA` and
`HAVE_ZLIB` control whether `zstd`/`zstdcat` link the optional compressors.
Passing them keeps the two directories consistent, which is right. Worth one
sentence so a future reader knows it is deliberate and that enabling
compression later is a two-line change (`packages/xz` already exists to supply
`liblzma`).

### 3. Nothing else is required

`make` on all four lines is bare, which **is serial by default** — verified
empirically (`MAKEFLAGS` is empty without `-j`) — so it is not a
serial-build defect. `PREFIX="$OUT"` and `LIBDIR="$OUT/lib"` are the install
target, which is allowed. `ZLIB_PREFIX="$PREFIX"` is a search path pointing at
the prefix, which is correct, though moot while `HAVE_ZLIB=0`.
`require("zstd@source")` names no missing package.

## Carried to the build

- `lib/libzstd.a` — `llvm-objdump -f lib/libzstd.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **This is the check that settles change 1**: if a host x86-64 object had been archived, `llvm-objdump -f` over the archive would show a second, mismatched `File format:` line. Run it over the whole archive, not just the first member.
- `lib/libzstd.so*` — record whether it appears; zstd's Makefile builds both a static and a shared library by default, and this prefix is static, so a `.so` is worth questioning.
- `include/zstd.h` — `[ -f include/zstd.h ]`.
- `lib/pkgconfig/libzstd.pc` — `pkg-config --modversion libzstd` → `1.5.7`. Check its `Libs.private`: with `HAVE_LZMA=0 HAVE_ZLIB=0` it must **not** name `-llzma` or `-lz`.
- `bin/zstd`, `bin/zstdcat`, `bin/unzstd` — `[ -x bin/zstd ]`. Target programs; **never run them**.
- `zstdgrep`/`zstdless` are shell scripts and are not installed by these two `make` invocations; if they appear, `programs` installed more than intended.
