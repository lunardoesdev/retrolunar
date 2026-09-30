# rapidjson 1.1.0 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-rapidjson
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'rapidjson@aarch64-android24' > /tmp/build-rapidjson.sh
sh -n /tmp/build-rapidjson.sh          # exit 0 — syntax gate passed
sh /tmp/build-rapidjson.sh
```

## Stale-artifact cleanup

rapidjson had **no** stale artifacts — it was never built by the discarded
run:

```
$ ls nest/aarch64-android24/include/rapidjson 2>/dev/null
(no output)
$ ls nest/aarch64-android24/lib/pkgconfig/RapidJSON.pc \
      nest/aarch64-android24/lib/cmake/RapidJSON \
      nest/aarch64-android24/share/doc/RapidJSON 2>/dev/null
(no output)
$ ls -a nest/aarch64-android24/.retrolunar-rapidjson
ls: cannot access '.../.retrolunar-rapidjson': No such file or directory
```

The stamp delete and the `rm -rf` of the three artifact paths were run
unconditionally; the post-delete check confirmed `include/rapidjson gone`.
Every artifact below is mtime-checked at `Oct 1 03:15`, from this build.

## Outcome: **SUCCESS**

rapidjson is header-only, so **there is no compile step by design** — the
recipe says so in a comment, and `CMakeLists.txt` has no `add_library` at
all. The build is therefore configure + install, and the install did 75 real
file operations. This is the preflight's third "no `.a` is correct" case, not
a no-op build: had the switches been wrong the log would show
`add_executable` lines and `-march=native` errors.

Configure:

```
-- Configuring done
-- Generating done
```

The switches all took, which is what the log proves by *absence*:

- `RAPIDJSON_BUILD_EXAMPLES=OFF` — the preflight's ranked hazard. No
  `Building CXX object` line appears anywhere in the log, so
  `example/CMakeLists.txt`'s fifteen unconditional `add_executable`s with
  `-Werror -Weverything` and the top level's `-march=native` never fired.
- `RAPIDJSON_BUILD_DOC=OFF` — no doxygen invocation.
- `RAPIDJSON_BUILD_TESTS=OFF` — `test/`, which needs the thirdparty/gtest
  submodule the tag archive does not carry, is untouched.

Install (75 `-- Installing:` lines; the shape is headers + one `.pc` + two
CMake config files + docs):

```
-- Installing: .../out-ISq0mi/lib/pkgconfig/RapidJSON.pc
-- Installing: .../out-ISq0mi/lib/cmake/RapidJSON/RapidJSONConfig.cmake
-- Installing: .../out-ISq0mi/lib/cmake/RapidJSON/RapidJSONConfigVersion.cmake
-- Installing: .../out-ISq0mi/share/doc/RapidJSON/readme.md
-- Installing: .../out-ISq0mi/share/doc/RapidJSON/examples/tutorial/tutorial.cpp
... (75 total)
```

## Artifact verification (real output)

The one command that proves it — `[ -f $PREFIX/include/rapidjson/document.h ]`:

```
$ test -f nest/aarch64-android24/include/rapidjson/document.h
$ echo $?
0
$ ls -la nest/aarch64-android24/include/rapidjson/document.h
-rw-r--r-- 1 si si 113794 Oct  1 03:15 nest/aarch64-android24/include/rapidjson/document.h
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| pkg-config, capitalised module name | `pkg-config --modversion RapidJSON` | `1.1.0` |
| CMake package config | `ls $PREFIX/lib/cmake/RapidJSON/` | `RapidJSONConfig.cmake`, `RapidJSONConfigVersion.cmake` |
| readme | `ls -la $PREFIX/share/doc/RapidJSON/readme.md` | `-rw-r--r-- 1 si si 8913 Oct  1 03:15 ...` |
| **no library file** | `ls $PREFIX/lib/libRapidJSON* $PREFIX/lib/librapidjson*` | `no rapidjson library (correct)` |
| examples installed, source only | `find $PREFIX/share/doc/RapidJSON/examples -name '*.cpp' \| wc -l` | `15` |
| no compiled example | `find $PREFIX/share/doc/RapidJSON/examples -type f ! -name '*.cpp'` | one hit: `examples/CMakeLists.txt` (a source file `install(DIRECTORY ...)` copies; no binaries) |

### The staged `.pc` rewrite worked

`RapidJSON.pc.in` ships `@includedir@`. The loader's staging rewrite turned
it into a real prefix path, verified by reading the published file:

```
$ cat nest/aarch64-android24/lib/pkgconfig/RapidJSON.pc
includedir=/home/si/ond/git/retrolunar/nest/aarch64-android24/include

Name: RapidJSON
Description: A fast JSON parser/generator for C++ with both SAX/DOM style API
Version: 1.1.0
URL: https://github.com/miloyip/rapidjson
Cflags: -I${includedir}
```

No `$OUT` path and no `/tmp` path leaked into the published file.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-rapidjson.sh
skip rapidjson@source (fresh)
skip rapidjson@aarch64-android24 (fresh)
```

## System-level findings

- No architecture check is possible here and none was faked: rapidjson ships no
  machine code. The header-only install is the whole deliverable, which is the
  preflight §4 caveat about "no library file" landing for the third time
  (with glm and stb).
- `stage2.md`'s **mingw** notes do not apply to this build (this is
  `aarch64-android24`, where `UNIX` is true and the config lands in
  `lib/cmake/`). The latent emitter defect it describes — the staging rewrite
  at `src/loader.lua:454-458` does not cover `$OUT/cmake/**`, so on
  `x86_64-mingw` `RapidJSONConfig.cmake` would keep its baked `$OUT` path —
  is left recorded here for whoever builds mingw. It is an emitter question,
  not a recipe one, and it is out of this build's scope.
- No recipe change was made; `packages/rapidjson/generic.lua` and
  `source.lua` are committed unmodified.
