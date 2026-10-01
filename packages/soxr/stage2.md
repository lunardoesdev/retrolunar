ACCEPT

# soxr 0.1.3 — stage 2 review

Checked against the unpacked `soxr-0.1.3` tree in `$HOME/dl`.

## "CMake only, no autotools at all" — confirmed

```
$ ls configure configure.ac Makefile.am Makefile.in
ls: cannot access 'configure': No such file or directory
ls: cannot access 'configure.ac': No such file or directory
ls: cannot access 'Makefile.am': No such file or directory
ls: cannot access 'Makefile.in': No such file or directory
```

No autotools build exists, so there is no `config.h` template to guard and no
`./configure` to run. The recipe correctly has neither. (The tree does carry
`soxr-config.h.in`, consumed by `configure_file` at `CMakeLists.txt:260-262` —
a cmake template with no timestamp hazard, as stage1.md:8-9 notes. Correctly
identified and correctly dismissed.)

## Two libraries and two `.pc` files — confirmed

`WITH_LSR_BINDINGS` defaults ON (`CMakeLists.txt:46`), and the LSR bindings are
a real second target, not test scaffolding (`src/CMakeLists.txt:100-118`):

```cmake
if (WITH_LSR_BINDINGS)
  set (LSR ${PROJECT_NAME}-lsr)
  add_library (${LSR} ${LIB_TYPE} ${LSR})
  target_link_libraries (${LSR} ${PROJECT_NAME})
  ...
    set (TARGET_PCS "${TARGET_PCS} ${CMAKE_CURRENT_BINARY_DIR}/${LSR}.pc")
    configure_file (${CMAKE_CURRENT_SOURCE_DIR}/${LSR}.pc.in ...)
    install (FILES .../${LSR}.pc DESTINATION ${LIB_INSTALL_DIR}/pkgconfig)
```

Both `.pc.in` templates exist (`src/soxr.pc.in`, `src/soxr-lsr.pc.in`) and both
carry `Libs: -L${LIB_INSTALL_DIR} -l${PROJECT_NAME}` / `-l${LSR}`, so a consumer
gets the right `-l` for each. The main library's install is at
`src/CMakeLists.txt:89-92`. **`libsoxr.a` + `libsoxr-lsr.a` + two `.pc` files
is exactly right.**

One thing stage1 gets right that is easy to miss: both `.pc` installs are
inside `elseif (NOT WIN32)` (`src/CMakeLists.txt:89` and `:113`), so a mingw
prefix gets **no** `.pc` at all. That is a real behavioural difference between
families, and the forecast states it (stage1.md:48, :116) instead of letting a
builder discover it. Its verification line — "expect the `soxr-lsr.pc` only on
non-Windows targets" — is correct and scoped.

## `BUILD_TESTS=OFF` is load-bearing, and I confirmed the mechanism

`BUILD_TESTS` defaults ON (`CMakeLists.txt:43`), and `tests/CMakeLists.txt`
ends with a glob-and-build loop:

```cmake
file (GLOB SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/*.c)
foreach (fe ${SOURCES})
  get_filename_component (f ${fe} NAME_WE)
  add_executable (${fe} ${fe})
endforeach ()
```

I listed `tests/`: `1-delay-clear.c`, `phase-test.c`, `q-test.c`,
`throughput-test.c`, `time-test.c`, `vector-cmp.c`, `vector-gen.c` — five
`add_executable`-eligible programs (the rest are directories and support
files), each of which would be cross-compiled as a target binary. Turning the
option off also removes `add_subdirectory (examples)` at `CMakeLists.txt:288-290`,
which matters because `BUILD_EXAMPLES` triggers a second `project()` call
(`CMakeLists.txt:104`) that adds a C++ compiler to what is otherwise
`project (soxr C)`. Both switches are passed. Correct.

`BUILD_LSR_TESTS` is a `cmake_dependent_option` defaulting OFF
(`CMakeLists.txt:72-73`, conditioned on `UNIX;NOT CMAKE_CROSSCOMPILING`), and
the recipe passes `-DBUILD_LSR_TESTS=OFF` anyway so the native build does not
differ from the cross ones by default. Sensible, and the comment says why.

