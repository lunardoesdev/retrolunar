REJECT

# cJSON 1.7.19 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`v1.7.19` tree. I did not build.

## Required changes

### 1. `packages/cjson/generic.lua:9` — upstream's `-Werror` is left enabled

```
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DENABLE_CJSON_TEST=OFF
```

The recipe turns the test suite off but leaves
`ENABLE_CUSTOM_COMPILER_FLAGS` at its **ON** default, which is the dangerous
one. Verified against the extracted tree:

```
$ grep -n "ENABLE_CUSTOM_COMPILER_FLAGS\|Werror" CMakeLists.txt
18:option(ENABLE_CUSTOM_COMPILER_FLAGS "Enables custom compiler flags" ON)
19:if (ENABLE_CUSTOM_COMPILER_FLAGS)
26:            -Werror
```

cJSON 1.7.19 appends `-std=c89 -pedantic -Wall -Wextra -Werror
-Wconversion -Wcast-align -Wcast-qual -Wmissing-variable-declarations
-Wcomma -Wused-but-marked-unused -fstack-protector-strong` to
`CMAKE_C_FLAGS`. Any warning a current NDK clang or host clang adds to
`cJSON.c` becomes a **hard build error**. cJSON is `[x]`, so it has built on
`aarch64-android24` — but that is luck, not a property of the recipe, and the
other five systems have not been tried. This is the same latent trap as
meshoptimizer's `MESHOPT_WERROR`, which the adder correctly left off.

**Replace line 9 with:**

```
        # Static library, headers and libcjson.pc. ENABLE_CUSTOM_COMPILER_FLAGS
        # is upstream's ON default and appends -Werror (plus -std=c89
        # -pedantic and a 10-flag warning set) to CMAKE_C_FLAGS, so any
        # warning a current compiler adds to cJSON.c becomes a hard build
        # error. Turning it off is a build-robustness choice, not a platform
        # flag: the prefix does not want to inherit a 2017 warning policy.
        # ENABLE_CJSON_TEST=OFF drops the host test program.
        cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DENABLE_CUSTOM_COMPILER_FLAGS=OFF -DENABLE_CJSON_TEST=OFF
```

This also drops the forced `-std=c89 -pedantic`, which contradicts
`stage1.md`'s claim that cJSON "requires a C99-capable compiler".

### 2. `packages/cjson/generic.lua:7-8` — the comment is false

It reads: *"the utils (cJSON_add/cJSON_pretty) are ordinary target programs and
stay on."* Both halves are wrong. Verified:

```
$ grep -n "ENABLE_CJSON_UTILS" CMakeLists.txt
174:option(ENABLE_CJSON_UTILS "Enable building the cJSON_Utils library." OFF)
175:if(ENABLE_CJSON_UTILS)
176:    set(CJSON_UTILS_LIB cjson_utils)
```

`ENABLE_CJSON_UTILS` defaults **OFF**, and in 1.7.19 the utils are a *library*
(`cjson_utils` → `libcjson_utils.a` plus `include/cjson/cJSON_Utils.h`), not
`cJSON_add`/`cJSON_pretty` programs. Nothing but the core library is
installed. **Replace lines 7-8 with:**

```
        # Static library, headers and libcjson.pc. The upstream test suite
        # is a host program, so it is off. Nothing else is installed:
        # ENABLE_CJSON_UTILS defaults OFF and is a library, not a program.
```

If the utils library is wanted, add `-DENABLE_CJSON_UTILS=ON` and list
`lib/libcjson_utils.a` in the artifacts — but that is a decision, not a
comment fix.

### 3. `packages/cjson/stage1.md` — three artifact errors

- It claims `bin/cJSON_add` and `bin/cJSON_pretty` are installed. They are
  not, and do not exist in 1.7.19.
