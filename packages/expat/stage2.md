ACCEPT

# expat 2.7.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`expat-2.7.1` release tarball. I did not build.

**Category (b): the recipe builds and installs a target program it never asked
for, and `stage1.md` states the opposite.** The build itself is sound and the
six WILL BUILD verdicts hold — the artifact list is what is wrong.

## The defect, verified

`packages/expat/generic.lua:9`:

```
        cmake -S . -B build $CMAKE_FLAGS -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF
```

There is no `-DEXPAT_BUILD_TOOLS=OFF`. I extracted the tarball and read the
option's default:

```
$ grep -n "EXPAT_BUILD_TOOLS" CMakeLists.txt
61:if(WINCE)
62:    set(_EXPAT_BUILD_TOOLS_DEFAULT OFF)
63-65:else()
64:    set(_EXPAT_BUILD_TOOLS_DEFAULT ON)
66:endif()
131:expat_shy_set(EXPAT_BUILD_TOOLS ${_EXPAT_BUILD_TOOLS_DEFAULT} CACHE BOOL "Build the xmlwf tool for expat library")
585:    add_executable(xmlwf ${xmlwf_SRCS})
591:    expat_install(TARGETS xmlwf DESTINATION ${CMAKE_INSTALL_BINDIR})
```

`_EXPAT_BUILD_TOOLS_DEFAULT` is **ON** for every target except WinCE — which is
not one of our six. So `xmlwf` is compiled **and installed** to
`$OUT/bin/xmlwf` on all six systems. The recipe asked for a library and got a
CLI tool as well.

`stage1.md` says "**no tools**" and separately that `xmlwf` is "off by default".
Both are wrong. `stage1.md` also got a knock-on detail right for the wrong
reason: `EXPAT_BUILD_DOCS`'s own default is computed at `CMakeLists.txt:67-76`
from whether docbook tooling is found, so passing `-DEXPAT_BUILD_DOCS=OFF` is
belt-and-braces rather than load-bearing.

## Required changes

### 1. `packages/expat/generic.lua:9` — add the missing switch, with the reason

Replace line 9 with:

```
        # Static library, headers and expat.pc. The three BUILD_*=OFF
        # switches matter individually: TESTS and EXAMPLES are target
        # programs we do not want in the prefix, and DOCS is off because
        # docbook2man may or may not be on the build host. TOOLS is the one
        # that is easy to miss - expat's CMakeLists.txt:61-66 defaults
        # _EXPAT_BUILD_TOOLS_DEFAULT to ON for everything except WinCE, and
        # line 591 installs xmlwf into bin/, so without this the prefix
        # silently gains a CLI tool.
        cmake -S . -B build $CMAKE_FLAGS -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF
```

With `EXPAT_BUILD_TOOLS=OFF` the `doc/xmlwf.1` install is inside that same
conditional, so `-DEXPAT_BUILD_DOCS=OFF` becomes moot — keep it anyway, it is
harmless and self-documenting.

### 2. `packages/expat/stage1.md` — correct the two false claims

- The "Installs" line: delete "**no tools**". Either list `bin/xmlwf` (if the
  recipe is left alone) or, after change 1, keep "no tools" but delete the
  claim that it is "off by default" and cite `CMakeLists.txt:61-66` and `:591`
  as the reason it needs an explicit switch.
- The "How to verify" section: add `bin/xmlwf` must be **absent** after change
  1. That is the check that proves the switch took.

### 3. Nothing else is required

