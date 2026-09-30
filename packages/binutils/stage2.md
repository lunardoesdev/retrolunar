ACCEPT

# binutils 2.45 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/binutils/`. I did not build.

## What the recipe gets right

- The `android.lua` / `generic.lua` split is exactly the AGENTS.md pattern:
  one `android.lua` covering all 56 Android systems through
  `recipe_fallbacks`, carrying only the Android-only switch
  (`--disable-gprofng`) plus a comment, with no per-target copies. The
  `--disable-gprofng` reason — Android lacks the pthread cancellation APIs
  gprofng uses — is a genuine platform fact and belongs in that file.
- Every other flag is package-level and correct: `--enable-ld=default`
  (unregular BFD), `--enable-plugins`, `--enable-shared`,
  `--disable-werror` (right: the tree has no reason to inherit upstream's
  warning policy, and a cross toolchain build is exactly where new warnings
  appear), `--enable-64-bit-bfd`, `--enable-new-dtags`, `--with-system-zlib`
  with `require("zlib")`, `--enable-default-hash-style=gnu`. Nothing is
  hardcoded to a target.
- `make -j1 tooldir="$OUT"` / `make -j1 tooldir="$OUT" install` are serial.
  binutils is one of the few packages in this prefix that legitimately wants
  `--enable-shared`: `libbfd` and `libopcodes` are consumed by other tools,
  and a static-only binutils would force every consumer to relink them.
- `--disable-werror` deserves credit — it is the same latent trap as cJSON's
  `-Werror` and meshoptimizer's `MESHOPT_WERROR`, and this recipe avoids it.

## Two observations, neither a reject reason

1. **`generic.lua:17` and `android.lua:20` touch a `config.h.in` that does not
   exist.** binutils has no top-level config header — `configure.ac` never
   calls `AC_CONFIG_HEADERS`. Its templates are all in subdirectories
   (`libctf/config.h.in`, `libsframe/config.h.in`,
   `gprofng/common/config.h.in`, `zlib/zconf.h.in`), none of which binutils'
   top-level `config.status` uses. The `touch` therefore creates a stray empty
   `config.h.in` and protects nothing — but there is also nothing to protect,
   so the guard is harmless. Cosmetic; fix when the file is next edited by
   dropping `config.h.in`:
   ```
           touch aclocal.m4 configure
   ```
2. `tooldir="$OUT"` on the make line. `--prefix=$OUT` is already in
   `$AUTOCONF_CONFIGURE_FLAGS`, and binutils computes `tooldir` from
   `$(prefix)/$(target_alias)`, so naming it explicitly is a belt-and-braces
   reaffirmation. Since binutils is `[x]` and the nest is populated, the
   installed layout is whatever it is — the builder should record the actual
   path rather than assume `$OUT/bin`, because with only `--host` (no
   `--target`) `target_alias` is the host alias and the explicit
   `tooldir="$OUT"` is what decides it.

## Carried to the build

- `bin/ld`, `bin/as`, `bin/objdump`, `bin/objcopy`, `bin/strip`, `bin/nm`, `bin/ar`, `bin/ranlib` — `[ -x bin/ld ]` and `[ -x bin/objdump ]`. Record the real directory if it is not `bin/`.
- `lib/libbfd-*.so`, `lib/libopcodes*.so` — `[ -f lib/libbfd-2.45.so ] || ls lib/libbfd*`. The `.so` is expected and correct here; it is not the freetype mistake.
- `include/bfd.h`, `include/dis-asm.h` — `[ -f include/bfd.h ]`.
- `lib/libctf.so` / `lib/libsframe.so` — present unless `--with-ctf`/`--with-sframe` were off; record which.
- The check that matters: **this is the prefix's own toolchain.** `file` on any installed binary should show a *target* ELF (`elf64-littleaarch64` on Android, `pei-x86-64` on mingw), not a host one. If `bin/objdump` is host x86-64 ELF, the recipe configured for the build machine rather than the target and the whole package is wrong.
- **Never run any installed binutils binary.**
