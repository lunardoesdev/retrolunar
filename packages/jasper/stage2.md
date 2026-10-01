REJECT

# jasper 4.2.9 — review

One defect. The recipe's flags are all correct; the **artifact list in
`stage1.md` names a file that does not exist and another that does**, in
the wrong directory. Per AGENTS.md ("An install list naming a binary or
`.pc` file that does not exist sends the builder after a phantom defect"),
that is the reject.

## The defect

`stage1.md:8` and `stage1.md:58` both say:

```
- Installs: ... `share/pkgconfig/jasper.pc`
- `share/pkgconfig/jasper.pc` and `pkg-config --modversion jasper` → `4.2.9`
```

jasper does **not** install its `.pc` into `share/pkgconfig`. The install
rule is at `CMakeLists.txt:880-881`:

```cmake
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/build/pkgconfig/jasper.pc"
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
```

with `CMAKE_INSTALL_LIBDIR` from `include(GNUInstallDirs)`
(`CMakeLists.txt:72`), which resolves to `lib` — I configured the package
and read `CMAKE_INSTALL_LIBDIR:PATH=lib` out of `CMakeCache.txt`. The
`lib/pkgconfig` destination is stated twice in jasper's own comments
(`CMakeLists.txt:865`, and `src/CMakeLists.txt`'s header comment says so
too). The generated `.pc` even says `libdir=${exec_prefix}/lib`.

I built and installed the package with the recipe's flags. The real install
is:

```
lib/libjasper.a
lib/pkgconfig/jasper.pc
include/jasper/{jasper,jas_config,jas_cm,jas_compiler,jas_debug,jas_dll,
                jas_export_cmake,jas_fix,jas_getopt,jas_icc,jas_image,
                jas_init,jas_log,jas_malloc,jas_math,jas_seq,jas_stream,
                jas_string,jas_thread,jas_tmr,jas_tvp,jas_types,
                jas_version}.h
share/doc/JasPer/README.md
```

`share/pkgconfig/` does not exist after install. So the builder following
stage1's verification list runs a check that can never pass, and — worse,
since the file *is* present one directory over — the natural "fix" is to
declare a real, correct build broken.

**Required fix, in `stage1.md` only** (two lines, 8 and 58): replace
`share/pkgconfig/jasper.pc` with `lib/pkgconfig/jasper.pc`. Nothing in
`generic.lua` changes; the recipe does not name the path at all, and
`cmake --install` puts the file where upstream says to put it.

## Question 1 — is it using the system?

Yes. `cmake -S . -B build $CMAKE_FLAGS` picks up the toolchain file,
`-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`,
`-DTHREADS_PREFER_PTHREAD_FLAG=ON` and the policy floor from
`packages/aarch64-android24/generic.lua:118-141`. The seven `-D` switches
are jasper policy, none names a target fact. No `export`, no hardcoded
prefix, no `--host`. `-DJAS_ENABLE_LIBJPEG=ON` is deliberate: it is
jasper's own default (`CMakeLists.txt:118`) and stating it says "use the
libjpeg-turbo already in `$PREFIX`", which is a package decision. Single-job
option written explicitly.

## Question 2 — is it doing what jasper needs?

Every option name checked against `CMakeLists.txt`:

| switch | declaration | default |
|---|---|---|
| `JAS_ENABLE_SHARED` | `:103`, `:106` | ON |
| `JAS_ENABLE_LIBJPEG` | `:118` | ON |
| `JAS_ENABLE_LIBHEIF` | `:119` | ON |
| `JAS_ENABLE_OPENGL` | `:120` | ON |
| `JAS_ENABLE_PROGRAMS` | `:123` | ON |
| `JAS_ENABLE_DOC` | `:121` | ON |
| `JAS_ENABLE_LATEX` | `:122` | ON |

All seven exist. No nonexistent flag.

**`JAS_ENABLE_SHARED=OFF` really sticks**, which stage1 flagged as worth
checking and which is correct to have flagged: the option is declared twice
(`:103` inside `if(DEFINED BUILD_SHARED_LIBS)`, `:106` in the `else`).
cmake's `option()` honours an existing cache entry, and the recipe sets the
cache on the command line, so the value is `OFF` regardless of which
declaration runs. Confirmed: the build produced `lib/libjasper.a` and no
`.so`.

**The seven native codecs are all present.** The adder's claim is correct
and important, so I checked it against the archive rather than the option
list. `ar t lib/libjasper.a` contains `bmp_{cod,dec,enc}`, `jp2_{cod,dec,enc}`,
`jpc_*` (17 objects), `mif_cod`, `pgx_{cod,dec,enc}`, `pnm_{cod,dec,enc}`,
`ras_{cod,dec,enc}` — all seven, none disabled. No external library is
silently disabled either: `JAS_INCLUDE_BMP/JP2/JPC/MIF/PGX/PNM/RAS_CODEC`
are all `ON` by default (`:133-143`) and the recipe leaves every one alone.
Only the two genuinely external backends go off — libheif (`find_library(HEIF_LIBRARY heif)`
at `:793`, nothing to find) and OpenGL/GLUT (`find_package(OpenGL)` /
`find_package(GLUT)` at `:717-718`, nothing to find on Android or here).
The `JAS_ENABLE_MIF_CODEC` **enable**-by-default option is `OFF` upstream
(`:154`) but `JAS_INCLUDE_MIF_CODEC` is `ON` (`:138`), so MIF is compiled
in and merely not pre-selected at runtime — that is upstream's choice, not
a recipe defect, and the object is in the archive.

**The libheif claim is precise and true.** `CMakeLists.txt:792-804` is
exactly the block quoted: `if(JAS_ENABLE_LIBHEIF)` … `endif()` /
`if(NOT JAS_HAVE_LIBHEIF) / set(JAS_INCLUDE_HEIC_CODEC 0)`. Passing
`=OFF` is belt-and-braces exactly as the recipe's own comment says. The
comment's honesty about the two defensive switches is the right call.

**`JAS_STRICT` defaults OFF** at `:130`, so a current clang on jasper's C
does not turn warnings into errors. Correct, and load-bearing.

**The threading claim checks out, with one correction to the citation.**
`CMakeLists.txt:636-637` is
`set(THREADS_PREFER_PTHREAD_FLAG TRUE)` / `find_package(Threads)`,
guarded by `IF(NOT WIN32)`, and the Android systems really do export
`-DTHREADS_PREFER_PTHREAD_FLAG=ON`. But the line number stage1 cites for
that system export, `aarch64-android24/generic.lua:123`, is a comment about
`CMAKE_TRY_COMPILE_TARGET_TYPE`; the flag is on **line 131**. The
`find_library(PTHREAD_LIBRARY pthread)` / `if(NOT PTHREAD_LIBRARY)`
neutralisation is `:594-597`, which stage1 got right. This citation slip is
not part of the reject — the conclusion holds and the recipe is unaffected —
but it is recorded so nobody later "fixes" line 123.

**No host programs.** `JAS_ENABLE_PROGRAMS=OFF` gates
`add_subdirectory(src/app)` at `CMakeLists.txt:860-862`; the install above
has no `bin/`.

**`require("libjpeg-turbo")`** resolves — `packages/libjpeg-turbo/` exists.
jasper's `.pc` carries `Requires.private: libjpeg`, and libjpeg-turbo's own
`stage1.md:7` confirms it ships `libjpeg.pc`, so the module resolves in
this prefix rather than dangling.

**Source URL and version.** The tag URL resolves (fetched it). The GitHub
releases API returns `"tag_name": "version-4.2.9"` as newest — current.
Top directory is `jasper-version-4.2.9/`, handled by `--strip-components=1`,
landing at `$NESTDIR/source/jasper/`, which `generic.lua` copies from. The
tag archive genuinely ships no autotools files at all — no `configure`, no
`configure.ac`, no `Makefile.in` — so cmake is the only build system, as
stage1 says.

## Forecast

The `x86_64-mingw` UNCERTAIN is real hedging on a real question, and
`stage1.md:20` names the specific thing to check (`jas_image.c`'s BMP
writer). I looked: `src/libjasper/bmp/` is a directory with `bmp_enc.c`,
`bmp_dec.c`, `bmp_cod.c`, and the encoder's file handling is in
`jas_image.c`'s stream layer, which uses jasper's own `jas_stream` tmpfile
abstraction rather than bare `unlink`. So the suspicion is pointed at the
right file. The other five WILL BUILDs are not optimism: I configured,
built and installed this exact configuration natively with zero errors, and
nothing in jasper's own sources reaches for a Bionic-absent symbol.

## Carried to the build

Corrected to the real paths. Every filter is scoped to something jasper
owns, so a second package in the prefix cannot satisfy it.

```sh
# 1. The archive, and no shared object.
[ -f lib/libjasper.a ]
[ ! -e lib/libjasper.so ]
ls lib | grep -c '^libjasper'          # expected 1: libjasper.a only

# 2. The .pc file, in lib/pkgconfig (NOT share/pkgconfig).
pkg-config --modversion jasper         # expected 4.2.9
[ -f lib/pkgconfig/jasper.pc ]
[ ! -d share/pkgconfig ]               # must be absent; jasper installs nothing there

# 3. Headers, including the generated ones.
[ -f include/jasper/jasper.h ]
[ -f include/jasper/jas_config.h ]

# 4. All seven native codecs are compiled in. Anchored on jasper's own
#    object names, one per codec; the archive must hold every one.
for c in bmp jp2 jpc pgx pnm mif ras; do
  ar t lib/libjasper.a | grep -c "^${c}_"
done

# 5. No programs: jasper, imagetopnm, jiv.
[ ! -d bin ]

# 6. HEIF really is out.
grep -c JAS_HAVE_LIBHEIF include/jasper/jas_config.h   # expected 0
```

Check 4's loop is the one worth running: I verified against
`ar t lib/libjasper.a` that all seven prefixes (`bmp_`, `jp2_`, `jpc_`,
`mif_`, `pgx_`, `pnm_`, `ras_`) actually appear, so the filter matches real
object names rather than the names one hopes for. Check 2's
`[ ! -d share/pkgconfig ]` is the check that would have caught this defect
at build time.
