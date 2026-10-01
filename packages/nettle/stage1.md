# nettle build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 3.10.2
- Build system: **autotools**. The 3.9.1 tarball ships a generated
  `configure`, `Makefile.in` and a top-level `config.h.in`, so nothing needs
  autoreconf.
- Installs: `lib/libnettle.a`, `lib/libhogweed.a` (static);
  `include/nettle/*.h`, `include/hogweed/*.h`;
  `lib/pkgconfig/nettle.pc`, `lib/pkgconfig/hogweed.pc`
  (`configure.ac:1234` lists both).
- Requires: `gmp` (exists in this prefix) — nettle's bignum arithmetic needs
  it, and `--disable-mini-gmp` forces the real one rather than nettle's
  bundled shim. `nettle@source` otherwise.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | nettle is C89/C99 plus **hand-written assembly**, and that is the whole uncertainty — not libc. Its C sources use only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<math.h>`, `<errno.h>`, `<stdint.h>`, `<inttypes.h>` and `<alloca.h>`; no `nl_langinfo`, no `getsubopt`, no `scandir`, no `fread_unlocked`, no `argp_parse`, no `mktime_z`, no `posix_spawn`. The blocker candidate is `--enable-assembler` (default yes): nettle ships `arm/aes-encrypt-internal.asm` and a large `arm/neon/` tree, m4-processed to aarch64 assembly at configure time, and I have not assembled any of it. What would settle this row: build it and read the first assembler diagnostic, if any. |
| aarch64-android24 | UNCERTAIN | Same single unknown as the API-21 row — nothing in nettle is API-level gated. |
| aarch64-android35 | UNCERTAIN | Same. |
| x86_64-android35 | WILL BUILD (moderate confidence) | x86_64 is nettle's best-trodden architecture and the assembly is the same plain GAS that any clang target accepts. Moderate rather than high only because I did not check whether nettle's x86_64 path reaches for an assembler feature the NDK clang's integrated assembler lacks — nettle historically prefers a *real* `as` over the integrated assembler. |
| x86_64-mingw | UNCERTAIN | nettle does have a Windows path, but its configure prefers a PE-capable assembler setup that I did not verify, and nettle's `arm/` tree is irrelevant here while `x86_64/` is not. Flagged, not claimed. |
| clang-native | WILL BUILD | Native glibc x86_64 with the system assembler — the configuration nettle's own CI covers most. |

## API level notes

**21 is the floor as far as libc goes.** nettle is arithmetic: it wraps
AES, ChaCha, GCM, Poly1305, SHA-2/3, Ed25519/448, Curve25519/448 and RSA/EC
primitives, none of which touches a platform interface. There is no
`nl_langinfo`, no `getsubopt`, no `mktime_z`, no `posix_spawn`, no
`process_vm_readv`, no `fread_unlocked`, no `scandir`/`versionsort`, no
`argp_parse`. **The API level is simply not the variable for this package —
the assembly is.**

## Risks / what a reviewer should check

- **Do not pass a pic flag to nettle.** An earlier version of this recipe
  passed `--with-pic`, which is not a nettle option. nettle's
  `configure.ac:60-62` is `AC_ARG_ENABLE(pic, AS_HELP_STRING([--disable-pic],
  ...), [enable_pic=yes])`: PIC is **on by default** and the only flag is the
  negative one. A `--with-pic` is accepted silently with a
  "WARNING: unrecognized options" line and configure continues, so the
  mistake is invisible in a passing build. The recipe now passes neither.
- **`--disable-mini-gmp` is the interesting switch.** nettle bundles a small
  GMP shim (`mini-gmp.c`) and uses it when it finds no external GMP. The
  prefix *has* a real GMP, so letting nettle find it is better than the shim;
  passing `--disable-mini-gmp` makes that explicit rather than dependent on
  configure's search order. If it turns out nettle's own detection finds the
  prefix's GMP anyway, the flag is belt-and-braces.
- **The config template really is top-level `config.h.in`.** nettle uses the
  *singular* `AC_CONFIG_HEADER([config.h])` at `configure.ac:11`, not the
  plural `AC_CONFIG_HEADERS`, and the tarball ships `config.h.in`,
  `Makefile.in` and `configure` at the top level — verified by listing the
  archive. This is the eighth distinct spelling question this wave has
  turned up, and the answer here is the ordinary one.
- **`AC_CONFIG_AUX_DIR([.])` puts the aux scripts in the top level**, not a
  `build-aux/` subdirectory, so there is no separate directory to guard.
  `find . -name 'Makefile.in' | xargs touch` still covers
  `tools/`, `testsuite/` and `examples/`, which `configure.ac:1233` generates.
- **The `testsuite/` is a host test suite that must RUN.** nettle's
  `testsuite/` contains C programs that link against the just-built library
  and execute it. Nothing in this recipe runs them — `make` and `make
  install` do not build or run `check_PROGRAMS` unless `make check` is
  invoked, and nothing here invokes it — so no target binary is executed.
  Worth stating explicitly because it is the rule nettle is most likely to
  break.
- **`--disable-documentation` avoids the texinfo manual.** Without it, nettle
  would want `makeinfo`/`sgml2texi` on the build host. That is a host-tool
  dependency, not a cross problem.

## How to verify once built

- `lib/libnettle.a`, `lib/libhogweed.a`
- `include/nettle/aes.h`, `include/nettle/version.h`, `include/hogweed/curve25519.h`
- `lib/pkgconfig/nettle.pc` and `pkg-config --modversion nettle` → `3.9.1`
- `readelf -h lib/libnettle.a` → `Machine: AArch64` on Android targets
- `llvm-nm --undefined-only lib/libnettle.a | grep -c '__gmp'` → **0** if
  `--disable-mini-gmp` worked and the prefix's GMP was used; non-zero means
  nettle compiled its own `mini-gmp` shim instead
- `lib/liblzma.so*` must be **absent** — nettle can optionally use liblzma
  for LZMA and `--disable-documentation` is unrelated to it; if a
  `liblzma` reference shows up in the archive, note which switch pulled it
  in
