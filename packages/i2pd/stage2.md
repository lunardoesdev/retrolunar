ACCEPT

Reviewed `source.lua`, `generic.lua`, `android.lua` and `stage1.md`, then
configured and built the package on `x86_64-mingw`. This verdict covers what
was actually observed, and one required change fell out of the build.

## The recipes as written

`generic.lua` was accepted unchanged. It uses the system for everything:
`$CMAKE_FLAGS` carries the toolchain, install prefix, prefix path and
make program; `$OUT` is the install target; `$PREFIX` is the search path.
No hardcoded target facts, no `export` of search flags, no
`git`/`jj`, no `sed`, no fan-out (`cmake --build cmakebuild --parallel 1`).
`require()` order is dependencies-first, `recipe()` last.

`-DBUILD_TESTING=OFF` is load-bearing, as stage1.md argues:
`build/CMakeLists.txt:416-418` adds `tests/` only when it is on, and
`tests/CMakeLists.txt:111-123` registers thirteen `add_test()` rules that run
the freshly built target binaries. Confirmed in the configure log of the run
that built this package: no `Check` lookup, no test target.

`android.lua` keeps its `-DANDROID_BINARY` append to `$CXXFLAGS` (its
`android.lua:43`) and its comment explains the `Daemon.h:100` stub at length.
Not exercised here — this review is the mingw build — so it is recorded as
unreviewed rather than accepted.

## stage1.md's mingw open questions, answered

stage1.md § "Open questions" listed three items it could not settle for
`x86_64-mingw`. All three are now settled by the build:

1. **`Boost::filesystem` at `build/CMakeLists.txt:399-403`** —
   `get_target_property(BOOSTFSLIBS Boost::filesystem INTERFACE_LINK_LIBRARIES)`
   runs. It succeeds: `Boost::filesystem` exists as an imported target
   (`lib/cmake/boost_filesystem-1.92.0/libboost_filesystem-variant-static.cmake:58`
   `add_library(Boost::filesystem STATIC IMPORTED)`), so the property read
   does not return `-NOTFOUND`, and `list(REMOVE_ITEM BOOSTFSLIBS
   synchronization)` at :402 is a no-op. Generate completed.
2. **`-Winvalid-pch` (`:156`)** — no diagnostic. It appears in the compile
   line and clang/gcc 16.2.1 says nothing about it.
3. **`WITH_STATIC=OFF` assumes shared Boost** — correct as written, because
   `packages/boost/x86_64-mingw.lua` installs both variants; the linked
   `bin/i2pd.exe` imports `libboost_filesystem.dll` and
   `libboost_program_options.dll` (verified with `objdump -p`, output in
   stage3.md).

stage1.md's "every row is blocked on Boost today" no longer holds for
mingw. It still holds for the Android rows, and
`packages/boost/generic.lua` is unchanged, so that is recorded rather than
papered over.

## REJECT-then-fixed: what the build exposed

The recipe did not need changing; three things around it did. Each was
fixed at the level that owns it.

**1. `packages/boost` shipped headers only.** Required, because
`find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)`
(`build/CMakeLists.txt:289`) needs a compiled archive *and* a component
package config per component. `boost_headers` alone is not enough. Fixed by
adding `packages/boost/x86_64-mingw.lua`, which builds the three components
plus `container` (a dependency of `filesystem`) via
`b2 --with-atomic --with-filesystem --with-program_options install`.

**2. The b2 toolset was the host's, silently.** b2 does not read `$CC` /
`$CXX` / `$AR`. With no `using` line it prints `warning: Configuring default
toolset "gcc"` and builds for the build machine — the nest collected ELF
`libboost_*.so.1.92.0` into the mingw prefix on the first attempt, and cmake
then failed with `IMPORTED_IMPLIB not set for imported target
"Boost::filesystem"`, which is what a `.so` looks like to a Windows
consumer. Fixed by writing `user-config.jam` from `$CXX`/`$AR`/`$RANLIB` and
naming it with `--user-config`, because
`tools/build/src/build-system.jam:461` loads it from `$HOME/.b2` and **not**
from the current directory — verified: the same file in the CWD still
produced the default-toolset warning.

`$CXX` and not `$CC`, and the reason is in the recipe: `gcc.jam:163` uses one
`command` for both languages and `gcc.jam:248` derives the archiver from it,
and b2 never adds `-lstdc++` itself. Handed `...-gcc`, every C++ link failed
with `undefined reference to 'operator new(unsigned long long)'`.

**3. A host library directory reached the target link line.** Two separate
system-level defects, both in `packages/x86_64-mingw/generic.lua`:

- `build/CMakeLists.txt:314` is `link_directories(${ZLIB_ROOT}/lib)`.
  `ZLIB_ROOT` was unset, so that expanded to the literal `/lib`, which on this
  host is a symlink to `/usr/lib` — glibc's directory, where `libpthread.a`
  is an **8-byte empty archive** (`od -c` → `!<arch>\n`). It shadowed
  mingw's real winpthreads archive and the link died on `undefined reference
  to 'pthread_self'` and every other winpthreads symbol. Fixed with
  `-DZLIB_ROOT=$PREFIX` in `$CMAKE_FLAGS`.
- The Windows import libraries. Upstream's cmake appends `crypt32` for MSVC
  only (`build/CMakeLists.txt:378-381`) and never adds the COM libraries, so
  the link failed on `__imp_CertFindCertificateInStore` (OpenSSL's mingw
  build reaches the Windows certificate store, so `libcrypto.a` itself
  carries the reference) and on `__imp_CoCreateInstance` /
  `IID_IConnectionPointContainer`.

  They are **not** in `$LDFLAGS`, and that placement was measured rather than
  assumed. cmake seeds `CMAKE_EXE_LINKER_FLAGS` from `$LDFLAGS`
  (`CMakeCommonLanguageInclude.cmake:9`), which puts those flags *before* the
  archives that reference them; i2pd links its static libs through a
  response file, so `libcrypto.a` is scanned later and ld does not revisit an
  archive it has passed. With the flags in `$LDFLAGS` the same link still
  failed on `__imp_CertFindCertificateInStore`. Moving the identical five
  flags to the end of the same link line produced a clean `i2pd.exe`. They
  therefore go through `-DCMAKE_REQUIRED_LIBRARIES=`, which i2pd forwards to
  its final link at `build/CMakeLists.txt:409`.

**4. A target variable reached a host build.** `packages/boost/clang-native.lua`
builds the b2 engine with the *host* compiler, but the block inherits the
environment of the build script it runs inside, and
`tools/build/src/engine/build.sh:505` finds `WINDRES` from the environment
with no flag to override it. `x86_64-mingw/generic.lua` exports
`WINDRES=x86_64-w64-mingw32-windres`, so the host engine got a PE resource
object linked into an ELF executable and died with
`res.o:(.rsrc+0x48): dangerous relocation: R_AMD64_IMAGEBASE with __ImageBase
undefined`. Fixed by clearing `WINDRES` and setting
`B2_DONT_EMBED_MANIFEST` for that one command, which is what upstream's own
script honours. Verified: with `WINDRES` still exported, the engine builds
clean and `file` reports ELF.

## The five `var/lib/i2pd` symlinks

stage1.md § 5 asked a builder to resolve each one after the loader's
`cp -rf`. All five resolve; output in stage3.md. They are relative, as the
recipe's comment claims.

## Verdict

ACCEPT, conditional on the four fixes above, all of which are in the tree.
The package builds, links and installs on `x86_64-mingw`; see `stage3.md`
for the log and the artifact checks. Android remains unverified and stays
recorded as such in `stage1.md`.