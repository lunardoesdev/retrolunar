# stage3 (Android) — i2pd 2.61.0 built on aarch64-android35

Built and installed. `bin/i2pd` is an Android 35 aarch64 PIE with
`/system/bin/linker64` as its interpreter, all three archives and 68 headers
are in the prefix, and the five data symlinks are present. Every command
below was run against the real prefix.

This covers ONE system. `packages/boost/android.lua` is per-family, so the
other three architectures and every other API level take their own run; see
"What was NOT verified".

## How it was built

```sh
ninja -C builddir retrolunar
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'i2pd@aarch64-android35' > build.sh
sh -n build.sh
ANDROID_HOME=/path/to/sdk flock ~/ond/git/rl-build.lock sh -c 'sh build.sh'
```

Freshness invalidated first, so the log is a real build:

```sh
rm -f nest/aarch64-android35/.retrolunar-boost \
      nest/aarch64-android35/.retrolunar-i2pd
```

Result: exit 0, 90 `Building CXX object` lines, and all nine blocks report
`(fresh)` on rerun.

Dependency resolution, from the log:

```
-- Found Boost: .../nest/aarch64-android35/lib/cmake/Boost-1.92.0/BoostConfig.cmake (found version "1.92.0") found components: filesystem program_options atomic
-- Found OpenSSL: .../nest/aarch64-android35/lib/libcrypto.a (found version "4.0.3")
-- Found ZLIB: .../nest/aarch64-android35/lib/libz.so (found version "1.3.1")
```

That first line is stage1.md's blocker, cleared on Android too.

## The blocker, and what removed it

`packages/boost/generic.lua` installs headers only, which cannot satisfy
`find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)`
(`build/CMakeLists.txt:289`). stage1.md:295-301 warned that nothing in the
tree was evidence that a *compiled* Boost builds on Android. This is that
evidence, and getting it took three non-obvious things, each measured:

**1. b2 does not read `$CC`/`$CXX`/`$AR`.** With no `using` line it prints
`warning: Configuring default toolset "clang"` and builds for the build
machine. `packages/boost/android.lua` writes `user-config.jam` from the
system's variables and names it with `--user-config`, because
`build-system.jam:461` loads it from `$HOME/.b2` and **not** from the current
directory — probed: the same file in the CWD still produced
`No toolsets are configured`.

**2. b2 overrode the NDK triple.** Left alone, `clang.jam:113-117` derives
`--target=arm64-pc-linux` from the detected architecture. That overrides the
NDK wrapper's own triple, so the driver stops knowing it targets Android,
never adds the sysroot or the libc++ include paths, and every C++ compile
dies on:

```
./boost/config/detail/select_stdlib_config.hpp:26:14: fatal error: 'cstddef' file not found
```

Probed both ways against NDK 28.2.13676358:

```
$CXX --target=arm64-pc-linux            /tmp/c.cpp -> cstddef not found
$CXX --target=aarch64-linux-android35   /tmp/c.cpp -> exit 0
```

`<triple>` is read at `clang-linux.jam:79` and suppresses the guess.

**3. The API level has to be in the triple.** A bare Android triple carries
no API level and the NDK resolves it to its minimum, 21 — so
`aarch64-linux-android` silently pins the build to 21 while the system says
35. The recipe uses `$HOST_TRIPLET$ANDROID_API`. That difference is not
cosmetic; it is exactly the wall i2pd hits at 21:

```
--target=aarch64-linux-android    -> getifaddrs MISSING (API 21)
--target=aarch64-linux-android35  -> getifaddrs OK
```

Bionic declares `getifaddrs` `__INTRODUCED_IN(24)`, and stage1.md flagged
API 21 as WILL NOT BUILD for this reason. Confirmed independently against
all three levels: 21 missing, 24 and 35 present.

**4. `target-os=android` on the b2 command line.** Without it b2 believes it
is building for glibc Linux and adds `-lrt` to shared links. Bionic has no
librt at all — the NDK sysroot for `aarch64-linux-android/35` contains
`libdl.so` but no `librt.so` — so every shared link died with:

```
ld.lld: error: unable to find library -lrt
```

This one is load-bearing rather than tidy: `WITH_STATIC=OFF` is the default,
and `build/CMakeLists.txt:282` then defines `BOOST_*_DYN_LINK`, so the
consumer wants the shared variant. `android` is a declared b2
`target-os` value (`tools/build/src/tools/features/os-feature.jam:12`,
feature declared at `:95` as propagated link-incompatible), not a hack.

## Artifact checks

All against `$PREFIX = nest/aarch64-android35`.

**The daemon** — expected an Android aarch64 PIE:

```
$ file bin/i2pd
bin/i2pd: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 35, built by NDK r28c (13676358), not stripped
```

`for Android 35` and `/system/bin/linker64` are the two things worth
reading: the API level came from the system's, and the binary is built to run
on a device, not the host. **No emulator was used and none installed.**

**Shared library dependencies**:

