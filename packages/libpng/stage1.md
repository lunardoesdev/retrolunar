# libpng build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.6.48
- Build system: autotools
- Installs: static `libpng16.a` (and `libpng.a`), `png.h`/`pngconf.h`,
  `libpng16.pc` and `libpng.pc`. The `pngfix` tool and the test programs are
  not installed by this recipe.
- Requires: `zlib` (exists) — passed as `--with-zlib-prefix="$PREFIX"`.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Two things carry this recipe. First, the zlib-name workaround at `generic.lua:12-16`: on mingw this tree's zlib installs as `libzlib`, but libpng's `configure` zlib probe *hardcodes* `-lz` and prepends it itself, so `LIBS` cannot override it and a missing `-l` is a hard configure error. The recipe therefore creates `libz.* → libzlib.*` symlinks in `$PREFIX/lib`, guarded so it never overwrites and skips absent files. On Android the loop finds no `libzlib.*` and does nothing, so the recipe is inert there and correct. Second, `--with-zlib-prefix="$PREFIX"` at `:17` makes the probe look in this tree rather than the NDK's ancient zlib. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | This is the system the workaround exists for, and it is what the AGENTS.md:263-265 name-mismatch trap describes verbatim. With the symlinks in place the `-lz` probe resolves. |
| clang-native | WILL BUILD | As above; the loop is inert (host zlib is already `libz.so`). |

**API level notes.** libpng is portable C; its only libc surface is `stdio`,
`malloc` and `setjmp`/`longjmp`. Nothing API-gated. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The symlink workaround is a good example of the pattern AGENTS.md wants
   and should not be removed.** It is commented, additive, guarded (`[ -f … ] ||
   continue`, then `[ -f … ] ||` before linking so an existing `libz` is never
   clobbered), and it benefits any later `-lz` user. It also writes into
   `$PREFIX` rather than `$OUT` — deliberately, because the probe happens at
   configure time before `$OUT` exists, and because AGENTS.md records this
   exact libpng/zlib interaction as the canonical case.
2. **A real asymmetry: the recipe mutates `$PREFIX`, which is shared and
   persists.** The `if fresh … else … fi` block means the symlinks are only
   created on a rebuild, and they survive into the published prefix. That is
   intended (the comment says "benefits any later `-lz` user too"), but a
   reviewer should be aware that this package has a side effect outside `$OUT`
   that no other recipe in the shard has.
3. **Two libraries are installed, and the `.pc` names matter.**
   libpng 1.6 installs both `libpng16.a` (the ABI-versioned name) and a
   `libpng.a` compatibility name, with `libpng16.pc` and `libpng.pc`. A
   consumer must pick one deliberately. `topackage.md` has no entry for this
   package, yet `opencv` and `pngprobe` both `require()` it, so it is
   load-bearing and unrecorded.
4. **The source URL has a mirror fallback** (`source.lua:7`), SourceForge
   first and the GitHub tag archive second. Good: SourceForge downloads are
   the flakiest thing in this tree. The GitHub archive has no generated
   `configure`? Actually it does for libpng (it ships pre-generated
   autotools), so the fallback is sound.
5. `make -j1` is present at `:20` — correct.
6. **`topackage.md` has no entry for libpng** while four packages depend on
   it. That is a gap in the backlog, not a gap in the recipe.

**How to verify once built.**

- `lib/libpng16.a` exists; `include/png.h` and `include/pngconf.h` exist.
- `pkg-config --modversion libpng16` reports 1.6.48.
- `$OBJDUMP -f lib/libpng16.a` prints `elf64-littleaarch64` on Android.
- **On mingw specifically:** `ls -l $PREFIX/lib/libz.*` should show symlinks
  into `libzlib.*`. If they are missing, a fresh build of libpng will fail its
  zlib probe.
- `pkg-config --static --libs libpng16` must name `zlib` (or `libz`).
- `grep PNG_LIBPNG_VER_STRING include/png.h` confirms the header matches the
  archive.
