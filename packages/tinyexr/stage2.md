REJECT

# tinyexr 3.2.0 — review

## The headline claim is TRUE. The recipe built on top of it is wrong.

I grepped the real `CMakeLists.txt` from the tag archive:

```
$ grep -n "install" CMakeLists.txt
(no output, exit 1)
$ wc -l CMakeLists.txt
78 CMakeLists.txt
```

There is no `install()` rule, no `install(TARGETS`, no
`CMakePackageConfigHelpers`, no `.pc` file anywhere in the tree
(`find . -name '*.pc*'` returns nothing). `cmake --install` therefore exits
**0 having installed nothing** — I ran it and it printed
`-- Install configuration: ""` and exited 0 without creating the prefix
directory at all. So the adder's central claim is correct and the danger it
describes is real.

That part of the diagnosis is right. **The remedy is where it fails.** The
recipe's comment says:

```
# Copy the archive and the single public header ourselves
mkdir -p $OUT/lib $OUT/include
cp build/lib/libtinyexr.a $OUT/lib/
cp tinyexr.h $OUT/include/
```

"the single public header" is wrong. tinyexr 3.2.0's `tinyexr.h` is not
self-contained, and I proved the installed prefix cannot be used.

### Defect 1 — the installed header set is incomplete; `#include <tinyexr.h>` fails

`tinyexr.h:749` is

```c
#include "exr_reader.hh"
```

`exr_reader.hh:12` in turn does `#include "streamreader.hh"`. Both are
top-level files in the tarball, and the recipe copies neither. A consumer
compiling against exactly what the recipe installs gets:

```
$ clang++ -std=c++11 -I $OUT/include -c cons.cpp
In file included from cons.cpp:2:
$OUT/include/tinyexr.h:749:10: fatal error: 'exr_reader.hh' file not found
```

That is a header that cannot be included. The package as written is not
usable by anything.

### Defect 2 — the installed library does not link

Even with all three headers supplied, `lib/libtinyexr.a` does not link on
its own, because the archive is not self-contained:

```
$ llvm-nm --undefined-only lib/libtinyexr.a | grep -c 'mz_\|tinfl\|tdefl'
3
$ llvm-nm --undefined-only lib/libtinyexr.a | grep 'mz_\|tinfl\|tdefl'
  U mz_compress
  U mz_compressBound
  U mz_uncompress
```

Those come from `deps/miniz/miniz.c`, built by the recipe's own
`-DTINYEXR_USE_MINIZ=ON` into a **separate** `libminiz.a`
(`CMakeLists.txt:32` `add_library(miniz STATIC deps/miniz/miniz.c)`). The
recipe installs `libtinyexr.a` and not `libminiz.a`. Linking a real consumer:

```
$ clang++ -std=c++11 -I out/include cons.cpp out/lib/libtinyexr.a
/usr/bin/ld: libtinyexr.a(tinyexr.cc.o): in function
  'tinyexr::CompressZip(unsigned char*, unsigned long&, unsigned char const*, unsigned long)':
  tinyexr.cc:(.text+0x1044): undefined reference to `mz_compressBound'
  tinyexr.cc:(.text+0x107c): undefined reference to `mz_compress'
  tinyexr.cc:(.text+0x1243): undefined reference to `mz_uncompress'
$ echo $?
141

# adding the bundled miniz archive:
$ clang++ ... cons.cpp out/lib/libtinyexr.a build/libminiz.a
$ echo $?
0
```

The recipe chose the bundled-miniz path *specifically* so "the library needs
no external decompressor and no prefix dependency" — and then installed the
archive without the decompressor it depends on. A `.pc` file cannot paper
over this either, because there is no `Libs.private:` mechanism available
without a `.pc` and none ships.

### Defect 3 — `miniz.h` is a bundled third-party header the consumer also needs

`tinyexr.h:108-109` defaults `TINYEXR_USE_MINIZ` to `1`, and
`tinyexr.h:770-771` then does `#include <miniz.h>`. So the *public* header
includes a bundled third-party header from `deps/miniz/miniz.h` by default.
The recipe installs `tinyexr.h` without it, so even a consumer who
works around defect 1 hits a missing `<miniz.h>`.

## Required changes

All in `packages/tinyexr/generic.lua`, and all three are needed together —
fixing any one alone still leaves an unusable prefix:

1. Copy the two bundled headers the public header includes:
   `cp exr_reader.hh streamreader.hh $OUT/include/`
2. Copy the bundled third-party header `tinyexr.h` includes by default:
   `cp deps/miniz/miniz.h $OUT/include/`
3. Copy the second archive the first depends on:
   `cp build/libminiz.a $OUT/lib/`

**On the layout question you asked about.** The current copy does not
follow any upstream layout, because upstream has none — there is no
install rule to follow, so there is no prefix-relative arrangement to
match. What matters instead is that the result is self-consistent and
usable, and that means the three files above plus `libtinyexr.a` and
`tinyexr.h`. Note that `libminiz.a` and `miniz.h` are bundled upstream
material, not generated output; `mkdir` and `cp` of them are exactly the
`cp`-and-`mkdir` recipe shape AGENTS.md permits, and no upstream source is
edited. **Alternative worth weighing:** `-DTINYEXR_USE_MINIZ=OFF` would drop
the miniz dependency from the archive entirely (`libtinyexr.a` would then
have no undefined `mz_*` symbols), but it still leaves defects 1 and 2's
sibling — the `.hh` files — so it is not sufficient on its own, and it
changes the library's feature set away from upstream's default. I recommend
installing the three missing files and leaving `TINYEXR_USE_MINIZ=ON`.