## No host program is compiled or run — verified

This is the one that would have been a hard blocker, and the guard holds.
`src/CMakeLists.txt:8` compiles `vr-coefs.c` into an executable and runs it to
generate `vr-coefs.h`, **but only** under:

```cmake
if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/vr-coefs.h)
  add_executable (vr-coefs vr-coefs.c)
  ...
  COMMAND vr-coefs > ${CMAKE_CURRENT_BINARY_DIR}/vr-coefs.h
```

I confirmed the header ships:

```
$ ls -la src/vr-coefs.h
-rw-r--r-- 1 si si 5336 Feb 24  2018 src/vr-coefs.h
```

so the branch is skipped and no host program is ever built, let alone run. The
comment names this trap explicitly and says a future release dropping the
header would reintroduce it — that is the right way to record a conditional
guarantee. stage1.md:124's check (`find $OUT -name 'vr-coefs' -o -name
'vector-gen' | wc -l` → 0) is correctly scoped to the two generator names.

## `-DBUILD_SHARED_LIBS=OFF` and `-DWITH_OPENMP=OFF`

Both real, both justified:

- `BUILD_SHARED_LIBS` is a `cmake_dependent_option` defaulting ON
  (`CMakeLists.txt:48-50`), and `LIB_TYPE` is chosen from it at
  `CMakeLists.txt:213-215` (`STATIC` unless `BUILD_SHARED_LIBS`). Passing it is
  what actually produces `libsoxr.a` — the archive name in the `.pc` and the
  installed file both follow. Correct and necessary.
- `WITH_OPENMP` defaults ON (`:45`) and `find_package (OpenMP)` at `:107-117`
  **mutates `CMAKE_C_FLAGS`** when it succeeds. Whether it succeeds depends on
  the build host, so leaving it on makes the compiled output host-dependent.
  soxr's resampler is single-threaded, so nothing is lost. Correct reasoning —
  this is a host-contamination argument, not a portability one, and it is the
  right argument.

Every option the recipe passes exists: `BUILD_SHARED_LIBS:48`,
`BUILD_TESTS:43`, `BUILD_EXAMPLES:44`, `BUILD_LSR_TESTS:72`,
`WITH_OPENMP:45`. No invented flags.

## Version currency

`CMakeLists.txt:14-16` sets `PROJECT_VERSION_MAJOR/MINOR/PATCH` to `0/1/3`, and
the SourceForge asset is unreachable from here, so the GitHub tag archive is
the only fetchable source of that tag. I checked for a newer tag —
`chirlu/soxr` `0.1.4.tar.gz` returns **404**, `0.1.3.tar.gz` returns **200**.
0.1.3 is current.

## The system

All flags via `$CMAKE_FLAGS`; `--prefix` from the system. No hardcoded target
facts, no exported search flags, no `android.lua` (nothing Android-specific
here). `cmake --build build --parallel 1` — no fan-out. `require("soxr@source")`
only, and correctly so: the library needs nothing but a C compiler and libm,
and `set (LIBM_LIBRARIES m)` at `CMakeLists.txt:101` plus the `-lm` every
Android system already carries in `LDFLAGS` covers it.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. The mingw row is right for the reason stage1:48 gives: the `.pc`
installs are `NOT WIN32`-guarded, so mingw simply gets fewer artifacts, and
the `MINGW` OpenMP workaround at `:112-115` is unreachable with
`WITH_OPENMP=OFF`. x86_64-android35 is right because SIMD selection
(`CMakeLists.txt:119-127`) goes through `SetSystemProcessor.cmake` off
`CMAKE_SYSTEM_PROCESSOR` and an unrecognised processor simply leaves
`WITH_CR32S`/`WITH_CR64S` off, falling back to the scalar engines
(`src/CMakeLists.txt:31-39`) — no row is architecture-blocked.

## Verdict

ACCEPT. No autotools and no guard needed, both libraries and both `.pc` files
present as claimed, the `BUILD_TESTS` glob-build trap correctly disabled, the
`vr-coefs` host-program guard verified against the file that satisfies it, the
OpenMP flag justified as host-contamination rather than wishful thinking, and
version 0.1.3 confirmed current. Nothing to fix.
