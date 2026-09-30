# nanopb 0.4.9.2 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-nanopb
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'nanopb@aarch64-android24' > /tmp/build-nanopb.sh
sh -n /tmp/build-nanopb.sh          # exit 0 — syntax gate passed
sh /tmp/build-nanopb.sh
```

## Stale-artifact cleanup — this package HAD stale artifacts

nanopb is one of the six the discarded run left behind. Deleted before the
build, with the mtimes that identified them as foreign:

```
$ ls -la nest/aarch64-android24/lib/*nanopb*
-rw-r--r-- 1 si si 32224 Sep 30 23:38 nest/aarch64-android24/lib/libprotobuf-nanopb.a

$ ls -la nest/aarch64-android24/include/nanopb
-rw-r--r-- 1 si si 44315 Sep 30 23:38 nest/aarch64-android24/include/nanopb/pb.h
-rw-r--r-- 1 si si  1677 Sep 30 23:38 nest/aarch64-android24/include/nanopb/pb_common.h

$ ls nest/aarch64-android24/lib/pkgconfig/*nanopb*
nest/aarch64-android24/lib/pkgconfig/nanopb.pc

$ ls -d nest/aarch64-android24/lib/cmake/nanopb
(no output — did not exist)
```

Deleted: `.retrolunar-nanopb` stamp, `lib/libprotobuf-nanopb.a`,
`include/nanopb/` (whole dir), `lib/pkgconfig/nanopb.pc`, any
`nanopb_generator.py`. Post-delete check printed `clean`.

**The size coincidence is worth naming explicitly.** The freshly built
`libprotobuf-nanopb.a` is *also* 32224 bytes — byte count alone would have
been a false pass here. It is a different object: the mtime is `Oct 1 03:14`
against the stale file's `Sep 30 23:38`, and the log shows the three
translation units compiled and archived during this run. `nest/source/nanopb/`
was **not** deleted: the preflight compared all fifteen `source.lua` files
against the staged trees and every version and URL matches, so the source stamp
was valid and this is the upstream tree.

## Outcome: **SUCCESS**

Real work in the log:

```
-- Detecting C compile features - done
-- Configuring done (0.4s)
-- Generating done (0.0s)
[ 25%] Building C object CMakeFiles/protobuf-nanopb-static.dir/pb_common.c.o
[ 50%] Building C object CMakeFiles/protobuf-nanopb-static.dir/pb_encode.c.o
[ 75%] Building C object CMakeFiles/protobuf-nanopb-static.dir/pb_decode.c.o
[100%] Linking C static library libprotobuf-nanopb.a
[100%] Built target protobuf-nanopb-static
```

Install:

```
-- Installing: .../out-IFuiH9/lib/libprotobuf-nanopb.a
-- Installing: .../out-IFuiH9/lib/cmake/nanopb/nanopb-targets.cmake
-- Installing: .../out-IFuiH9/lib/cmake/nanopb/nanopb-targets-noconfig.cmake
-- Installing: .../out-IFuiH9/lib/cmake/nanopb/nanopb-config.cmake
-- Installing: .../out-IFuiH9/lib/cmake/nanopb/nanopb-config-version.cmake
-- Installing: .../out-IFuiH9/include/nanopb/pb.h
-- Installing: .../out-IFuiH9/include/nanopb/pb_common.h
-- Installing: .../out-IFuiH9/include/nanopb/pb_encode.h
-- Installing: .../out-IFuiH9/include/nanopb/pb_decode.h
```

The preflight's `CMakeLists.txt:19-23` hazard did **not** fire. Lines 19-20
are `find_program(nanopb_PROTOC_PATH protoc PATHS generator-bin generator
NO_DEFAULT_PATH)` followed by an unconditional second `find_program`; the
`FATAL_ERROR` at line 22 is satisfied because the release tarball ships
`generator/protoc`. Configure completed cleanly.

## Artifact verification (real output)

The one command that proves it — `llvm-objdump -f` showing the architecture:

```
$ llvm-objdump -f nest/aarch64-android24/lib/libprotobuf-nanopb.a | head -3

nest/aarch64-android24/lib/libprotobuf-nanopb.a(pb_common.c.o):	file format elf64-littleaarch64
architecture: aarch64
start address: 0x0000000000000000
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls -la $PREFIX/lib/libprotobuf-nanopb.a` | `-rw-r--r-- 1 si si 32224 Oct  1 03:14 nest/aarch64-android24/lib/libprotobuf-nanopb.a` |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libprotobuf-nanopb.a \| grep -E ' T (pb_encode\|pb_decode)$'` | `00000000000000e4 T pb_encode`, `0000000000000c1c T pb_decode` |
| headers under `include/nanopb/` | `ls $PREFIX/include/nanopb/` | `pb.h  pb_common.h  pb_decode.h  pb_encode.h` |
| CMake package config | `ls $PREFIX/lib/cmake/nanopb/` | `nanopb-config.cmake  nanopb-config-version.cmake  nanopb-targets.cmake  nanopb-targets-noconfig.cmake` |
| **no generator installed** | `find $PREFIX -name 'nanopb_generator.py'` | *(no output)* — `-Dnanopb_BUILD_GENERATOR=OFF` took |
| **no `bin/`** | `ls $PREFIX/bin` | nothing from this build |

### Two corrections to the forecasts

1. **Archive name.** `stage2.md` predicted `lib/libnanopb.a`. Upstream sets
   `OUTPUT_NAME protobuf-nanopb` on the static target
   (`nest/source/nanopb/CMakeLists.txt:159-161`), so the real file is
   **`lib/libprotobuf-nanopb.a`** — the preflight brief §4 had this right and
   `stage2.md` had it wrong. The recipe is correct; the forecast was wrong.

2. **No `.pc` file.** `stage2.md` predicted
   `lib/pkgconfig/nanopb.pc` checked with `pkg-config --modversion nanopb`.
   Upstream nanopb 0.4.9.2 ships **no pkg-config template at all** — there is
   no `pkgconfig` string anywhere in `CMakeLists.txt`, and `extra/` contains
   no `.pc.in` (`FindNanopb.cmake`, `nanopb-config.cmake`,
   `nanopb-config-version.cmake.in`, `nanopb.mk`, `pb_syshdr.h`, `poetry/`,
   `bazel/`, `requirements*.txt`, `script_wrappers/`). The only
   `install(FILES ...)` rules are the two CMake config files and the four
   headers. Verified:

   ```
   $ pkg-config --modversion nanopb
   Package nanopb was not found in the pkg-config search path.
   Package 'nanopb' not found
   $ ls nest/aarch64-android24/lib/pkgconfig/nanopb.pc
   no nanopb.pc installed by this build
   ```

   The `.pc` that was in the prefix before this build was deleted with the
   rest of the stale set — it was produced by the discarded recipe, not by
   upstream. **No `.pc` is correct**; the brief §4 said so. This is a stage2
   forecast error, **not** a recipe defect, so no recipe was changed.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-nanopb.sh
skip nanopb@source (fresh)
skip nanopb@aarch64-android24 (fresh)
```

## System-level findings

- `$CMAKE_FLAGS` on every Android system carries
  `-DTHREADS_PREFER_PTHREAD_FLAG=ON` (used by `packages/aarch64-android24/generic.lua`),
  which nanopb's CMakeLists never reads. It produced a benign warning, quoted:

  ```
  CMake Warning (unused-cli):
    Manually-specified variables were not used by the project:

      THREADS_PREFER_PTHREAD_FLAG
  ```

  Cosmetic only — CMake warns and continues, the build is unaffected.
  Recorded, not worked around; a system file is out of scope for the builder.
- No recipe change was made; `packages/nanopb/generic.lua` and `source.lua`
  are committed unmodified.
