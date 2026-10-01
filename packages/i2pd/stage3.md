# stage3 — i2pd 2.61.0 built on x86_64-mingw

Built and installed. `i2pd.exe` is a PE32+ x86-64 Windows GUI binary, the
three archives and 68 headers are in the prefix, and the five data symlinks
resolve. Every command below was run against the real prefix and its output
is pasted verbatim.

## How it was built

```sh
ninja -C builddir retrolunar
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'i2pd@x86_64-mingw' > build.sh
sh -n build.sh
flock ~/ond/git/rl-build.lock sh -c 'sh build.sh'
```

Freshness was invalidated first, as AGENTS.md requires, so the log below is a
real build and not a recorded skip:

```sh
rm -f nest/x86_64-mingw/.retrolunar-boost \
      nest/clang-native/.retrolunar-boost \
      nest/x86_64-mingw/.retrolunar-i2pd
```

Log: 2699 lines, 93 `Building CXX object` lines, 5 `skip` lines (the source
recipes and the two already-fresh dependencies), exit 0.

Dependency resolution, from the log:

```
-- Found Threads: TRUE
-- Found Boost: .../nest/x86_64-mingw/lib/cmake/Boost-1.92.0/BoostConfig.cmake (found version "1.92.0") found components: filesystem program_options atomic
-- Found OpenSSL: .../nest/x86_64-mingw/lib/libcrypto.a (found version "4.0.3")
-- Found ZLIB: .../nest/x86_64-mingw/lib/libzlib.dll.a (found version "1.3.1")
```

`found components: filesystem program_options atomic` is the line stage1.md
said could not happen. It is the whole blocker, cleared.

Install, from the log:

```
-- Installing: .../nest/tmp/out-UzAELN/lib/libi2pd.a
-- Installing: .../nest/tmp/out-UzAELN/lib/libi2pdclient.a
-- Installing: .../nest/tmp/out-UzAELN/lib/libi2pdlang.a
-- Installing: .../nest/tmp/out-UzAELN/bin/i2pd.exe
```

Those are exactly the four `install()` rules stage1.md counted at
`build/CMakeLists.txt:74, :87, :100, :411`. The rest of the prefix is the
recipe's own install step.

## What had to be fixed to get here

Four defects, none in `packages/i2pd`. Detail and the measurements behind each
are in `stage2.md`; this is the list.

1. **`packages/boost` had no compiled components**, so
   `find_package(Boost REQUIRED COMPONENTS ...)` could not resolve.
   Fixed by adding `packages/boost/x86_64-mingw.lua`.
2. **b2 built for the host.** It does not read `$CC`/`$CXX`/`$AR`; the first
   attempt collected ELF `libboost_filesystem.so.1.92.0` into the mingw
   prefix and cmake rejected it with `IMPORTED_IMPLIB not set for imported
   target "Boost::filesystem"`. Fixed by writing `user-config.jam` from the
   system's `$CXX`/`$AR`/`$RANLIB` and naming it with `--user-config`.
3. **`/lib` on a target link line.** `build/CMakeLists.txt:314` is
   `link_directories(${ZLIB_ROOT}/lib)`; `ZLIB_ROOT` was empty, so ld saw the
   host's `/usr/lib` and its 8-byte empty `libpthread.a`, shadowing winpthreads.
   Fixed with `-DZLIB_ROOT=$PREFIX` in the mingw system.
4. **Missing Windows import libraries**, and they had to go at the *end* of the
   link line, not in `$LDFLAGS` — cmake seeds `CMAKE_EXE_LINKER_FLAGS` from
   `$LDFLAGS`, which places them before the archives referencing them, and ld
   does not revisit an archive it has scanned. They now travel through
   `-DCMAKE_REQUIRED_LIBRARIES=`, which i2pd forwards to its final link.

Plus one in `packages/boost/clang-native.lua`: the cross systems export
`WINDRES`, and `tools/build/src/engine/build.sh:505` picks it up from the
environment, which linked a PE resource object into the host ELF engine.

## Artifact checks

All run against `$PREFIX = nest/x86_64-mingw`.

**The daemon** — expected a PE32+ x86-64 Windows executable:

```
$ file bin/i2pd.exe
bin/i2pd.exe: PE32+ executable for MS Windows 5.02 (GUI), x86-64, 21 sections
```

`GUI` subsystem is correct: `build/CMakeLists.txt:369` does
`add_executable("${PROJECT_NAME}" WIN32 ...)` under `if(WIN32)`.

**The three archives** — expected three, non-empty, PE objects inside:

```
$ ls -la lib/libi2pd.a lib/libi2pdclient.a lib/libi2pdlang.a
-rw-r--r-- 1 si si 16484210 Oct  1 20:20 lib/libi2pd.a
-rw-r--r-- 1 si si 12565514 Oct  1 20:20 lib/libi2pdclient.a
-rw-r--r-- 1 si si  1451256 Oct  1 20:20 lib/libi2pdlang.a
$ x86_64-w64-mingw32-ar t lib/libi2pd.a | wc -l
47
$ x86_64-w64-mingw32-ar p lib/libi2pd.a RouterInfo.cpp.obj > /tmp/ri.obj && file /tmp/ri.obj
/tmp/ri.obj: x86-64 COFF object file, no line number info, not stripped, 604 sections, ...
```

The object check matters: it proves the archives hold *target* objects, not
host ELF ones. The names carry no `lib` prefix because
`build/CMakeLists.txt:71, :84, :97` strip it, as stage1.md recorded.

**Version string** — expected `2.61.0`, since `WITH_GIT_VERSION=OFF` makes the
binary self-report the parsed `libi2pd/version.h`:

```
$ strings bin/i2pd.exe | grep -m2 '^2\.61\.0$'
2.61.0
2.61.0
```

