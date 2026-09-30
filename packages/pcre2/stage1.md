# pcre2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 10.45 (GitHub release asset)
- Build system: autotools
- Installs: static `libpcre2-8.a`, `libpcre2-16.a`, `libpcre2-32.a` **plus**
  `libpcre2-posix.a` (the POSIX wrapper, which is on by default), the
  `pcre2.h` family, and five `.pc` files: `libpcre2-8`, `libpcre2-16`,
  `libpcre2-32`, `libpcre2-posix`.
- Requires: `pcre2@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Three `--enable-pcre2-*` switches build all three width variants from one source tree — pcre2 supports that with a single set of objects and a width macro, so it is one build, not three. `--disable-cpp` is the important one: `pcre2grep` is the only C++ part, and the recipe's comment at `:6-8` correctly notes that the grep programs are still built (C `pcre2grep` without the C++ one). JIT is left on, and pcre2's JIT uses a bundled copy of the SLJIT assembler rather than a system one, so no external assembler is needed. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. pcre2 is portable C with its own bundled SLJIT
assembler; its only libc surface is `malloc`, `memcpy` and `bsearch`. The JIT
generates code at runtime into a buffer, which requires `mmap` with
`PROT_EXEC` — Bionic has that at every API level. No API-gated symbol.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **Four archives, and `libpcre2-posix.a` is the one that surprises
   people.** The POSIX wrapper (`pcre2_compile` with the POSIX wrapper API) is
   built by default and is *not* mentioned in the recipe's comment, which only
   discusses the C++ question. It is a legitimate artifact, but a consumer
   linking `libpcre2-posix.a` also needs `libpcre2-8.a`, and the `.pc` chain
   has to express that. Same latent consumer-link class as lcms2 and libarchive.
2. **JIT is enabled and that is a deliberate, defensible default** — the
   recipe does not pass `--disable-jit`. Worth a reviewer's attention for a
   different reason: **JIT-generated pages are executable memory.** On Android
   that is fine for an app that can already generate code, but it is a policy
   consideration for a prefix intended for a phone. A `.pc` consumer that turns
   JIT off would need `-DPCRE2_CONFIG_JIT=0` at compile time, and pcre2's
   headers handle that. Not a defect — a decision worth recording.
3. **The recipe's comment says "The grep/pcre2grep programs are still built"
   (`:7-8`), which is confusing wording** — `pcre2grep` is the C++ one being
   disabled, and the remaining program is `pcre2grep` built as C (pcre2 ships
   both `pcre2grep.c` and a C++ variant). What lands in `$OUT/bin/` should be
   checked to confirm exactly one binary. **A reviewer should read the log and
   record what actually got installed**, because the comment is ambiguous about
   whether any program is expected at all.
4. **`--disable-cpp` also affects the `pcre2test` and `pcre2_jit_test`
   programs** — they are C already, so they should still build. Check
   `ls $OUT/bin/`.
5. `topackage.md` records this as built: *"static libpcre2-8/16/32 plus
   libpcre2-posix, JIT on; pkg-config --modversion …"*. **That entry names
   `libpcre2-posix` explicitly**, which confirms the artifact set in risk 1 and
   shows the comment above is the outlier. Consistent and accurate.
6. `make -j1` is present at `:12` — correct.

**How to verify once built.**

- `lib/libpcre2-8.a`, `libpcre2-16.a`, `libpcre2-32.a` and
  `libpcre2-posix.a` all exist.
- `include/pcre2.h` exists.
- `pkg-config --modversion libpcre2-8` reports 10.45; the 16 and 32 variants
  report the same.
- `pkg-config --static --libs libpcre2-posix` must name `libpcre2-8` — that is
  the check for risk 1.
- `$OBJDUMP -f lib/libpcre2-8.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libpcre2-8.a | grep -cw pcre2_compile` non-zero.
- `ls $OUT/bin/` — record exactly what is there. One C `pcre2grep` and no C++
   one is the expected result; a `pcre2test` is fine too.
- `llvm-nm --undefined-only lib/libpcre2-8.a | grep -cw sljit_compile` —
  non-zero proves the bundled SLJIT is linked in, which is what makes JIT work
  without an external assembler.
