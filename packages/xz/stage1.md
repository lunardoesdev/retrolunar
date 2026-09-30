# xz build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 5.8.1
  (`github.com/tukaani-project/xz/releases/download/v5.8.1/xz-5.8.1.tar.xz`)
- Build system: **autotools** — `./configure` at `generic.lua:8-15`, timestamp
  guard at `:16-17`
- Installs: `lib/liblzma.a`, `include/lzma.h`, `include/lzma/*.h` (5.8 added the
  subdirectory), `lib/pkgconfig/liblzma.pc`, `bin/xz`, `bin/lzmainfo`
- Requires: `xz@source` only (`generic.lua:1`). No dependencies — xz is
  self-contained and the recipe disables the optional lzma/zlib backends in the
  tools.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The seven `--disable-*` flags at `generic.lua:9-15` remove every optional subsystem: `--disable-nls` (no gettext), `--disable-unxz`/`--disable-lzmadec`/`--disable-lzmainfo` (the tools that would need zlib/lzma_file I/O helpers), `--disable-lzlinks` (the hardlink/copy variants) and `--disable-doc` (no asciidoc/texinfo). The library itself is `src/liblzma/*.c` and uses only `mmap`, `fopen`, `read`, `write`, `malloc` and `memcpy` — all present at API 21. **No `mktime_z`, no `nl_langinfo`, no `posix_spawn`.** |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; xz's x86-64 assembly (`x86_64.h`, `.S`) is selected by `config.h` at configure time and is plain assembly with no libc dependency. |
| x86_64-mingw | WILL BUILD | As above, plus xz's Win32 `win32/` I/O layer. `topackage.md:87` records a verified mingw-independent Android build producing `lib/liblzma.so` with `ARM aarch64`, which suggests shared libs were enabled there — note that discrepancy below. |
| clang-native | WILL BUILD | Native; same flag set. |

**API level notes.** **No new wall.** xz's decoder is a tight loop over buffers
with no libc surface beyond `memcpy`/`memmove`; the filter chain touches
`fread`/`fwrite`. The one thing worth naming is `src/liblzma/crc64.c`'s
use of `wint_t`/`__uint64_t` under `#ifdef` — that is a compiler question, not
an API one. Nothing needs an API introduced after 21.

**Risks / what a reviewer should check.**
1. **`topackage.md:87` contradicts this recipe on shared vs static.** The
   backlog records that for the verified build `lib/liblzma.so` is an
   `ELF 64-bit LSB shared object, ARM aarch64`. The recipe passes **no**
   `--disable-shared`/`--enable-static`, so it inherits xz's autotools default —
   which for xz 5.x is **shared enabled**. So the recipe as written builds a
   shared `liblzma.so`, unlike almost every other package in this tree
   (`jansson`, `snappy`, `libuv`, `zlib`, `zstd` all force static). **A reviewer
   should decide deliberately**: either that is intended for xz, or
   `--disable-shared --enable-static` should be added. I am not changing the
   recipe — this is a forecast, and the discrepancy is the finding.
2. **The seven `--disable-*` flags are a coherent "minimal library in a target
   prefix" set** and each is explained by the recipe comment at
   `generic.lua:6-7` ("NLS and the unxz/lzmadec helpers are off because gettext
   and the optional lzma tooling are not part of this target prefix"). This is
   good design: upstream switches, no `sed`, no patches.
3. **`bin/lzmainfo` is installed despite `--disable-lzmainfo`** appearing in the
   flag list — no, it does not: `--disable-lzmainfo` at `generic.lua:12`
   disables the *`lzmainfo` tool*, so what installs is the `lzmainfo`
   compatibility shell wrapper only if `--enable-lzlinks` permits it, and that
   is off too. **A reviewer should verify which `bin/` entries actually land**
   rather than assuming from the package name.
4. `make` at `generic.lua:18` is bare (serialises by default); cosmetic, same
   as `sed`, `tar`, `shadow`, `sysklogd`, `texinfo`, `util-linux`, `termcap`.
5. 5.8.1 matches the LFS pin recorded in `topackage.md:87`.

**How to verify once built.**
- `lib/liblzma.a` **and/or** `lib/liblzma.so` (see risk 1 — whichever the
  build produced is the answer), `include/lzma.h`, `include/lzma/*.h`,
  `lib/pkgconfig/liblzma.pc`, `bin/xz`
- `pkg-config --modversion liblzma` → `5.8.1`; `topackage.md:87` records this
  exact check succeeding, so it is the known-good verification
- `llvm-objdump -f bin/xz | head` → `elf64-littleaarch64` on aarch64;
  `file bin/xz` should match the string in `topackage.md:87`
- `strings bin/xz | grep -m1 'XZ Utils 5.8.1'` — the binary cannot be run (no
  emulation)
- **Check risk 1 concretely:** `ls lib/liblzma.*` — if a `.so` is present, the
  recipe did *not* force static, which is the finding to report
- `ls bin/` should show `xz` only (risk 3)