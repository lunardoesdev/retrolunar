# lz4 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.10.0 (GitHub release asset)
- Build system: **plain make** — upstream ships a hand-written `lib/Makefile`
  and `programs/Makefile`, not autotools and not cmake. So neither
  `$AUTOCONF_CONFIGURE_FLAGS` nor `$CMAKE_FLAGS` applies, and **no autotools
  timestamp guard is needed**. The recipe passes `PREFIX="$OUT"` because that
  is how lz4's own makefiles expect to install into a staged prefix.
- Installs: static `liblz4.a`, `lz4.h`, `lz4hc.h`, `lz4frame.h`,
  `liblz4.pc`, and the `bin/lz4` and `bin/lz4c` command-line tools.
- Requires: `lz4@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `make -C lib PREFIX="$OUT" BUILD_SHARED=no BUILD_STATIC=yes` is the documented interface. `BUILD_SHARED=no` is the switch that matters: a shared liblz4 on a target with no loader path is useless here, and it is the tree-wide policy. The library is freestanding C. The tools are target binaries that are built but, per the rules here, must never be run. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | lz4's `programs/Makefile` is POSIX-flavoured and its install paths use `INSTALL` variables that lz4 1.10 does define for Windows, but the `lib/Makefile`'s own defaults are tuned for a Unix prefix. The library half is certainly fine; what would settle it is whether `make -C programs PREFIX="$OUT" install` places `lz4.exe` where expected. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. liblz4 is assembly-optional freestanding C: the
pure-C decoder path is always compiled and the asm is selected by the
compiler, not by a separate assembler. No libc dependency beyond `malloc`,
`memcpy` and `read`/`write` in the frame code. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **This recipe keeps two executables, and that is a deliberate choice worth
   reviewing.** `make -C programs` installs `bin/lz4` and `bin/lz4c`. Unlike
   libuv's tools — where the recipe's own justification was wrong — these have a
   defensible reason: they are lz4's *only* user-facing interface, and
   `topackage.md:52` records both as real verified target binaries
   (*"bin/lz4 is 'ELF 64-bit LSB pie executable, ARM aarch64, for Android 24,
   built by NDK r28c'; bin/lz4c also installed"*). So a consumer on a device can
   run them. They must still never be run **here**.
2. **`make -C programs PREFIX="$OUT"` at `generic.lua:10` is followed by a
   separate `install` at `:11`.** That is lz4's two-step idiom and it is
   correct — `make -C programs` alone builds in place. Do not collapse them.
3. **No `-j1` equivalent, and none is available.** `make` here is upstream's
   own, and the recipe does not pass `-j1`. AGENTS.md:225-229 asks for a
   serial build; with upstream's makefile and no wrapper, that is a soft
   deviation. The default `make` is already serial, so it is compliant in
   effect.
4. **`topackage.md:52` confirms this recipe works**, including the
   `elf64-littleaarch64` archive members. Consistent.
5. **The static-only choice means no `liblz4.so`.** Worth confirming, because
   a consumer expecting the shared library will not find it — that is
   intentional (`BUILD_SHARED=no`) and matches the tree's static policy.

**How to verify once built.**

- `lib/liblz4.a` exists; `include/lz4.h`, `lz4hc.h` and `lz4frame.h` exist.
- `lib/liblz4.so` must **not** exist — `BUILD_SHARED=no` is deliberate.
- `pkg-config --modversion liblz4` reports 1.10.0.
- `bin/lz4` and `bin/lz4c` exist. `file bin/lz4` must report
  `ELF 64-bit LSB pie executable, ARM aarch64, for Android 24, built by NDK r28c`
  — the exact string `topackage.md:52` already recorded.
- `$OBJDUMP -f lib/liblz4.a` prints `elf64-littleaarch64`.
- `llvm-nm --defined-only lib/liblz4.a | grep -cw LZ4_decompress_safe`
  non-zero.
- **Do not run `bin/lz4`.** Static inspection only.