**Headers** — expected **68**, from `i18n/` + `libi2pd/` + `libi2pd_client/`
flattened:

```
$ ls include/i2pd | wc -l
68
```

Flattening is safe because no basename collides — the check is scoped to this
package's own directory, not to `$PREFIX/include`:

```
$ ls include/i2pd | xargs -n1 basename | sort | uniq -d | wc -l
0
```

**Certificates** — expected **22** across the two subdirectories
(`family/` 6, `reseed/` 16), scoped to this package's own data directory:

```
$ find share/i2pd/certificates -name '*.crt' | wc -l
22
```

**Config and man page**:

```
$ ls etc/i2pd/
i2pd.conf
subscriptions.txt
tunnels.conf
tunnels.conf.d
$ ls share/man/man1/
i2pd.1
$ ls share/doc/i2pd/
ChangeLog  LICENSE  README.md  i2pd.conf  subscriptions.txt  tunnels.conf
```

**The five data symlinks** — stage1.md § 5 asked for exactly this, each one
resolved. Scoped to `$PREFIX/var/lib/i2pd`:

```
$ find var/lib/i2pd -type l -exec sh -c 'printf "%s -> %s (%s)\n" "$1" "$(readlink $1)" "$([ -e $1 ] && echo OK || echo BROKEN)"' _ {} \;
var/lib/i2pd/certificates -> ../../../share/i2pd/certificates (OK)
var/lib/i2pd/tunnels.d -> ../../../etc/i2pd/tunnels.conf.d (OK)
var/lib/i2pd/i2pd.conf -> ../../../etc/i2pd/i2pd.conf (OK)
var/lib/i2pd/subscriptions.txt -> ../../../etc/i2pd/subscriptions.txt (OK)
var/lib/i2pd/tunnels.conf -> ../../../etc/i2pd/tunnels.conf (OK)
```

They survived the loader's `cp -rf "$OUT"/. "$NESTDIR/<sys>/"` because they
are relative, which is the reason the recipe makes them so.

**Imports** — the evidence that the linker fixes are real, read with
`objdump -p`:

```
$ x86_64-w64-mingw32-objdump -p bin/i2pd.exe | grep 'DLL Name' | sort
	DLL Name: ADVAPI32.dll
	DLL Name: CRYPT32.dll
	DLL Name: GDI32.dll
	DLL Name: IPHLPAPI.DLL
	DLL Name: KERNEL32.dll
	DLL Name: SHELL32.dll
	DLL Name: USER32.dll
	DLL Name: WS2_32.dll
	DLL Name: WSOCK32.dll
	DLL Name: api-ms-win-crt-convert-l1-1-0.dll
	... (11 more api-ms-win-crt-* entries)
	DLL Name: libboost_filesystem.dll
	DLL Name: libboost_program_options.dll
	DLL Name: libgcc_s_seh-1.dll
	DLL Name: libstdc++-6.dll
	DLL Name: libwinpthread-1.dll
	DLL Name: libzlib.dll
	DLL Name: ole32.dll
```

Three things are worth reading off this list:

- `CRYPT32.dll` and `ole32.dll` are imported. They were the two missing
  system libraries.
- `libwinpthread-1.dll`, not a glibc path. The host's empty
  `libpthread.a` shadowing winpthreads is gone.
- `libboost_filesystem.dll` and `libboost_program_options.dll` are imported,
  which is consistent with `WITH_STATIC=OFF`
  (`build/CMakeLists.txt:282` adds the `BOOST_*_DYN_LINK` defines). The DLLs
  themselves land in `$PREFIX/bin` next to the executable, so the pair runs
  from the prefix without extra staging.

**No `.pc` file and no CMake package config** — expected, per stage1.md:
`build/CMakeLists.txt` has no `install(FILES ...)` and no `install(EXPORT ...)`,
so `pkg-config --modversion i2pd` is not a valid check here and was not run.

## Freshness

Re-running the same script prints fresh for all nine blocks:

```
skip i2pd@source (fresh)
skip openssl@source (fresh)
skip openssl@x86_64-mingw (fresh)
skip zlib@source (fresh)
skip zlib@x86_64-mingw (fresh)
skip boost@source (fresh)
skip boost@clang-native (fresh)
skip boost@x86_64-mingw (fresh)
skip i2pd@x86_64-mingw (fresh)
```

This is meaningful only because the stamps were deleted before the build
above; the log for that run contains 93 real compiles, not skips.

## The b2 engine is a host binary

`packages/boost/clang-native.lua` installs the engine that drives the cross
build, so it must be runnable here:

```
$ file nest/clang-native/bin/b2
b2: ELF 64-bit LSB pie executable, x86-64, ... dynamically linked, ... stripped
```

## What was NOT verified, and why

- **No target binary was executed.** The upstream test suite is off
  (`-DBUILD_TESTING=OFF`) and nothing in this build runs `i2pd.exe`.
  Everything above is static inspection: `file`, `ar`, `objdump`, `strings`,
  and filesystem checks. No emulator was used or installed.
- **Android is untouched.** `packages/boost/generic.lua` is unchanged and
  still installs headers only, so i2pd remains blocked on every Android
  system, and `stage1.md`'s `getifaddrs` wall at API 21 stands. That gap is
  left visible, not worked around.
- **`packages/i2pd/android.lua` was not built.** Its `-DANDROID_BINARY`
  correction is reviewed on its own merits in `stage2.md` and remains
  unexercised.
- **Runtime data paths are not proven.** `stage1.md` is right that a nest
  prefix is not a runnable deployment: `libi2pd/FS.cpp:194-200` looks in
  `$HOME/.i2pd`, so the daemon needs `--datadir=$PREFIX/var/lib/i2pd`. That
  is a runtime claim and was not tested.