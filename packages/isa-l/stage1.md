# ISA-L build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: **2.32.1** (v2.32.1, the latest `intel/isa-l` tag;
  v2.32.1 and v2.32.0 differ in ~50 files, so this is not a cosmetic bump)
- Directory name: `isa-l` (the tree ships no `config.h.in`, no `configure`
  and no `aclocal.m4` at all, so the config-template question is moot for
  the build system this recipe uses — see below)
- Build system actually used: **hand-written `Makefile.unx` + `make.inc`**

## The three build systems in this tarball, and why the recipe uses the makefile

| system | present? | what it would need |
|---|---|---|
| autotools | `configure.ac` (292 lines), `autogen.sh`, `Makefile.am` + 7 unit `Makefile.am` — but **no `configure`, no `aclocal.m4`, no `Makefile.in` anywhere** in the 536-entry tarball index | `autoreconf -fi` with the native autoconf/automake/libtool/m4, then `./configure`. Works in principle; `configure.ac:161-258` correctly skips the nasm hunt for non-x86 (`is_x86` is only set in the `x86_64`/`riscv64` arms of the `case` at `configure.ac:56`, and `:254-258` disables `USE_NASM` otherwise). More bootstrap, no benefit here. |
| `Makefile.unx` + `make.inc` | yes, both shipped | one make variable (`host_cpu`) — what the recipe uses |
| CMake | `CMakeLists.txt` (298 lines) + `cmake/*.cmake` | upstream calls it **"Experimental"** (`README.md:87`). `cmake/crc.cmake` and `cmake/igzip.cmake` select sources from `CMAKE_SYSTEM_PROCESSOR`, which our toolchain files do set correctly (`aarch64`/`x86_64`), so it would sidestep the uname problem entirely — but it is upstream's experimental path, it builds test/perf trees by default (`ISAL_BUILD_TESTS`/`ISAL_BUILD_PERF_TESTS` both default ON, `CMakeLists.txt:42,49`), and `cmake/raid.cmake:115` pulls `find_package(Threads REQUIRED)`. Not the boring choice. |

Because no generated `configure` exists, there is **no config template to
guard** — `AC_CONFIG_HEADERS` appears nowhere in `configure.ac`, and no
`config*.h.in`/`config*.hin` file exists in the tree. The autotools
timestamp guard does not apply to this recipe because the recipe does not run
`./configure`.

## Wall 1 — CONFIRMED, and the override is `host_cpu` alone

`make.inc:42-44`:

```
version ?= 2.32.1
host_cpu ?= $(shell uname -m | sed -e 's/amd/x86_/')
arch ?= $(shell uname | grep -v -e Linux -e BSD )
```

Both come from `uname`, so on an x86-64 build machine `host_cpu` is always
`x86_64` and `arch` is always empty (the `grep -v -e Linux` deletes the only
line `uname` prints on Linux). That is wrong for every cross build, and it
has three separate consequences. The recipe passes **`host_cpu="$HOST_ARCH"`
and nothing else**; `make -n` confirms that one variable is sufficient,
because `arch` follows from it:

- `make.inc:47-49` — `ifeq ($(host_cpu)_$(arch),aarch64_)` then `arch = aarch64`.
  So passing `host_cpu=aarch64` also sets `arch=aarch64` on this build host.
  Verified by dry run: the sources chosen are `crc/aarch64/*.S`,
  `igzip/aarch64/*.S`, `mem/aarch64/*.S`, not the `.asm` x86 files.
- `make.inc:80-83` — `ifeq ($(host_cpu),x86_64)` adds
  `CFLAGS_ += -fcf-protection=full`, `ASFLAGS_ += -DINTEL_CET_ENABLED` and
  `LDFLAGS += -Wl,-z,ibt -Wl,-z,shstk -Wl,-z,cet-report=error`. **Confirmed
  rejected by the target compiler**: `aarch64-linux-android24-clang
  -fcf-protection=full` gives
  `error: option 'cf-protection=return' cannot be specified on this target`.
  With `host_cpu=aarch64` the whole block is skipped — the dry-run command
  lines contain zero occurrences of `cf-protection`.