The archive name `libtinyexr.a` is right: `BUILD_TARGET` is `tinyexr`
(`CMakeLists.txt:5`), `add_library(${BUILD_TARGET} ...)` at `:38` sets no
`OUTPUT_NAME` or `SOVERSION`, and my build produced
`build/libtinyexr.a`. stage1's own caveat about that is fair.

## Question 1 — is it using the system?

Yes, and cleanly. `cmake -S . -B build $CMAKE_FLAGS` carries the toolchain
file, `-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` and the policy floor from
the Android system file. `mkdir`/`cp` target only `$OUT`. No `export`, no
hardcoded target fact, no `--host`. `-DTINYEXR_BUILD_SAMPLE=OFF` correctly
suppresses the host program (`SAMPLE_TARGET`/`test_tinyexr.cc`,
`CMakeLists.txt:6,53-60`). `--parallel 1` written explicitly.

## Question 2 — everything else about the package checks out

- **Source URL resolves** (fetched `v3.2.0.tar.gz`); GitHub releases API
  returns `"tag_name": "v3.2.0"` as newest — current.
- **Top-level directory** is `tinyexr-3.2.0/`, handled by
  `--strip-components=1`; the tree lands at
  `$NESTDIR/source/tinyexr/`, which `generic.lua:5` copies from. The
  `cp build/lib/libtinyexr.a` path is relative to the copied tree, so it
  resolves.
- **Options exist.** `TINYEXR_BUILD_SAMPLE` (`CMakeLists.txt:11`) and
  `TINYEXR_USE_MINIZ` (`:12`) are the only two `option()`s in the file, and
  both are passed with valid values.
- **stage1's risk note about `deps/` is right**: `deps/` holds ZFP,
  astcenc, basisu, libdeflate, miniz, nanozlib, zstd, and only
  `deps/miniz` is referenced by the CMakeLists.
- **${CMAKE_DL_LIBS}**: `CMakeLists.txt:42` is
  `target_link_libraries(${BUILD_TARGET} ${TINYEXR_EXT_LIBRARIES} ${CMAKE_DL_LIBS})`.
  For a static archive this is link-interface metadata only and affects no
  link step in this recipe, so the Android `libdl` question stage1 raises
  is not load-bearing.

## Forecast

The five WILL BUILDs are not optimism — **the library itself builds clean**,
which I confirmed by configuring and building it: 78-line CMakeLists, three
object files, exit 0. And the UNCERTAIN on `x86_64-mingw` is honest, not
hedging: tinyexr really does ship only `Makefile.gcc-mingw` variants and no
mingw-tested cmake path, which is precisely what stage1 says it did not
check.

The forecast is wrong in exactly one place, and it is the place that
matters: **`stage1.md:7` states the install is `lib/libtinyexr.a` and
`include/tinyexr.h`, copied by the recipe**, and presents that as the
answer to "what does this package install". Those two files are not a
usable tinyexr. The adder correctly identified the missing `install()` and
then stopped one step short of checking what a consumer of the result
actually needs. The `cmake --install` no-op would have been caught by
`[ -f lib/libtinyexr.a ]`; the two defects above would **not** have been,
because both files are present and look right.

## Carried to the build

Scoped to tinyexr's own artefacts so a second package in the prefix cannot
satisfy them, and each filter verified against the real file list.

```sh
# 1. The archive and the header exist (this alone would NOT have caught
#    the defect -- which is the point).
[ -f lib/libtinyexr.a ]
[ -f include/tinyexr.h ]

# 2. The bundled headers the public header includes. Without these the
#    header cannot be parsed at all.
[ -f include/exr_reader.hh ]
[ -f include/streamreader.hh ]
[ -f include/miniz.h ]

# 3. The second archive libtinyexr.a depends on.
[ -f lib/libminiz.a ]

# 4. libtinyexr.a must not carry unresolved miniz symbols.
llvm-nm --undefined-only lib/libtinyexr.a | grep -c 'mz_\|tinfl\|tdefl'   # expected 3

# 5. Still no program: TINYEXR_BUILD_SAMPLE=OFF.
[ ! -d bin ]

# 6. Still no .pc: upstream ships none, so a tinyexr.pc in the prefix means
#    upstream changed and this file is stale.
find . -name 'tinyexr.pc' | grep -c .    # expected 0
```

Check 4 is deliberately written to expect **3**, not 0: the symbols are
legitimately unresolved in the static archive, because `libminiz.a` in the
same prefix satisfies them. Expecting 0 would turn the correct build into a
phantom defect. The real end-to-end proof is a throwaway compile and link
of a trivial consumer against `$OUT` alone, which is what caught all three
defects:

```sh
mkdir -p /var/tmp/txcheck && cd /var/tmp/txcheck
printf '#include <tinyexr.h>\nint main(){EXRImage i;InitEXRImage(&i);return 0;}\n' > c.c
cc -std=c++11 -I "$PREFIX/include" c.c "$PREFIX/lib/libtinyexr.a" "$PREFIX/lib/libminiz.a" -o /dev/null
```