- It claims "**no pkg-config file**". cJSON installs `lib/pkgconfig/libcjson.pc`
  (`CMakeLists.txt`, `install(FILES … libcjson.pc DESTINATION lib/pkgconfig)`),
  and `lib/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set.
- Consequently `pkg-config --modversion cjson` **should** work; the forecast
  tells the builder not to look for it.

### 4. Nothing else is required

`-DBUILD_SHARED_LIBS=OFF` is honoured, `cmake --build build --parallel 1` is
serial, and install goes to `$OUT` via the system's
`-DCMAKE_INSTALL_PREFIX=$OUT`. The six WILL BUILD verdicts stand once the
`-Werror` risk is removed.

## Carried to the build

- `lib/libcjson.a` — `llvm-objdump -f lib/libcjson.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/cjson/cJSON.h` — `[ -f include/cjson/cJSON.h ]`.
- `lib/pkgconfig/libcjson.pc` — `pkg-config --modversion cjson` → `1.7.19`. It exists; a failure here means the loader's `.pc` rewrite did not run, not that upstream ships none.
- `lib/cmake/cJSON/cJSONConfig.cmake` — `[ -f lib/cmake/cJSON/cJSONConfig.cmake ]`.
- `lib/libcjson_utils.a` and `bin/cJSON_add` must both be **absent** — either appearing means the default assumptions in change 2 are wrong.
- The test suite must be absent: no `cJSON_test` binary anywhere under `$OUT`.

## Rework verification

**Verdict: REJECT.** First line left as `REJECT`.

### Correctly fixed

- **Change 1 landed.** `generic.lua:13` now passes
  `-DENABLE_CUSTOM_COMPILER_FLAGS=OFF`. Verified against the unpacked tree:
  `CMakeLists.txt:18` is `option(ENABLE_CUSTOM_COMPILER_FLAGS "Enables custom
  compiler flags" ON)`, `:19` opens the guard, `:26` is the `-Werror` inside
  it. The switch is off, so `-Werror`, `-std=c89 -pedantic` and the warning
  set never reach `CMAKE_C_FLAGS`. The latent trap is closed; the recipe no
  longer builds by luck on one system.
- `generic.lua:14` is `cmake --build build --parallel 1` — serial, as
  `AGENTS.md:225-229` requires.
- **Change 2 landed.** `generic.lua:11-12` now says
  `ENABLE_CJSON_UTILS` defaults OFF and *is a library*, not that the utils are
  programs. Verified: `CMakeLists.txt:174`
  `option(ENABLE_CJSON_UTILS "Enable building the cJSON_Utils library." OFF)`,
  `:176` `set(CJSON_UTILS_LIB cjson_utils)`. No `cJSON_add`/`cJSON_pretty`
  target exists anywhere in 1.7.19 — the only `add_executable` in the file is
  `:245` `add_executable("${TEST_CJSON}" test.c)`, inside the
  `ENABLE_CJSON_TEST` guard, which the recipe turns off.
- **Change 3, first and third items, landed.** `stage1.md:6` now lists
  `lib/pkgconfig/libcjson.pc` and says "**no programs**", and `stage1.md:53`
  says `bin/cJSON_add` must be absent. Verified: `CMakeLists.txt:146`
  `install(FILES "${CMAKE_INSTALL_FULL_LIBDIR}/pkgconfig" ...)` installs the
  `.pc` to `lib/pkgconfig`, which is inside the loader's rewrite set
  (`src/loader.lua:454`). The old "no pkg-config file" claim is gone.
- Nothing else damaged. No `export` in the recipe, no hardcoded target fact,
  no `sed`/patch/`/dev/null`, install goes to `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`, and `require("cjson@source")` names a
  package that exists. `source.lua` is correct: `project(cJSON VERSION
  1.7.19 ...)` matches the pin, the tag archive URL answers 200, and the tree
  lands in `$OUT/cjson/`.

### Still wrong

- **`stage1.md:36` — the fix was pasted in without its list marker, and it now
  reads as a continuation of the preceding bullet.** The line begins
  `**Nothing but the core library is installed.**` with no leading `- `, so
  the paragraph about `cJSON_add`/`cJSON_pretty` is swallowed into the
  "loader-glob regression" bullet above it. Add `- ` at column 1.
- **`stage1.md:11` cites a line number that no longer exists.** It says
  "`ENABLE_CJSON_TEST=OFF` (`generic.lua:9`)". The `cmake` line is
  `generic.lua:13`; line 9 is inside the comment block. Same class of drift at
  `:26-35`, which still reasons about a glob without naming the switch.
- **`stage1.md:52` and `:55` still give a `pkg-config` invocation that will
  fail.** Both say `pkg-config --modversion cjson`. The installed file is
  `lib/pkgconfig/libcjson.pc` and its `Name:` field is `libcjson`
  (`library_config/libcjson.pc.in:4`). `pkg-config` resolves a module by
  *file name*, so the correct command is `pkg-config --modversion libcjson`;
  `cjson` finds nothing and returns non-zero. A builder following this line
  reports a phantom defect — the exact failure mode change 3 was meant to
  remove. `stage2.md:100` above carries the same wrong invocation.
- **`stage1.md:41-43` still asserts cJSON "requires a C99-capable compiler"
  and that "no `-std` flag is needed".** That is now true but is stated as a
  fact about the source rather than as a consequence of change 1, so the two
  halves of the file no longer line up: the recipe no longer forces `-std=c89`
  precisely *because* the flags block is off. Worth one clause tying it to
  `-DENABLE_CUSTOM_COMPILER_FLAGS=OFF`.

### Not mine to fix, reported

`packages/cjson/readme.md:29-33` still tells the reader that
  "`libcjson.a`, `cJSON.h` and the two utility programs, `cJSON_add` and
  `cJSON_pretty`" are built and that "cJSON 1.7.18 does not install a
  pkg-config file". Both halves are false for 1.7.19 and both contradict the
  recipe that now ships. I am not editing `readme.md`; it needs the same
  correction the recipe got.

The `-Werror` defect that motivated this rework is genuinely fixed. What
keeps this at REJECT is that the documentation a builder actually reads —
  `stage1.md` — was left internally inconsistent, and its `pkg-config` check is
  guaranteed to fail for a reason that does not exist.
