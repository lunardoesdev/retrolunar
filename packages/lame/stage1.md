# lame build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.100 (SourceForge release tarball, the last upstream
  release — LAME has been unmaintained for years)
- Build system: autotools
- Installs: static `libmp3lame.a`, the `lame/` headers, and `include/mp3lame.h`.
  **No tools and no `lame` frontend** — `--disable-frontend` at
  `generic.lua:6`, alongside `--disable-gtktest` and `--disable-nasm`.
- Requires: `lame@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-frontend` removes `lame`, `lamedec`, `mpglib` decode and the GTK front-ends, all of which are host programs and would be target binaries. `--disable-gtktest` and `--disable-nasm` remove the GUI test driver and the hand-written x86 asm (which cannot be assembled for aarch64 or armv7a anyway). What remains is `libmp3lame/`, pure C. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; nothing in `libmp3lame/` is arch-conditional. |
| x86_64-mingw | WILL BUILD | As above, though LAME's Windows support is mostly in the frontend, which is off. |
| clang-native | WILL BUILD | As above. |

**API level notes.** `libmp3lame/` is portable C using only `stdio`, `stdlib`
and `math`. It is a plausible candidate for the `stderr`-as-a-symbol wall in
principle, but it writes diagnostics with `fprintf(stderr, …)` rather than
`fprintf(STDERR_FILENO, …)`, so it does not hit it. No `posix_spawn`, no
`O_BINARY` (that is a Windows-only concern, and the tools are off). No API
level dependency. `armv7a-android*` and `i686-android*` match `aarch64-*`.

**Risks / what a reviewer should check.**
1. **The recipe installs selectively and that is deliberate:**
   `make -C libmp3lame install` then `make -C include install`
   (`generic.lua:10-11`) rather than a top-level `make install`. That is what
   keeps the `frontends/` and `doc/` install rules out. Do not "simplify" it to
   `make install` — that would pull in the disabled-but-still-listed binaries.
2. **`--disable-nasm` matters more than it looks.** LAME's `configure` probes
   for NASM to assemble the x86-only `l3tabspeed`/`takeh_wav` paths. Leaving
   it on would make configure fail on aarch64 (no assembler for that flavour)
   and produce a broken x86_64-Android library. This is a genuine
   architecture-dependent switch chosen in a system-neutral way — good.
3. **The `.pc` situation: LAME 3.100 ships `mp3lame.pc`**, configured from
   `libmp3lame/mp3lame.pc.in` and installed by `make -C libmp3lame install`. So
   `pkg-config --modversion mp3lame` should report 3.100. Worth confirming
   because the recipe's comment does not mention the `.pc` at all.
4. `-lm` is needed by `libmp3lame` and the Android systems' `LDFLAGS` already
   carry it (`aarch64-android24/generic.lua:79`), so the static archive's
   consumers are covered without a recipe change.
5. **LAME 3.100 is unmaintained.** It predates modern toolchains; the main
   practical risk is a newer NDK's clang defaulting to a C standard LAME's 2007
   C does not satisfy. The NDK defaults to C23 per AGENTS.md:236, which is the
   kind of thing that turns a 2007 C file into a wall. Nothing in the recipe
   sets `-std=`. That is the one thing I would want a real build to confirm.

**How to verify once built.**

- `lib/libmp3lame.a` exists.
- `include/lame/lame.h` and `include/mp3lame.h` exist.
- `pkg-config --modversion mp3lame` reports 3.100.
- `$OBJDUMP -f lib/libmp3lame.a` prints `elf64-littleaarch64` on Android.
- `ls $OUT/bin/` must be **empty or absent** — a `lame` binary here means
  `--disable-frontend` regressed.
