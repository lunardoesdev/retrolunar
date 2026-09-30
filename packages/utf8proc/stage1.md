# utf8proc build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.9.0 (`github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.9.0.tar.gz`)
- Build system: **CMake** (`generic.lua:8`)
- Installs: `lib/libutf8proc.a`, `include/utf8proc.h`,
  `lib/pkgconfig/libutf8proc.pc`, plus a CMake package config
- Requires: `utf8proc@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Two source files, `utf8proc.c` and `utf8proc_data.c`. The generated data file compiles Unicode tables into the archive — it is plain static arrays of `char32_t`/`int32_t`, no locale, no `iconv`, no character-property lookups from libc. `-DBUILD_SHARED_LIBS=OFF` (`generic.lua:8`) gives the archive. utf8proc implements its own case folding and normalisation internally (`utf8proc.c`'s `utf8proc_tolower`/`decompose_char`), so **it does not call `towlower`, `towupper` or `setlocale`** — that is the usual Bionic gap for a Unicode library and it does not apply. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; no arch-specific code. |
| x86_64-mingw | WILL BUILD | As above. utf8proc's CMake has no WIN32-specific source list. |
| clang-native | WILL BUILD | Native; same two files. |

**API level notes.** **No new wall.** utf8proc's entire libc surface is
`malloc`/`free`/`realloc` (for `utf8proc_map`'s output buffer and
`utf8proc_iterate`'s) and, in the optional `utf8proc_*_file` helpers, stdio —
and even those are only used by the `utf8proc_map_file` convenience wrapper,
not by the core. There is no `nl_langinfo` (API 26), no `iconv.h` (API 28),
no `mktime_z` (API 35), and no locale dependency of any kind. The API level is
genuinely inert.

**Risks / what a reviewer should check.**
1. **The build really is two files and nothing host-side.** utf8proc's CMake
   has no tests, examples or benchmarks to turn off — this is the simplest
   CMake recipe in the shard, and the recipe comment at `generic.lua:6-7`
   correctly records *why* there is no separate data install (the tables are
   compiled in). Nothing to scrutinise on the flag front beyond
   `-DBUILD_SHARED_LIBS=OFF`.
2. **`libutf8proc.pc` is the only discovery mechanism**, so its presence matters
   more than for a package that also ships a CMake config. If it were missing,
   consumers would silently fall back to a bare `-lutf8proc`.
3. **The `.pc` name is `libutf8proc`, not `utf8proc`** — that is upstream's
   choice and is easy to get wrong in a consumer's `pkg-config --libs` line.
   Worth a reviewer checking against the actual installed filename rather than
   assuming symmetry with the library.
4. 2.9.0 is the current release line. No upgrade pressure.
5. No `-std=` is pinned. utf8proc is C89/C99-clean and its CMake sets
   `CMAKE_C_STANDARD 99` itself, so there is no language-default problem even
   under the NDK's C23 default. Contrast `packages/libcbor/stage1.md`, where
   upstream's C standard is *not* pinned and the recipe has to do it.

**How to verify once built.**
- `lib/libutf8proc.a`, `include/utf8proc.h`, `lib/pkgconfig/libutf8proc.pc`
- `pkg-config --modversion libutf8proc` → `2.9.0` (note the `lib` prefix —
  risk 3)
- `llvm-objdump -f lib/libutf8proc.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libutf8proc.a | grep -c utf8proc_` → a large
  count, which is the check that the Unicode tables in `utf8proc_data.c` were
  compiled in rather than dropped
- `ls -l lib/libutf8proc.a` should show a multi-megabyte archive; a small one
  means the data table did not compile in, and the library would silently
  mis-handle every non-ASCII character at runtime
- `find $PREFIX -name '*.so*'` → **empty**