- `make.inc:111-113` — `ifeq ($(arch),aarch64)` sets `AS=$(CC)
  -D__ASSEMBLY__`, which is what the `.S` rule at `make.inc:222-224` uses.
  With `arch` correctly aarch64 this fires without being passed.

The brief's claim that aarch64 asm "fails to assemble under the NDK clang
integrated assembler" is **refuted for 2.32.1**. Probed directly against the
NDK compiler, all **38** aarch64 assembly sources (`crc/aarch64/*.S`,
`igzip/aarch64/*.S`) assemble cleanly with
`-D__ASSEMBLY__ -I include -I <unit-dir>`: 38 OK, 0 failures. The `-I` is
required — `crc/aarch64/crc_multibinary_arm.S:29` does
`#include <aarch64_multibinary.h>`, which lives at `include/`, and the
makefile's `VPATH` (Makefile.unx:56) is what puts `-I./…/include` on the
command line, as the dry run shows.

The `-D__ASSEMBLY__` define is **not** optional: re-running the same probe
without it fails 12 of 60 (all the multibinary dispatcher `.S` files). It
comes from `make.inc:112`, so it is present whenever `arch=aarch64`.

For `armv7a` the recipe's single override also suffices, and for a different
reason: `make.inc:129-131`
`ifeq ($(filter aarch64 x86_%,$(host_cpu)),) host_cpu=base_aliases` rewrites
`armv7a` to `base_aliases`, and the dry run then compiles only the portable
C sources with no assembly at all. ISA-L has no 32-bit ARM SIMD path and
does not pretend to.

## Wall 2 — REFUTED as stated: the probe is `-pthread`, and it works

`make.inc:181-188`:

```
# Check for pthreads
ifeq ($(arch),mingw)
have_threads ?= y
else
have_threads ?= $(shell printf "int main(void){return 0;}\n" | $(CC) -x c - -o /dev/null -pthread && echo y )
endif
THREAD_LD_$(have_threads) := -pthread
THREAD_CFLAGS_$(have_threads) := -DHAVE_THREADS
```

Three corrections to the brief's description, each checked against the file:

1. **It probes `-pthread`, not `-lpthread`.** The literal string `lpthread`
   does not occur anywhere in `make.inc`. `grep -rn lpthread` over the whole
   ISA-L tree returns only `raid/Makefile.am:61`
   (`raid_raid_funcs_perf_LDFLAGS = -lpthread`, a perf-test variable that
   the `lib` and `install` targets never reference) and
   `tools/test_fuzz.sh:121,124` (fuzz harness). Neither is on our link line.
2. **It writes `-pthread` whether or not the probe succeeded.** The claim
   that a failed probe "still leaves -lpthread on the link line" is true in
   shape — `THREAD_LD_$(have_threads) := -pthread` is unconditional — but
   the entry it defines is `THREAD_LD_y` when `have_threads=y`. If the probe
   failed, `have_threads` is empty and the variable is `THREAD_LD_`, while
   `make.inc:192` asks for `$(THREAD_LD_y)`, which is then **undefined and
   expands to nothing**. So a failed probe yields *no* thread flag, not a
   broken one. Either way, `-pthread` is a compiler flag, not a library name,
   so no sysroot lookup happens.
3. **The probe succeeds here.** It compiles and links a test program with
   `$CC` and **never runs it**, which makes it legal in a cross build — this
   is not an emulation problem. `aarch64-linux-android24-clang -x c - -o
   … -pthread` links cleanly (5504-byte output), and so does API 21. It also
   writes to `/dev/null`, which is upstream's line, not the recipe's.

`THREAD_LD_y` is consumed only at `make.inc:192`
(`$(bin_PROGRAMS): LDLIBS += $(THREAD_LD_y)`) and `:195`, i.e. by the `igzip`
CLI, never by the library archive. `make.inc:120-122` shows `lib` is just
`ar cr $(lib_name) $(objs)` with no link step at all.

