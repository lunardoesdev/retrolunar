REJECT

# yajl 2.1.0 — review

The recipe cannot get past `cmake` **configure**. Not on any system in this
tree, and not because of anything the recipe does. yajl 2.1.0's top-level
`CMakeLists.txt` unconditionally adds two subdirectories that call
`GET_TARGET_PROPERTY(... LOCATION)`, which cmake 3.19+ refuses. The
configure step dies before a single target exists, so the target-scoped
build the recipe relies on is never reached.

## Defect 1 — configure fails outright

`CMakeLists.txt:66-71` adds six subdirectories with no option to suppress
any of them:

```cmake
ADD_SUBDIRECTORY(src)
ADD_SUBDIRECTORY(test)
ADD_SUBDIRECTORY(reformatter)
ADD_SUBDIRECTORY(verify)
ADD_SUBDIRECTORY(example)
ADD_SUBDIRECTORY(perf)
```

`reformatter/CMakeLists.txt:38` and `verify/CMakeLists.txt:32` are both

```cmake
GET_TARGET_PROPERTY(binPath json_reformat LOCATION)
GET_TARGET_PROPERTY(binPath json_verify LOCATION)
```

Reading `LOCATION` was deprecated in cmake 3.19 and is an **error** in
cmake 4.x. Running the recipe's own configure line:

```
$ cmake -S . -B build -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX=$OUT -DCMAKE_PREFIX_PATH=$PREFIX
CMake Error at reformatter/CMakeLists.txt:38 (GET_TARGET_PROPERTY):
  The LOCATION property may not be read from target "json_reformat".  Use the
  target name directly with add_custom_command, or use the generator
  expression $<TARGET_FILE>, as appropriate.

CMake Error at verify/CMakeLists.txt:32 (GET_TARGET_PROPERTY):
  The LOCATION property may not be read from target "json_verify".
  ...

-- Configuring incomplete, errors occurred!
```

`cmake` here is 4.4.3 — the same binary the build would use.

**I checked whether the systems' policy floor rescues it. It does not.**
`packages/aarch64-android24/generic.lua:135` exports
`-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, which fixes the *other* yajl problem
(the `cmake_minimum_required(VERSION 2.6)` refusal) and gets the configure
further — to the two `GET_TARGET_PROPERTY` errors above. Lowering the floor
to 2.6 does not help either; it reintroduces the minimum-version refusal:

```
CMake Error at CMakeLists.txt:15 (CMAKE_MINIMUM_REQUIRED):
  Compatibility with CMake < 3.5 has been removed from CMake.
```

There is no flag in `$CMAKE_FLAGS`, and no value the recipe can pass, that
gets past this. The only build paths out are (a) a cmake older than 3.19,
which is not what this tree has, or (b) editing upstream, which
AGENTS.md forbids. The recipe as written produces an empty `$OUT` and a
failed build.

**There is no usable alternative in the tree either.** yajl ships a
`configure` — but it is a 2 KB shell wrapper whose entire job is to invoke
`cmake` (`rm -rf build; mkdir build; cd build; cmake -DCMAKE_INSTALL_PREFIX=... ..`),
so it hits the identical error. There is no `configure.ac`, no `Makefile.in`
and no `Android.configure.mk`; I checked for all of them. cmake is the only
build system yajl 2.1.0 has, and that build system does not configure under
cmake 4.

## Defect 2 — the recipe's central mechanism would not have worked anyway

Suppose the configure error were fixed. The recipe's plan is
`cmake --build build --target yajl_s` — build only the static library —
"and let `cmake --install` place the archive, headers and `.pc`"
(`generic.lua:13-15`). But `src/CMakeLists.txt:80` is

```cmake
INSTALL(TARGETS yajl
        RUNTIME DESTINATION lib${LIB_SUFFIX}
        LIBRARY DESTINATION lib${LIB_SUFFIX}
        ARCHIVE DESTINATION lib${LIB_SUFFIX})
