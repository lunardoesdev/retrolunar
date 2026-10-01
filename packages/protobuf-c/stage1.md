# protobuf-c 1.5.1 — build forecast

Source: `protobuf-c-1.5.1.tar.gz`, release tarball from
`github.com/protobuf-c/protobuf-c/releases/download/v1.5.1/`.
Archive verified before reading: 531693 bytes, `gzip -t` clean, 108 archive
entries -> 90 extracted files (the delta is directory entries), and
`configure` 706594 B / `Makefile.in` 164936 B / `config.h.in` 5833 B all
present and non-zero. All research below was done in that verified tree.

## The dependency question

`topackage.md:168` records protobuf-c as "blocked on its dependency:
1.5.1's configure requires Google protobuf >= 3.0.0". **That is true of the
default configuration and false of the library.** The requirement is entirely
confined to the protoc branch:

- `configure.ac:68` declares `--disable-protoc`.
- `configure.ac:70` opens `if test "x$enable_protoc" != "xno"`, and
  `configure.ac:73` is the `PKG_CHECK_MODULES([protobuf], [protobuf >= 3.0.0])`
  the checklist refers to.
- `configure.ac:89` additionally *executes* `$PROTOC --version` at configure
  time — a host program run during configure.
- `Makefile.am:75` opens `if BUILD_COMPILER`; `protoc-gen-c` and its sources
  (`:76-97`), its `-lprotoc`/`$(protobuf_LIBS)` link (`:110-112`) and the
  `@PROTOC@` generation rule (`:114-120`) are all inside it. The
  `install-exec-hook` symlink to `bin/protoc-c` (`:125-127`) is too, so
  nothing dangles when the block is skipped.
- The library itself: `Makefile.am:50-52` lists `protobuf-c/protobuf-c.c`
  and `protobuf-c/protobuf-c.h` only — no generated files, no C++.
  `protobuf-c/libprotobuf-c.pc.in` has no `Requires` at all (0 matches).

So protobuf-c is buildable **today, with no protobuf**, and the recipe does
not `require("protobuf")`. The cmake build in `build-cmake/` cannot be used
instead: it calls `find_package(Protobuf CONFIG)` and falls back to
`find_package(Protobuf REQUIRED)` at `build-cmake/CMakeLists.txt:18-26`, plus
`find_package(absl CONFIG)` at `:28`, all *before* `option(BUILD_PROTOC ...)`
at `:48` — so `-DBUILD_PROTOC=OFF` would not remove the dependency there.

## API-gate exposure

None. The only system headers the two translation units include are
`stdlib.h`, `string.h` (`protobuf-c.c:48-49`) and `assert.h`, `limits.h`,
`stddef.h`, `stdint.h` (`protobuf-c.h:200-203`). Nothing from the API-21
wall list (real `stderr`, `POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`,
`mblen`, `getpass`, `O_BINARY`) appears, so API 21, 24, 26, 28 and 35 are
identical. armv7a and i686 behave like aarch64 for the same reason.

## Verdicts

| System family | Verdict | Why |
|---|---|---|
| aarch64-android21 | WILL BUILD | Portable C only (`protobuf-c.c:48-49`, `protobuf-c.h:200-203`); no API-21 symbol used. `AC_USE_SYSTEM_EXTENSIONS`/`AC_SYS_LARGEFILE` (configure.ac:18-19) compile on Bionic. |
| aarch64-android24 | WILL BUILD | Same, and 24 is past the API-21 wall anyway. |
| aarch64-android35 | WILL BUILD | Same. |
| x86_64-android35 | WILL BUILD | Same; no arch-specific code in the package. |
| x86_64-mingw | UNCERTAIN | The source itself is portable, but this is a libtool package: `LT_INIT` (configure.ac:22) plus `gl_LD_VERSION_SCRIPT` (configure.ac:98). On mingw the version-script path is expected to fall back to `-export-symbols-regex` (`Makefile.am:58-63`). I did not compile against the mingw wrappers, so the libtool link step is unverified here. |
| clang-native | WILL BUILD | Native build, `--host`/`--build` identical, no cross probes to defeat. |

## Serial / memory

Two source files, one static archive, serial `make -j1`. Peak memory is a
single C translation unit; nowhere near the 2 GB ceiling in
`topackage.md:106-108`. No test suite is built: `Makefile.am:133-349` puts
every `check_PROGRAMS`/`TESTS` entry inside `if CROSS_COMPILING ... else`,
and `configure.ac:96` sets that conditional from autoconf's own
`$cross_compiling`.
