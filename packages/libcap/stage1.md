# libcap build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.78
- URL: `https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.78.tar.xz`
- Build system: **none — hand-written make.** There is no `configure`, no
  `configure.ac`, no `aclocal.m4`, and **no config header template of any
  spelling** (no `config.h.in`, `config.hin`, `configh.in`, `ac_config.h.in`,
  `configure.h.in`, `config-h.in` or `config_h.in`), because nothing is
  autoheader-generated. **There is therefore no autotools timestamp guard to
  write**, and the recipe correctly has none. Naming a template that does not
  exist would be exactly the inert `touch` AGENTS.md warns about.
- Requires: `libcap@source` only — libcap has no external dependencies.

### Reachability

`topackage.md:47` records libcap as blocked with "no reachable source". That
is **out of date**: upstream moved its release tarballs to
`mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/`, and
that directory serves `libcap-2.78.tar.xz` (201040 bytes, verified against the
server's Content-Length, `xz -t` clean, 312 archive file entries matching 312
extracted files). The old `pub/linux/libs/libcap` paths that the backlog
mentions as 404 are indeed gone, but the linux-privs path is live. The
tarball is also mirrored as `.tar.gz` on the same directory.

## The toolchain trap

`Make.Rules:68` is a **hard assignment**:

    CC := $(CROSS_COMPILE)gcc

`:=` inside a makefile overrides an exported environment variable, so an
exported `CC` is silently ignored and every object would be built with a bare
host `gcc`. Variables named on the **make command line** override makefile
assignments of any kind, so `CC`/`AR`/`RANLIB` are passed on the make line.

The exception is `BUILD_CC`. `libcap/Makefile:82-86` builds `_makenames` with
`BUILD_CC` and then **runs** it:

    _makenames: _makenames.c cap_names.list.h
    	$(BUILD_CC) $(BUILD_CFLAGS) $(BUILD_CPPFLAGS) $< -o $@
    cap_names.h: _makenames
    	./_makenames > cap_names.h

`Make.Rules:88` defaults `BUILD_CC ?= $(CC)`, so on a cross build the
capability-name table would be produced by running a *target* binary. The
recipe sets `BUILD_CC=cc` (host), the same convention `packages/texinfo/generic.lua:7`
already uses. Verified with `make -n`: the dry run shows `cc ... _makenames.c`
building `_makenames` and the target compiler building every `cap_*.o`.

`cap_names.h` is genuinely absent from the tarball (it is generated), and it
is included by `libcap/libcap.h:29`, so it must be produced.

## `lib=lib` is load-bearing

`Make.Rules:20-22` otherwise derives the library directory by running
`ldd /usr/bin/ld` **on the build machine** and cutting the output:

    lib=$(shell ldd /usr/bin/ld|grep -E "ld-linux|ld.so"|cut -d/ -f2)

On this host that answers **`lib64`**, which would install to `$OUT/lib64` and
put `libcap.pc` outside the `PKG_CONFIG_LIBDIR` every system searches
(`$PREFIX/lib/pkgconfig`). The recipe passes `lib=lib` explicitly.

## Installs

From `-C libcap` only (the top-level `Makefile:11-22` also recurses into
`pam_cap`, `go`, `tests`, `progs` and `doc`, all excluded):

- `lib/libcap.a` (+ `libcap.pc`, `include/sys/capability.h`)
- `lib/libpsx.a` (+ `libpsx.pc`, `include/sys/psx_syscall.h`) — `PTHREADS=yes`

`SHARED=no` keeps it static-only and avoids the `loader.txt` step
(`libcap/Makefile:118-122`), which builds an executable and runs
`OBJCOPY --dump-section` over it.

## Per-system verdicts

