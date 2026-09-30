# jansson build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.14 (release asset `jansson-2.14.tar.gz`, not the git tag
  archive — jansson's releases carry a real dist tarball with a generated
  `configure`)
- Build system: autotools
- Installs: static `libjansson.a`, `jansson.h`, `jansson_config.h` and
  `jansson.pc`. No tools.
- Requires: `jansson@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--enable-static --disable-shared --with-pic` at `generic.lua:9` is the whole configuration. jansson is a small C library using malloc and stdio; nothing in it is API-gated. The timestamp guard at `:10-11` prevents the tarball's mtimes from triggering an `aclocal-1.17` re-run the prefix does not have. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; the archive is PE COFF, and `-fPIC` from the system's `$CFLAGS` is harmless on Windows. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. jansson calls `malloc`, `free`, `vsnprintf`,
`strtod` and file I/O — all present at every Bionic API level. The Android
walls listed at AGENTS.md:368 (`stderr` as a symbol, `posix_spawn`,
`mblen`/`getpass`, `O_BINARY`, `process_vm_readv`, `POSIX_MADV_*`) do not
apply. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. This is one of the simplest recipes in the tree and it matches the house
   pattern exactly — the same shape as `c-ares` and `libogg`. Nothing to fix.
2. The switches are all upstream defaults for this project's release tarball
   rather than things that must be disabled: jansson's test suite is not built
   by `make install` anyway. The recipe is defensive, not corrective.
3. `topackage.md:149` records this as built: *"static libjansson.a;
   pkg-config --modversion jansson reports 2.14; archive members are
   elf64-littleaarch64."* The recipe as it stands is consistent with that
   entry, so nothing here contradicts the backlog.

**How to verify once built.**

- `lib/libjansson.a` exists.
- `include/jansson.h` and `include/jansson_config.h` exist — the config header
  is the one people forget, and a consumer including only `jansson.h` needs it.
- `pkg-config --modversion jansson` reports 2.14.
- `$OBJDUMP -f lib/libjansson.a` prints `elf64-littleaarch64` on Android.
- Rerun prints `skip jansson (fresh)`.