## What the `install` target actually does

Dry-run (`make -n -f Makefile.unx host_cpu=aarch64 arch=aarch64
prefix=$OUT install`, 255 lines, exit 0) confirms the plan is legal:

- builds `bin/isa-l.a` via `ar cr`, using `$AR` from the environment (the
  makefile has no `AR =` of its own outside the `arch=mingw` arm at
  `make.inc:90`), so the system's `llvm-ar` is used — confirmed in the
  dry-run output
- builds `bin/libisal.so` via `$(CC) --shared $(LDFLAGS_so)`
  (`make.inc:328`, `make.inc:352-353`) — a shared library in `$OUT`, plus the
  `libisal.so.2` / `libisal.so` symlinks
- generates `isa-l.h` at the top of `$OUT/include` from `$(extern_hdrs)`
  (`make.inc:308-319`) and installs the eight unit headers under
  `$OUT/include/isa-l`
- installs `programs/igzip` and `programs/igzip.1`

Two build-host dependencies in `install` are both satisfied:

- `make.inc:338-339` runs `which libtool && libtool --mode=finish … ||
  echo …`. `libtool` is absent from the native prefix, so the `||` arm runs
  and the rule succeeds. Nothing fails.
- **No help2man.** `programs/Makefile.am:34` has a `-help2man` rule for
  `programs/igzip.1`, but that man page **ships pre-built** in the tarball
  (1959 bytes, `programs/igzip.1`, an entry in the tarball index) and
  `make.inc:342` only *installs* `$(dist_man_MANS)`. The dry-run contains
  **zero** `help2man` lines — the rule never fires, so no target binary is
  ever run. This matters: `make.inc:203-206` (`.run` rules) would run target
  binaries, but nothing in `lib`/`install` reaches them.

## API level notes

Zero occurrences of any level-gated symbol across ISA-L's `.c`, `.h` and
`.S` sources:

- `nl_langinfo` (26), `mktime_z` (35), `posix_spawn` (28),
  `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass`, `O_BINARY`: **no
  hits** anywhere in the tree.
- `posix_memalign` and `mmap` appear only in `*_perf.c`, `*_test.c` and
  `examples/*.c` — files reached by `make check`/`perfs`/`ex`, not by `lib`
  or `install`.

So the API level is not a variable for ISA-L on Android.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL BUILD** | `host_cpu=aarch64` (from `$HOST_ARCH`) makes `make.inc:47-49` set `arch=aarch64`, which skips the x86-only `-fcf-protection` block at `make.inc:80-83` (which the NDK clang rejects: `error: option 'cf-protection=return' cannot be specified on this target`) and enables `AS=$(CC) -D__ASSEMBLY__` at `make.inc:112`. All 38 aarch64 `.S` sources assemble under the NDK clang when given the makefile's own `-I` paths. The pthread probe at `make.inc:185` uses `-pthread`, links cleanly at API 21, and runs no binary. No level-gated symbol is used. |
| aarch64-android24 | **WILL BUILD** | As above. |
| aarch64-android35 | **WILL BUILD** | As above; nothing in the tree is gated at 26 or 35, so 35 differs from 21 in no way that matters here. |
| x86_64-android35 | **WILL NOT BUILD** | `host_cpu=x86_64` selects the x86 SIMD sources and `make.inc:52` sets `AS = nasm`, so every `.asm` file is assembled by nasm (`make.inc:222-224`, `nasm -f elf64 -DINTEL_CET_ENABLED …`, confirmed in the dry run). **nasm is not available**: `which nasm` fails, `/usr/bin/nasm` does not exist, there is no `packages/nasm`, and no nest prefix contains one. `-DINTEL_CET_ENABLED` and the `arch=mingw` case are moot — the assembler itself is missing. Upstream requires nasm ≥ 2.14.01 (`README.md:50`, `configure.ac:239`), and `arm=…`; the CMake path would not help either: `CMakeLists.txt:37-39` `enable_language(ASM_NASM)` under the same x86_64 condition. |
| x86_64-mingw | **WILL NOT BUILD** | Same missing nasm. Worse: `make.inc:77` `ifneq ($(arch),mingw)` guards the CET flags, but the `arch=mingw` arm at `make.inc:88-95` forces `CC=x86_64-w64-mingw32-gcc` and `AR=x86_64-w64-mingw32-ar` as plain make assignments (overridable from the command line, so not fatal) and still leaves `AS=nasm` from `make.inc:52` — the dry run shows `nasm -f win64 …`. Without nasm, no x86_64 target builds, Windows included. |
| clang-native | **WILL NOT BUILD** | Same missing nasm, and it is *not* a cross-build problem here: on an x86-64 host `uname -m` says `x86_64`, so `host_cpu` is right by accident, but `make.inc:52` still sets `AS = nasm` and every one of the ~50 `.asm` sources needs it. `nasm` is absent from this machine (`which nasm` → exit 1). |

