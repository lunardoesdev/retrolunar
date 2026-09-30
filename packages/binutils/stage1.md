# binutils build forecast

- Recipe: `generic.lua` **and** `android.lua`, source `source.lua`
- Version pinned: 2.45
- Build system: autotools
- Installs: `ld`, `as`, `objdump`, `objcopy`, `strip`, `nm`, `readelf`, `size`, `strings`, `addr2line`, `ar`, `ranlib`, `c++filt`, `elfedit`, `gprofng`-adjacent tools; plus `libbfd`, `libopcodes`, `libsframe`; **no `.pc`**
- Requires: `zlib` (exists, 1.3.1), `binutils@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `android.lua:14-24` passes `--disable-gprofng`, and the recipe comment names the reason: "Android lacks pthread cancellation APIs used by gprofng". gprofng's `libprocmaps/` and `BPF/` code calls `pthread_cancel`, which Bionic did not expose until API 24+ and never in the same shape. With gprofng off, the rest of binutils is BFD/ELF manipulation that only needs `<elf.h>`, `<link.h>` and `dl_iterate_phdr`-free code, all present at API 21. `--with-system-zlib` points at this prefix's zlib. |
| aarch64-android24 | WILL BUILD | Same recipe. Even so, gprofng stays off here because the recipe is per-family, not per-level — one `android.lua` covers every level, so the same safe configuration is used at 24 and 35. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same code; the Android recipe names tools explicitly rather than relying on PATH (no cross bin dir on PATH per AGENTS.md:321-325). |
| x86_64-mingw | **UNCERTAIN** | `generic.lua` is used. The ELF-specific parts (BFD's ELF targets, `libopcodes`, `elfedit`, `strings` over ELF) build but are useless on a PE target, and `generic.lua:8` passes no `--target` or `--disable-*` to prune them. Whether the build *completes* is the question: the Darwin/WASI target support in BFD is broad enough that 2.45 usually configures for `x86_64-w64-mingw32`, but `--enable-ld=default` selects the ELF linker, which mingw-w64 has no use for. I am not claiming it fails; I am saying the recipe has never been shaped for this target and the forecast rests on BFD's target list rather than on evidence. |
| clang-native | WILL BUILD | Native x86_64 Linux; this is the configuration binutils CI tests most. topackage.md:13 records Binutils 2.45 as `[x]` with the gprofng note. |

## API level notes

**gprofng is the API-level variable and the recipe already handles it.**
Android's `pthread_cancel` was not a stable, linkable symbol at API 21;
`android.lua:17` disables gprofng for *every* Android level rather than
enabling it at 24+, which is the conservative and correct choice. Nothing
else in binutils needs a level above 21. In particular `-lm` is already in
the Android systems' `$LDFLAGS` (aarch64-android21/generic.lua:78), which
BFD's floating-point-adjacent code and `strings` benefit from.

## Risks / what a reviewer should check

- **`--enable-shared` is on** (`android.lua:16`, `generic.lua:8`). This is
  the one binutils recipe in the repo that deliberately builds shared
  libraries, because `libbfd` and `libopcodes` are useful to build tools
  that link back into the prefix. That is a deliberate departure from the
  static-everywhere norm and is worth a reviewer's attention rather than a
  "fix".
- **`make -j1 tooldir="$OUT"`** (`android.lua:26`) is the load-bearing line.
  binutils installs relative to `tooldir`, which defaults to `$(exec_prefix)
  /../$(target_alias)`. Without this the tools land outside the prefix.
  Getting it wrong is silent — the build succeeds and installs nowhere.
- **`android.lua` and `generic.lua` differ by exactly one line**
  (`--disable-gprofng`, `android.lua:17`). Good, intentional, and easy to
  desynchronise.
- **The mingw row is the open question.** `tooldir` is passed, so the
  install location is right; whether the ELF linker configures at all on a
  mingw host is what I could not settle.

## How to verify once built

- `bin/ld`, `bin/as`, `bin/objdump`, `bin/readelf`
- `lib/libbfd-2.45.so` (shared, per `--enable-shared`)
- `file bin/ld` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- `$OBJDUMP --version` output — but only read it, never run the binary on
  the build host
- `ls $OUT/*/ld` if the tool landed in a `tooldir` subdirectory instead of
  `bin/`; a missing `bin/ld` with a present `$OUT/x86_64-linux-android/bin/ld`
  means the `tooldir` override regressed