The library sources (`cap_alloc.c`, `cap_proc.c`, `cap_extint.c`,
`cap_flag.c`, `cap_text.c`, `cap_file.c`, `cap_syscalls.c`) plus the psx
sources (`psx.c`, `psx_calls.c`, `wrap/psx_wrap.c`) were compiled with the
NDK r28 clang wrappers at each API level, using libcap's own include flags
from `Make.Rules:63-64`. Results below are from those probes.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | All 7 library sources and all 3 psx sources compile clean at API 21 with no diagnostics. libcap needs `<sys/prctl.h>`, `<sys/securebits.h>`, `<sys/capability.h>`, `<byteswap.h>` and `<sys/syscall.h>`; Bionic has the first, third, fourth and fifth, and libcap **ships its own** `include/sys/securebits.h` and `include/sys/capability.h` (present in the tarball and on the include path at `Make.Rules:63-64`). It needs the raw `SYS_capset`/`SYS_prctl` numbers (`cap_proc.c:98,108`), not the libc wrappers, so the API-21 `stderr` wall does not apply. Nothing references `nl_langinfo`, `mktime_z`, `iconv`, `posix_spawn`, `pthread_cancel` or `process_vm_readv`. |
| aarch64-android24 | WILL BUILD | Same probe, clean. |
| aarch64-android35 | WILL BUILD | Same probe, clean. |
| x86_64-android35 | WILL BUILD | Same sources, endian-neutral; `cap_extint.c` uses `__builtin_bswap` via `byteswap.h`, no arch-specific syscall numbers (those are `psx_syscall.h`, which defines its own). |
| x86_64-mingw | **WILL NOT BUILD** | libcap is a Linux capabilities library and does not build on Windows at all. Probed with `x86_64-w64-mingw32-gcc`: `cap_proc.c:13` fails on `<grp.h>` (no such file), `psx/psx.c:27` fails on `<sys/syscall.h>` (no such file), `cap_file.c:16` fails on `<byteswap.h>` (no such file), and `include/sys/capability.h:163` fails on `unknown type name 'uid_t'`. The whole library is built on `prctl()`/`syscall()`/`capget`/`capset`, none of which exist on Windows. No switch can fix this; it is a platform property of the package. |
| clang-native | WILL BUILD | Native Linux/glibc; the same sources and the same make-line variables work unchanged. |

armv7a-androidNN and i686-androidNN behave like aarch64: the only
architecture-conditional code is in `psx_syscall.h`, which carries its own
syscall-number table, and `Make.Rules` adds no arch logic.

## Risks / what a reviewer should check

- **`GOLANG=no` and `PAM_CAP=no` on the make line.** `Make.Rules:123` computes
  `PAM_CAP` by probing for `/usr/include/security/pam_modules.h` **on the build
  machine** and `Make.Rules:138` probes for a `go` binary, so both are host
  facts that would otherwise vary by machine. Both are pinned off.
- **`USE_GPERF=no`.** `Make.Rules:106` probes `which gperf` on the build
  machine; `gperf` is not installed here, so the default would be `no`, but
  leaving it unset makes `cap_text.c` compile differently on a machine that
  has it. Pinned for reproducibility.
- **`make -j1` is used on both the build and the install line**; libcap's
  Makefile re-invokes itself with `$(MAKE)`, and a single `-C libcap install`
  would rebuild nothing extra but splitting them keeps the log readable.
- **The `install` target runs `/sbin/ldconfig`** (`libcap/Makefile:200-201`)
  but only under `ifeq ($(FAKEROOT),)` and with a `-` prefix, and `SHARED=no`
  means that branch is not reached at all. No host command is executed.

## How to verify once built

- `lib/libcap.a`, `lib/libpsx.a`
- `include/sys/capability.h`, `include/sys/psx_syscall.h`
- `pkg-config --modversion libcap` → `2.78`; `pkg-config --modversion libpsx` → `2.78`
- `readelf -h lib/libcap.a` → `Machine: AArch64` on Android targets
- the install must be under `lib/`, not `lib64/` — if `lib64` appears, the
  `lib=lib` on the make line was dropped
- `nm lib/libcap.a` must show `cap_get_proc` and **no** `psx_load_syscalls`
  undefined reference problem (libcap defines a weak default,
  `cap_syscalls.c:15`)