```
$ llvm-readelf -d bin/i2pd | grep NEEDED
  (NEEDED)  Shared library: [libm.so]
  (NEEDED)  Shared library: [liblog.so]
  (NEEDED)  Shared library: [libboost_filesystem.so]
  (NEEDED)  Shared library: [libboost_program_options.so]
  (NEEDED)  Shared library: [libboost_atomic.so]
  (NEEDED)  Shared library: [libz.so.1]
  (NEEDED)  Shared library: [libc++_shared.so]
  (NEEDED)  Shared library: [libboost_container.so]
  (NEEDED)  Shared library: [libdl.so]
  (NEEDED)  Shared library: [libc.so]
```

Three things are worth reading off that list:

- All three requested Boost components are linked, plus `container`,
  which is a dependency of `filesystem` rather than a request.
- `liblog.so` is there because the Android systems put `-llog` in
  `$LDFLAGS` for exactly the abseil/glog `__android_log_write` reason
  `aarch64-android35/generic.lua` documents.
- `libc++_shared.so` proves the NDK sysroot resolved — that is the library
  that would have been missing under the wrong `--target`.

**The Boost artifacts are genuine Android binaries**, not host objects:

```
$ file lib/libboost_filesystem.so
lib/libboost_filesystem.so: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, for Android 35, built by NDK r28c (13676358), not stripped
$ llvm-readelf -d lib/libboost_filesystem.so | grep NEEDED
  (NEEDED)  Shared library: [libboost_atomic.so]
  (NEEDED)  Shared library: [libc++_shared.so]
  (NEEDED)  Shared library: [libm.so]
```

This is the check that distinguishes a working cross build from a host build
that happens to compile.

**The three archives and the headers**:

```
$ ls -la lib/libi2pd*.a
-rw-r--r-- 1 si si 15196604 Oct  1 22:07 lib/libi2pd.a
-rw-r--r-- 1 si si 12212752 Oct  1 22:07 lib/libi2pdclient.a
-rw-r--r-- 1 si si  1675616 Oct  1 22:07 lib/libi2pdlang.a
$ ls include/i2pd | wc -l
68
```

Same 68 as the mingw build, from the same `i18n/` + `libi2pd/` +
`libi2pd_client/` flattening.

**Data files**, scoped to this package's own directory rather than the shared
prefix:

```
$ ls etc/i2pd/
i2pd.conf  subscriptions.txt  tunnels.conf  tunnels.conf.d
$ find share/i2pd/certificates -name '*.crt' | wc -l
22
$ ls share/man/man1/
i2pd.1
$ find var/lib/i2pd -type l | wc -l
5
```

The five symlinks are the same relative ones the mingw build verified as
resolving (`stage3.md`); they are counted here rather than re-resolved
because `stage3.md` already did that against the identical recipe lines.

## No target binary was executed

The upstream test suite is off (`-DBUILD_TESTING=OFF`, which
`build/CMakeLists.txt:416-418` gates `tests/` on) and nothing in this build
runs `bin/i2pd`. All of the above is static inspection — `file`,
`llvm-readelf`, and filesystem checks. The host does have `qemu-aarch64`
registered via `binfmt_misc`, so this is stated rather than assumed.

## What was NOT verified, and why

- **One system only.** `aarch64-android35` was built. `armv7a-*`, `i686-*`
  and `x86_64-*` take the same `packages/boost/android.lua` — b2 derives
  `<architecture>` from the driver, and all four NDK triples were confirmed
  to configure and compile in the probe — but "confirms the triple" is not
  "a finished build", and this file does not claim them.
- **API levels below 24 cannot work.** Verified for `getifaddrs` at 21/24/35;
  `stage1.md` already recorded the API-21 row as WILL NOT BUILD for that
  reason. Nothing was built at 21 or 23.
- **`packages/i2pd/android.lua`'s `-DANDROID_BINARY` correction is now
  exercised** — i2pd's own configure summary reports it reaching the
  compiler, which is the thing `android.lua:43` exists to arrange:

  ```
  -- Compiler flags     : -O2 -fPIC -I.../include -DANDROID -DANDROID_BINARY -Wall -Wextra -Winvalid-pch ...
  ```

  What that does *not* establish is which daemon implementation was
  selected. `daemon/Daemon.h:100` picks `DaemonAndroid` for
  `ANDROID && !ANDROID_BINARY`, and that failure mode is silent — the stub
  compiles and links against the base class. Nothing was run to observe the
  behaviour, so the argument stays a source-reading one; only the flag's
  delivery is measured.
- **Runtime data paths are not proven.** `libi2pd/FS.cpp:184-192` puts the
  data dir under `$EXTERNAL_STORAGE/i2pd` and skips the `/var/lib/i2pd`
  service path under `-DANDROID` (`FS.cpp:94`), so the symlink farm is only
  used if something passes `--datadir`. Not tested.
- **The `.so` files in `lib/` need staging.** `$PREFIX/lib` holds the four
  Boost `.so` and `libz.so*`; an on-device deployment has to place them
  alongside the binary or on the loader path. The nest is a build prefix,
  not a package.