`-DEXPAT_SHARED_LIBS=OFF` is honoured and gives `lib/libexpat.a`.
`cmake_minimum_required(VERSION 3.13.0)` is fine, and the system's
`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is irrelevant at 3.13. `cmake --build
build --parallel 1` is serial, and install goes to `$OUT` via the system's
`-DCMAKE_INSTALL_PREFIX=$OUT`. `require("expat@source")` names no missing
package. The six WILL BUILD verdicts stand.

## Carried to the build

- `lib/libexpat.a` — `llvm-objdump -f lib/libexpat.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/expat.h`, `include/expat_external.h` — `[ -f include/expat.h ] && [ -f include/expat_external.h ]`.
- `lib/pkgconfig/expat.pc` — `pkg-config --modversion expat` → `2.7.1`. It is installed on by default, and `lib/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `bin/xmlwf` must be **absent** — its presence means `-DEXPAT_BUILD_TOOLS=OFF` is missing and the recipe must not be recorded as built.
- No examples and no tests: `ls bin` should be empty, and no test binary anywhere under `$OUT`.

---

## Rework verification

**Verdict: ACCEPT.** (The first line of this file was changed from `REJECT`
to `ACCEPT` by this review.)

### Required change 1 — the switch is present

`generic.lua:6` now reads:

```
        cmake -S . -B build $CMAKE_FLAGS -DEXPAT_SHARED_LIBS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_EXAMPLES=OFF -DEXPAT_BUILD_DOCS=OFF
```

`-DEXPAT_BUILD_TOOLS=OFF` is there. This is the whole fix and I confirmed
the premise it addresses is real, not defensive:

```
$ sed -n '61,66p' nest/source/expat/CMakeLists.txt
if(WINCE)
    set(_EXPAT_BUILD_TOOLS_DEFAULT OFF)
else()
    set(_EXPAT_BUILD_TOOLS_DEFAULT ON)
endif()
$ grep -n "expat_install(TARGETS xmlwf" nest/source/expat/CMakeLists.txt
591:    expat_install(TARGETS xmlwf DESTINATION ${CMAKE_INSTALL_BINDIR})
```

Default ON for everything except WinCE, and WinCE is not one of the six
systems. So the old recipe did silently install `$OUT/bin/xmlwf`.

I also checked that `OFF` actually takes effect, since the option goes
through a custom macro rather than `option()`:

```
$ sed -n '119,127p' nest/source/expat/CMakeLists.txt
    if(DEFINED ${var})
        ...only add to the cache if there is no cache entry, yet...
    else()
        set("${var}" "${default}" CACHE ...)
```

`expat_shy_set` is "shy" about variables that are *already defined* — a
`-DEXPAT_BUILD_TOOLS=OFF` on the command line is defined, so the `else()`
arm that would install the `ON` default never runs. The switch wins.
`EXPAT_BUILD_DOCS` (`:135`) rides the same macro, so passing it `=OFF` is
also honoured rather than silently overwritten.

### Required change 2 — the "no tools" claim is now true

`stage1.md:6` was rewritten and no longer says "no tools, they are off by
default". It now states the artifact set and the condition under which
`bin/xmlwf` would appear, naming `CMakeLists.txt:61-66` and `:591` as the
reason. `stage1.md:35-39` carries the same fact in the risk section and
explicitly withdraws the old claim. `stage1.md:58` adds
`bin/xmlwf must be **absent**` to the verification list, which is the
check that proves the switch took. All three parts of required change 2
are done.

### Required change 3 — nothing else broken

`require("expat@source")` names no missing package. `$CMAKE_FLAGS` is used
for a cmake build, which is the correct variable per AGENTS.md. No
`export`, no hardcoded target facts, no `sed`/patch/`/dev/null`.
`cmake --build build --parallel 1` is serial. There is no `android.lua`.

### The guard question does not arise here

expat uses cmake, not `./configure`, so no timestamp guard is required and
none is present — correct under AGENTS.md, which scopes the guard to
autotools. For the record, if anyone later switches this recipe to
autotools, the template would be `expat_config.h.in`
(`configure.ac:91`: `AC_CONFIG_HEADERS([expat_config.h])`), **not**
`config.h.in`.

### Not verified

I did not build, and `xmlwf`'s absence is asserted from the CMake
conditionals rather than observed. The `stage1.md:58` check is the right
confirmation once someone builds it.
