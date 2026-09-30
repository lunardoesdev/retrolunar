ACCEPT

# Catch2 3.8.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- Catch2 v3 is a genuinely compiled library (`libCatch2.a` plus the `Catch2Main`
  library), not a header-only bundle, so a real compile is correct here — and
  the recipe comment says so rather than pretending otherwise.
- No test or sample program is built. The mechanism is worth being precise
  about, because the recipe comment is slightly off: **no test switch is
  actually passed.** `CATCH_DEVELOPMENT_BUILD` defaults OFF, and in a
  non-development build Catch2 never even defines `BUILD_TESTING` (CTest is
  included only in a dev build), so the dependent options
  `CATCH_BUILD_TESTING` / `CATCH_BUILD_EXAMPLES` / `CATCH_ENABLE_WERROR` are
  all off. The recipe's conclusion ("tests off") is right; the
  `CATCH_INSTALL_*` switches on line 9 are about installation, not about
  turning tests off.
- `CATCH_ENABLE_WERROR` being off by default is worth noting, because it is the
  same latent trap as cJSON's `-Werror` and meshoptimizer's `MESHOPT_WERROR`.
  Catch2 avoids it by default; do not "helpfully" enable it later.
- `cmake_minimum_required(VERSION 3.16)` is comfortably satisfied, and the
  system's `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is irrelevant at 3.16.
  `cmake --build build --parallel 1` is serial, install goes to `$OUT`.
- `require("catch2@source")` names no missing package.

## One forecast error, not a reject reason

`stage1.md:6` and `:40-49` say "**no pkg-config file**" and tell the builder
to use `find_package(Catch2)` only. Catch2 3.8.1 installs **two** `.pc` files
unconditionally: `share/pkgconfig/catch2.pc` and
`share/pkgconfig/catch2-with-main.pc` (top-level `CMakeLists.txt`, with
`PKGCONFIG_INSTALL_DIR = ${CMAKE_INSTALL_DATAROOTDIR}/pkgconfig`).

`$OUT/share/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set
(`src/loader.lua:455`), so they are correct and usable. Fix the artifact list
and the verification step: `pkg-config --modversion catch2` → `3.8.1` should
work, and a builder told otherwise would report a phantom defect.

## Carried to the build

- `lib/libCatch2.a` and `lib/libCatch2Main.a` — `llvm-objdump -f lib/libCatch2.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Both must be present.
- `include/catch2/catch_test_macros.hpp`, `catch_all.hpp` — `[ -f include/catch2/catch_test_macros.hpp ] && [ -f include/catch2/catch_all.hpp ]`.
- `share/pkgconfig/catch2.pc`, `share/pkgconfig/catch2-with-main.pc` — `pkg-config --modversion catch2` → `3.8.1`. These **do** exist; a failure here means the loader's rewrite did not run, not that upstream ships none.
- `lib/cmake/Catch2/Catch2Config.cmake`, `Catch2ConfigVersion.cmake` — `[ -f lib/cmake/Catch2/Catch2Config.cmake ]`.
- `share/doc/Catch2/` must be **absent** — `-DCATCH_INSTALL_DOCS=OFF` did its job. A `Catch2.md` there means the switch did not take.
- No test or sample binary anywhere under `$OUT`; they would be target programs nothing could run.

## Rework verification

**Verdict: ACCEPT.** First line was already `ACCEPT`; left as `ACCEPT`.

### Correctly fixed

- **The "no pkg-config file" claim is gone from the artifact list.**
  `stage1.md:6` now reads
  `share/pkgconfig/catch2.pc` and `share/pkgconfig/catch2-with-main.pc`
  (Catch2 3.8.1 ships both, `CMakeLists.txt:172-188`). Verified in the
  unpacked tree:
  - `CMakeLists.txt:171-174` sets
    `PKGCONFIG_INSTALL_DIR` to `${CMAKE_INSTALL_DATAROOTDIR}/pkgconfig`
    (default `share/pkgconfig`);
  - `:175-179` `configure_file(CMake/catch2.pc.in ...)`;
  - `:180-184` `configure_file(CMake/catch2-with-main.pc.in ...)`;
  - `:185-191` installs **both** files into that directory, unconditionally —
    inside the `if (NOT_SUBPROJECT)` block, with no option guarding it.
  So `share/pkgconfig/*.pc` is right, and it is inside the loader's rewrite
  set (`src/loader.lua:455`), which is what makes the paths usable.
- **The verification step was corrected too**, which was the other half of the
  ask: `stage1.md:48` now reads
  `pkg-config --modversion catch2` and `pkg-config --modversion catch2-with-main`
  both report `3.8.1`. I checked the module names against the templates, since
  `pkg-config` resolves by *file name*, not by the `Name:` field:
  `CMake/catch2.pc.in` is installed as `catch2.pc` (so `catch2` is correct),
  and `CMake/catch2-with-main.pc.in` as `catch2-with-main.pc` (so
  `catch2-with-main` is correct). `catch2.pc.in:9` does carry
  `Version: @Catch2_VERSION@`, so `--modversion` returns `3.8.1` rather than
  failing on a missing field. Both commands work as written.
- No `require()` names a missing package, and no `android.lua` exists for
  catch2 (correct — Catch2 needs no per-target workaround).
- `generic.lua` is untouched by this rework and remains correct:
  `cmake --build build --parallel 1` at `:11` is serial, install goes to
  `$OUT` through the system's `-DCMAKE_INSTALL_PREFIX=$OUT`, and there is no
  `export`, no hardcoded target fact, no `sed`/patch/`/dev/null`.
- `source.lua` is correct: `project(Catch2 VERSION 3.8.1 ...)` in the unpacked
  tree matches the pin, the tag archive URL answers 200, and the tree lands in
  `$OUT/catch2/`.

### Still wrong, outside my scope

- **`stage1.md:16` still repeats the false claim.** The `clang-native` row says
  `topackage.md:226` records Catch2 "with `elf64-littleaarch64` archive members
  and no `.pc`". `topackage.md:226` does say "No pkg-config file upstream, so
  use find_package(Catch2)" — the backlog entry is the stale source, and
 `stage1.md:16` now contradicts `stage1.md:6` and `stage1.md:48` in the same
  file. The fix stopped one line short of its own conclusion. I am not editing
  `stage1.md` or `topackage.md`; both need the `.pc` fact corrected.

The artifact list and the verification steps are now right, and nothing in
 the recipe regressed while they were being fixed.