The split is clean and it is entirely about nasm: **every aarch64 target
builds, every x86_64 target does not**, and the reason is one missing build
tool, not a platform limitation of the package.

## Risks / what a reviewer should check

- **`host_cpu="$HOST_ARCH"` is the whole override.** A reviewer should
  confirm the dry-run shape: no `cf-protection`, no `.asm`, `AS` used as
  `$CC -D__ASSEMBLY__`. If `make -n` shows `nasm` or `cf-protection`, the
  variable did not reach make.
- **`$HOST_ARCH` values in this repo**: `aarch64` (aarch64-androidNN),
  `armv7a` (armv7a-androidNN), `i686`, `x86_64`. The first two are handled
  (real aarch64 SIMD; portable base aliases for armv7a). The latter two hit
  the nasm wall, which is why those rows read WILL NOT BUILD.
- **A shared library lands in `$OUT/lib`** (`libisal.so.2.32.1` plus two
  symlinks). The rest of this prefix is static-first; ISA-L's `install` target
  has no switch to skip `slib` — `make.inc:328` lists `$(so_lib_name)` as an
  unconditional prerequisite — so this is what upstream's install does. A
  consumer wanting only `isa-l.a` links that; nothing forces the `.so`.
- **`libtool --mode=finish` will not run** (`make.inc:338`, no libtool in the
  native prefix). It is inside `which libtool && … || echo …`, so the rule
  succeeds and the shared library simply keeps its `libisal.so` name instead
  of gaining a `.dylib`-style fixup. Harmless.
- **`igzip` is installed as a target binary.** It is built, never run.
- **32-bit ARM gets a different library than 64-bit.** `host_cpu=armv7a`
  becomes `base_aliases`, so `isa-l.a` on armv7a holds the portable C
  dispatchers and no NEON assembly. Correct, but worth knowing before
  someone compares archive sizes across arches.

## How to verify once built

- `lib/libisal.a` and `include/isa-l.h` and `include/isa-l/*.h` (eight
  headers: `crc.h`, `crc64.h`, `erasure_code.h`, `gf_vect_mul.h`,
  `igzip_lib.h`, `isal_api.h`, `mem_routines.h`, `raid.h`)
- `bin/igzip`, `share/man/man1/igzip.1`
- `readelf -h`/`llvm-nm` on `lib/libisal.a`: archive members are
  `elf64-littleaarch64` on aarch64 targets, and the archive contains
  `crc32_ieee_norm_pmull.o`-class aarch64 objects — the proof that
  `host_cpu` reached make
- **No `.pc` file.** `libisal.pc.in` is used only by the autotools build
  (`configure.ac:291`); `Makefile.unx`'s `install` target does not install
  one. Consumers link `-lisal` with `-I$PREFIX/include`. Scoped check:
  `ls $PREFIX/lib/pkgconfig | grep -c '^libisal'` → expect 0.
