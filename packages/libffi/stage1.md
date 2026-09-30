# libffi build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.8.0 (GitHub release asset)
- Build system: autotools
- Installs: `libffi.a` **and** `libffi.so` (the recipe passes no
  `--enable-shared`/`--disable-shared`, so libffi's own defaults apply and it
  builds both), `ffi.h`, `ffitarget.h`, `libffi.pc`. Also the `libffi.map`
  version script and, on some systems, `include/ffi_decl.h`.
- Requires: `libffi@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe is a bare `./configure $AUTOCONF_CONFIGURE_FLAGS` with no switches (`:6`) — libffi needs none here. The one thing that matters is `src/arm64/ffi.c` and `src/arm/ffi.c`, which are the architecture dispatch the autoconf-generated `fficonfig.h` selects, and AArch64 is one of libffi's best-supported targets. No API-gated symbol: libffi builds raw stack frames and calls through them, so it depends on no libc function at all. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; `src/x86/ffi64.c` and `src/x86/ffiw64.c` are equally mature. |
| x86_64-mingw | WILL BUILD | As above. mingw's x86-64 unwinder works, and libffi builds shared libraries here without a loader-path problem because the target has one. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None, and this is worth stating more strongly than for
most packages: **libffi has essentially no libc surface.** It is the one
library in the tree that is *about* not calling libc — it manipulates the
frame chain and jumps to addresses directly. Nothing in it is API-gated, so
the Android level is genuinely irrelevant and `armv7a-android*` and
`i686-android*` match `aarch64-android*` with no caveat.

**Risks / what a reviewer should check.**

1. **This recipe builds a shared library where the rest of the tree builds
   static.** `topackage.md:48` records it: *"libffi.so is 'ELF 64-bit LSB
   shared object, ARM aarch64, for Android 24, built by NDK r28c'; static
   members are elf64-littleaarch64."* So both exist. That is upstream's
   default and it is harmless — but it is the reason a consumer may find two
   candidates and must know which to ask for. `pkg-config --libs libffi` will
   prefer the shared one. Worth being deliberate about.
2. **`libffi.map` and the version script.** libffi 3.8 uses a linker version
   script to control its exported symbol set. That is a *link-time* mechanism,
   so the shared library's exports are correct, but it means the static archive
   and the `.so` are not interchangeable in symbol visibility. Not a defect —
   just something to know when reading `nm` output.
3. **No `--disable-multi-os-directory`.** libffi defaults to installing headers
   into `libffi/<triple>/include` on some platforms and plain `include/` on
   others. The recorded install (`ffi.h` findable) suggests plain here, but on
   a *different* system family the header path could differ, which would make
   the same recipe produce a different include layout per system. That is the
   main per-system risk in an otherwise system-neutral recipe.
4. **The bare `make` at `:9` is not `make -j1`** — a rule deviation from
   AGENTS.md:225-229, and the same one kbd, less, kmod and intltool have.
5. `topackage.md:48` is accurate and consistent with this recipe.

**How to verify once built.**

- `lib/libffi.a` and `lib/libffi.so` both exist; `include/ffi.h` and
  `include/ffitarget.h` exist.
- `pkg-config --modversion libffi` reports 3.8.0.
- `file lib/libffi.so` reports `ELF 64-bit LSB shared object, ARM aarch64, for
  Android 24, built by NDK r28c`.
- `$OBJDUMP -f lib/libffi.a` prints `elf64-littleaarch64`.
- `llvm-nm -D --defined-only lib/libffi.so | grep ffi_call` must find
  `ffi_call` — this is the real test, because it proves the version script let
  the public symbols through.
- `grep -c 'FFI_TARGET' include/ffitarget.h` is non-zero, confirming the
  architecture dispatch header was generated for this target rather than
  shipped stale.
