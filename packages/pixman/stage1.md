# pixman build forecast

- Recipe: `generic.lua`, source `source.lua`; plus `android.lua` for the one
  Android-only switch
- Version pinned: 0.46.4
- Build system: **meson** (meson.build:21-28, `meson_version: '>= 1.3.0'`;
  this prefix's meson is 1.12.1)
- Requires: `pixman@source` only. pixman has no library dependencies:
  meson.build:466-467 probes `libm` and `threads`, both supplied by the
  toolchain, and nothing else is unconditional.
- Installs: `lib/libpixman-1.a`, `include/pixman-1/pixman.h`,
  `include/pixman-1/pixman-version.h`, `lib/pkgconfig/pixman-1.pc`
  (pixman/meson.build:30,122-131,141; meson.build:614-621)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The generic recipe's six switches cover it: no dependency to resolve, and `default_library=static`, `tests`/`demos`/`libpng`/`gtk`/`openmp` all off. `android.lua`'s `-Darm-simd=disabled -Dneon=disabled` is inert here — meson.build:290,306,322 gate those three ARM paths on `host_machine.cpu_family()`, which the aarch64 cross files set to `aarch64`, so only `a64-neon` can turn on. It defines `USE_ARM_A64_NEON` (meson.build:330), a macro pixman-arm.c:36 does **not** test, so aarch64 never enters the `cpu-features.h` branch and keeps full NEON. Nothing in pixman needs an API above 21: meson.build:497 probes `sigaction`, `alarm`, `mprotect`, `getpagesize`, `mmap`, `gettimeofday`, `posix_memalign` — all long-standing Bionic. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same reasoning; additionally meson.build:183-185 enables SSE2 outright on an `x86_64` cpu_family, and meson.build:499-501 *excludes* `posix_memalign` from the probe list only on `windows`, so it is probed here and Bionic has it. |
| x86_64-mingw | WILL BUILD | `meson.build:499` skips the `posix_memalign` probe on non-`windows` hosts precisely because mingw claims it and lacks it, and meson.build:526-545 takes the `__declspec(thread)` branch for TLS. `meson.build:431-441` skips the OpenMP probe for msvc-style compilers only, which is why `-Dopenmp=disabled` is not merely tidy. |
| clang-native | WILL BUILD | The generic recipe verbatim; no Android recipe is consulted. meson.build:583-585 sets `WORDS_BIGENDIAN` only on a big-endian host, and this is little-endian x86_64. |

## API level notes

**21 is the floor and pixman clears it.** The only libc surface meson probes
is meson.build:497-507's list, plus `fenv.h`/`sys/mman.h`/`unistd.h` at
:516-524. None of those is on the API-21 wall list.

## Risks / what a reviewer should check

1. **`android.lua` is load-bearing for `armv7a-android*` and only there.**
   pixman-arm.c:96-123 is an `#elif defined(__ANDROID__) || defined(ANDROID)`
   branch that does `#include <cpu-features.h>` and calls
   `android_getCpuFamily()`/`android_getCpuFeatures()`. That header is AOSP's,
   not Bionic's: `find $NDK/sysroot -name 'cpu-features*'` returns **zero**
   hits, while the sysroot is otherwise readable (`stdio.h` is 15887 bytes).
   Compiling pixman-arm.c with `-DUSE_ARM_NEON` against
   `armv7a-linux-androideabi35-clang` reproduces it directly —
   `fatal error: 'cpu-features.h' file not found` at pixman-arm.c:98. The same
   compile on `aarch64-linux-android35-clang` with `-DUSE_ARM_A64_NEON` does not
   reach that line, which is the aarch64/armv7a asymmetry above.
   **Cost: armv7a loses the SIMD and NEON fast paths.** Upstream's alternative
   is the `cpu-features-path` option (meson.options:81-85), which wants a local
   copy of AOSP's cpu-features.c/h; there is no such package here, and
   vendoring one is the forbidden patch-shaped answer.
2. **The claim in `generic.lua` that pixman has no dependencies is worth one
   check.** It rests on meson.build:466-467 being the only unconditional
   `find_library`/`dependency`. `libpng` (meson.build:447-461) and
   `gtk+-3.0`/`glib-2.0` (meson.build:443-444) are conditional on options that
   are off, and every SIMD option is gated on `host_machine.cpu_family()`.
3. **`-Dopenmp=disabled` is real, not cosmetic.** Left on auto,
   meson.build:432's `dependency('openmp', required: auto)` resolves to the
   NDK's libomp and sets `USE_OPENMP` (meson.build:434). Its only consumers are
   `pixman/test/composite.c:512` and the blue-noise generator — neither built
   here — but the define would still be in the shipped `pixman-config.h`.

## How to verify once built

- `lib/libpixman-1.a` — a `.a`, not a `.so`, which is the direct check that
  `-Ddefault_library=static` took effect
- `include/pixman-1/pixman.h` and `include/pixman-1/pixman-version.h`
- `lib/pkgconfig/pixman-1.pc`; `pkg-config --modversion pixman-1` → `0.46.4`
- `grep PIXMAN_VERSION build/pixman/pixman-version.h` → `0.46.4`, proving
  meson.build:593-596 split the version correctly
- `$OBJDUMP -f lib/libpixman-1.a` → `elf64-littleaarch64` on Android
- `grep -c '^libpixman' nest/$SYS/lib/pkgconfig/pixman-1.pc`-style scoping:
  the .pc belongs to pixman alone, so grep it by name
- On `armv7a-android*` only: `$OUT/bin` must not exist, and the meson summary
  must not list an arm-simd or arm-neon implementation. On `aarch64-android*`
  a NEON implementation **should** be listed — its absence would mean
  `android.lua` over-disabled.