```

**unconditional** — it does not test whether `yajl` (the SHARED target at
`src/CMakeLists.txt:40`) was built. A target-scoped build that skips `yajl`
leaves `cmake --install` with an install rule for a file that does not
exist, and `install(TARGETS)` on a missing artefact fails. So even behind
defect 1 the recipe would fail at the install step. stage1 half-noticed
this at `:42-47` ("If a future yajl adds a `test/` install rule … install
fails") but applied it to a hypothetical future change rather than to the
rule that is already in the tree today.

The fix for this half is to build the `yajl` target too (or to build
everything), which costs nothing: `yajl` is the same three source files and
a shared object builds fine on these targets.

## What is right, and worth keeping

- **"yajl declares no options at all" is true and important.** `grep -n
  "option(" CMakeLists.txt` over the top-level file returns nothing. There is
  no `ENABLE_TESTS`, no `YAJL_BUILD_APPS`. That is why the recipe reaches
  for a target-scoped build instead of a switch, and the reasoning is sound.
- The install destinations in `src/CMakeLists.txt:84-87` are as stage1 says:
  `lib${LIB_SUFFIX}` for the archive, `include/yajl` for the headers,
  **`share/pkgconfig`** for `yajl.pc` (`src/CMakeLists.txt:87`). So yajl's
  `.pc` really does land in `share/pkgconfig`, unlike jasper's — and unlike
  jasper this claim is **correct**. Worth noting the contrast, because the
  loader rewrites both (`src/loader.lua:454-468` covers `share/pkgconfig/*.pc`)
  and every system sets `PKG_CONFIG_LIBDIR` to include it
  (`packages/aarch64-android24/generic.lua:89-92`).
- `src/CMakeLists.txt:38` is `ADD_LIBRARY(yajl_s STATIC ...)` — the target
  name the recipe names is real.
- **Source URL and version.** Resolves (fetched `2.1.0.tar.gz`); the tags API
  returns `"name": "2.1.0"` as newest — current, and upstream is dormant.
  Top directory `yajl-2.1.0/`, handled by `--strip-components=1`, landing at
  `$NESTDIR/source/yajl/`.
- `require("yajl@source")` resolves; yajl is freestanding C and genuinely
  needs no dependency.

## Defect 3 — a false statement in stage1

`stage1.md:7` says the tag archive "ships a `configure` script and an
`Android.configure.mk`". The `configure` is there (it is the cmake wrapper
above). `Android.configure.mk` is **not**:

```
$ find . -maxdepth 1 -name '*.mk'
(no output)
```

Recorded because the `configure` and the `.mk` are cited together as if they
were equally present, and a builder looking for the `.mk` to route the build
around the cmake failure will not find it. This is not the reason for the
reject — the cmake breakage is — but it is the kind of claim that sends
someone looking for a nonexistent escape hatch.

## Question 1 — is it using the system?

Yes, and cleanly. `cmake -S . -B build $CMAKE_FLAGS` carries the toolchain
file, `-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` and the policy floor from
`packages/aarch64-android24/generic.lua:118-141`. `-fvisibility=hidden`
detection is `CHECK_C_COMPILER_FLAG` (compile-only), not a run probe, so
cross-compilation is not asked to execute anything. `--parallel 1` written
explicitly. No `export`, no hardcoded target fact.

The problem is entirely that upstream's cmake files do not survive cmake 4,
and AGENTS.md's rule — "recipes must not patch upstream sources" — means the
recipe cannot fix it.

## Forecast

All six rows are wrong, and they are wrong in the direction that matters:
`stage1.md` marks five systems WILL BUILD and the mingw row
"WILL BUILD (moderate confidence)". None of them can configure. The entire
table was derived by reading `CMakeLists.txt` for option names and platform
symbols — a sound method that this package defeats, because yajl's failure
is a cmake *API* removal, not a missing option or a missing libc symbol. No
row named a citation that would have caught it. Per AGENTS.md, "stage1.md
claiming WILL BUILD with no citation is a finding"; here the citations are
present and true but orthogonal to the only thing that matters.

The mingw hedge is doubly moot — the recipe never reaches a compiler.

## Required change

The adder has to choose a path, because the recipe cannot resolve this on
its own:

1. **Decide whether yajl 2.1.0 is buildable in this tree at all.** It is
   not, with the cmake available. That is a package-level call, not a flag.
2. If the answer is "not buildable", `stage1.md` must say so on every row
   with the `reformatter/CMakeLists.txt:38` citation, and the package
   should be recorded as blocked rather than left with a recipe that cannot
   run.
3. If a path forward is wanted, it needs a system-level change — a cmake old
   enough to accept `GET_TARGET_PROPERTY(... LOCATION)`, i.e. < 3.19 — and
   that belongs in the system files, not in a recipe. Flag it for the
   director rather than working around it here.
4. Independently of whichever path is chosen, the `cmake --build build
   --target yajl_s` line must go: `src/CMakeLists.txt:80`'s unconditional
   `INSTALL(TARGETS yajl ...)` means a target-scoped build cannot install.

## Carried to the build

Nothing to verify until the above is settled — the current recipe produces no
`$OUT` to inspect. Once a build is possible, the checks are:

```sh
# 1. The archive, and no shared object if the recipe stays static-only.
[ -f lib/libyajl.a ]
ls lib | grep -c '^libyajl'          # expected 1 if only the static lib is built

# 2. Headers.
[ -f include/yajl/yajl_parse.h ]
[ -f include/yajl/yajl_tree.h ]
[ -f include/yajl/yajl_version.h ]

# 3. The .pc file, and in share/pkgconfig -- this one really is there.
pkg-config --modversion yajl          # expected 2.1.0
[ -f share/pkgconfig/yajl.pc ]

# 4. No programs: json_reformat, json_verify.
[ ! -d bin ]
```

Check 3's path is `share/pkgconfig`, verified against
`src/CMakeLists.txt:87` — deliberately the opposite of jasper's
`lib/pkgconfig`, so the two do not get confused. Check 1's expected value
depends on defect 2's fix and should be set to match whatever the recipe
then builds.
