ACCEPT

# brotli 1.1.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- `-DBUILD_SHARED_LIBS=OFF` is upstream's own option name for brotli, and it
  gives the three static archives the prefix wants. `cmake --build build
  --parallel 1` is serial, and install goes to `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("brotli@source")` names no missing package, and no `@native` need:
  nothing in brotli's build shells out to a host program.
- The `-lm` reasoning in the comment is the right shape even though the
  details need fixing (below): brotli's own `CHECK_FUNCTION_EXISTS(log2)`
  cannot detect anything under
  `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` on Android, because
  `check_function_exists` needs a *link* and a static-library try-compile does
  not link. What actually carries the `log2` reference on Bionic is the
  systems' `$LDFLAGS -lm` (`packages/aarch64-android24/generic.lua:79`). The
  recipe is right to rely on the system for it rather than adding a flag —
  that is precisely the division of labour AGENTS.md prescribes.

## One stale comment, not a reject reason

`generic.lua:5-8` says upstream builds "the brotli/brotlicli tools" and that
"their zopfli path calls log2()". Two corrections:

- brotli 1.1.0's `CMakeLists.txt` defines exactly **one** executable,
  `brotli` (`add_executable(brotli c/tools/brotli.c)`). There is no
  `brotlicli` target.
- The `log2` call is not in a "zopfli path" in the tools; it is in the library,
  and brotli handles it with its own `CHECK_FUNCTION_EXISTS(log2)` plus
  `target_link_libraries(${lib} m)`.

`stage1.md` inherits the same error and lists `bin/brotlicli` as an artifact.
That file will not exist. Fix the comment to say "the `brotli` CLI, which
upstream gives no option to omit" and correct the artifact list to
`bin/brotli` only.

## Carried to the build

- `lib/libbrotlicommon.a`, `lib/libbrotlidec.a`, `lib/libbrotlienc.a` — `llvm-objdump -f lib/libbrotlienc.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). All three must be present; a missing one means a `*.so` was produced instead.
- `include/brotli/encode.h`, `decode.h`, `types.h`, `port.h`, `transform.h` — `[ -f include/brotli/encode.h ]`.
- `lib/pkgconfig/libbrotlicommon.pc`, `libbrotlidec.pc`, `libbrotlienc.pc` — `pkg-config --modversion libbrotlienc` → `1.1.0`, and the same for the other two. Three `.pc` files, all inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `bin/brotli` — expected; it is a target program, so **never run it**.
- `bin/brotlicli` must be **absent** — it is not a brotli 1.1.0 target, and its presence would mean a different upstream tree.
- The link check that matters on Android: `llvm-nm lib/libbrotlienc.a | grep log2` must find the `U log2` undefined reference, and the system `-lm` is what resolves it at consumer link time.

## Rework verification

**Verdict: ACCEPT.** First line was already `ACCEPT`; left as `ACCEPT`.

### Correctly fixed

- **`stage1.md:6` no longer lists `bin/brotlicli` as an installed artifact.**
  It now ends "`bin/brotli` (brotli 1.1.0 has exactly one `add_executable`,
  CMakeLists.txt:172 — there is no `brotlicli`)". Verified in the unpacked
  tree: `CMakeLists.txt:172` is the sole `add_executable`
  (`add_executable(brotli c/tools/brotli.c)`), and `:177-180` installs exactly
  that one target into `${CMAKE_INSTALL_BINDIR}`. A tree-wide grep for
  `add_executable` in `brotli/` returns that single line. The citation is
  right, and naming the absence explicitly is better than silently dropping
  it.
- **The verification step was corrected to match**, which was the substance of
  the ask: `stage1.md:53` reads "`bin/brotli` present; there is no `brotlicli`
  in 1.1.0". A builder following this will no longer go looking for a
  `brotlicli` that upstream never builds.
- The three `.pc` files are named correctly and their directory is right:
  `CMakeLists.txt:354-359` installs `libbrotlicommon.pc`, `libbrotlidec.pc`
  and `libbrotlienc.pc` all into `${CMAKE_INSTALL_LIBDIR}/pkgconfig`, and
  `lib/pkgconfig/*.pc` is inside the loader's rewrite set
  (`src/loader.lua:454`). `pkg-config --modversion libbrotlienc` resolves by
  file name, so the command at `stage1.md:51` works as written.
- **The `-lm` reasoning survives intact and I re-verified it.** brotli does
  `CHECK_FUNCTION_EXISTS(log2)` at `CMakeLists.txt:82` and
  `CHECK_FUNCTION_EXISTS(log2 LOG2_LIBM_RES)` at `:86`, so the recipe is right
  to let the system supply `-lm` rather than adding a flag here — that is the
  division of labour `AGENTS.md:205-210` prescribes. I confirmed the log2
  reference is in the *library*, not the tools: `grep -rln log2 brotli/c/tools/`
  returns nothing, while `c/enc/backward_references_hq.c`,
  `c/enc/bit_cost_inc.h` and `c/enc/fast_log.c` all reference it. That is
  what this review's original comment nit was about, and the comment was left
  alone, so it did not regress.
- Nothing else damaged. `generic.lua:11` is
  `cmake --build build --parallel 1` (serial), install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`, no `export`, no hardcoded target
  fact, no `sed`/patch/`/dev/null`, and `require("brotli@source")` names a
  package that exists.
- `source.lua` is correct: `c/common/version.h:20-22` gives
  `BROTLI_VERSION_MAJOR 1`, `MINOR 1`, `PATCH 0`, matching the pin 1.1.0; the
  tag archive URL answers 200; the tree lands in `$OUT/brotli/`.

### Still wrong, outside my scope

- **`generic.lua:7` and `packages/brotli/readme.md:10` still say
  `brotli/brotlicli`.** The recipe comment reads "no option to leave out the
  brotli/brotlicli tools" and `readme.md:10` lists "`bin/brotli`,
  `bin/brotlicli` — the command line tools" with `readme.md:19` saying "and
  both tools". Upstream defines one executable; there is no `brotlicli`
  target in 1.1.0. `stage1.md:31` correctly notes "The recipe comment says
  `brotli/brotlicli`; only `brotli` exists", so the mismatch is now
  documented rather than hidden — but the comment and the readme still carry
  the error. I am not editing `generic.lua` or `readme.md`. `topackage.md:123`
  repeats it as well ("plus the brotli/brotlicli tools") and is the upstream
  source of all three.

`stage1.md` is now correct on the point this rework was about, the recipe was
 not touched, and no system-derived flag or target fact was disturbed.
