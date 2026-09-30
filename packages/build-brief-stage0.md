# BUILD BRIEF — stage 0 preflight, fifteen packages, system `aarch64-android24`

Written by the preflight reviewer, before anything is compiled. Nothing here was
built. What *was* done: every `source.lua`, `generic.lua`, `stage1.md` and
`stage2.md` of the fifteen packages was read; two throwaway probes were compiled
under `/tmp` with the real NDK clang; and `./builddir/retrolunar install` was
run with `--nest ./nest` to *emit* scripts (emission only — nothing executed) so
the freshness logic below is read off real generated output, not off theory.

Three of the brief's stated premises are wrong. They are corrected in §6 and the
corrections change what the builder should do. Read §6 before building.

---

## 1. PER-PACKAGE BUILD ORDER

### Native prerequisites — what must already exist in `nest/clang-native`

The loader emits, for **every** package block, `NATIVE_PREFIX="$NESTDIR/clang-native"`
and prepends `$NATIVE_PREFIX/bin` to `PATH` (`src/loader.lua:412-415`). A
`require("tool@native")` therefore means "build `tool` into
`nest/clang-native/` first, and the block will find it on `PATH`".

Actual state of `nest/clang-native/bin` right now — this is the important table:

| tool | in `nest/clang-native/bin`? | needed by |
| --- | --- | --- |
| `gperf` | **YES** | libseccomp (hard, configure-time); bison (build-time) |
| `flex` | **NO** | libnl-3 (hard, configure-time) |
| `bison` | **NO** | libnl-3 (hard, configure-time) |
| `m4` | **NO** | flex (transitively, for libnl-3) |
| `yacc`/`lex` | NO | not required; `configure.ac` wants `bison -y`, which bison provides |

So **libnl-3 is the only package with unmet native prerequisites, and it needs
four of them built, not two.** The emitted queue proves it — `retrolunar install
--nest ./nest --packages ./packages 'libnl-3@aarch64-android24'` emits ten
blocks in exactly this order:

```
m4@source → m4@clang-native → flex@source → flex@clang-native →
gperf@source → gperf@clang-native → bison@source → bison@clang-native →
libnl-3@source → libnl-3@aarch64-android24
```

`m4` is there because `packages/flex/generic.lua:1` is `require("m4")` — a
*bare* require, which inside a package recipe inherits the requiring module's
system, i.e. it resolves to `m4@clang-native`, not `m4@aarch64-android24`.
`gperf` is there because `packages/bison/generic.lua:1` is
`require("gperf@native")`.

`gperf@clang-native` is already stamped (`.retrolunar-gperf` present) and its
binary exists, so that block will print `skip gperf@clang-native (fresh)` —
correctly, and it is not the builder's problem. `m4`, `flex` and `bison` have no
`nest/clang-native` stamp and no binary: **they will actually build.** That is
correct behaviour, but it means the libnl-3 build is really a five-package build
(`m4`, `flex`, `bison`, `gperf`, `libnl-3`) and will take correspondingly longer.

Note `packages/bison/generic.lua:7` passes bare `./configure $AUTOCONF_CONFIGURE_FLAGS`
— no `--enable-static --disable-shared`. On `clang-native` that is right (a host
tool must be dynamically linked to run), so bison lands as a runnable host binary
in the native prefix. Do not "fix" it.

### Build order

**Tier 0 — must build first, native (`clang-native`):**

1. `m4` — prerequisite of `flex`
2. `flex` — prerequisite of `libnl-3`
3. `gperf` — already present, will skip
4. `bison` — prerequisite of `libnl-3`

**Tier 1 — self-contained, any order, `aarch64-android24`:**

5. `libconfig` 6. `libcbor` 7. `zopfli` 8. `nanopb` 9. `rapidjson` 10. `glm`
11. `stb` 12. `meshoptimizer` 13. `oniguruma` 14. `libnuma` 15. `libunwind`
16. `abseil-cpp` 17. `glog` 18. `libseccomp`

**Tier 2 — needs Tier 0:**

19. `libnl-3`

Nothing in Tier 1 depends on anything else in this list. All fifteen are
independent of each other; `libnl-3` is the only one with dependencies at all.
`abseil-cpp` and `glog` are also independent of each other — neither is a
dependency of the other, despite both touching `__android_log_write`.

### If a build fails at configure with a missing tool

Check these, in this order, before reading the log further:

```sh
# 1. Is the tool actually in the native prefix?
ls nest/clang-native/bin/{gperf,flex,bison,m4}

# 2. Does the native block for it exist and pass?
ls -a nest/clang-native/ | grep retrolunar   # .retrolunar-<tool>
ls -a nest/source/     | grep retrolunar     # .retrolunar-<tool>

# 3. Does the tool run on this build host? (an aarch64 binary will not)
file nest/clang-native/bin/<tool>
nest/clang-native/bin/<tool> --version
```

Point 3 is the one that bites. `nest/aarch64-android24/bin/bison` **exists** —
a *cross-compiled* bison, an aarch64 Android binary that cannot run on this
x86_64 build host. It is not on `PATH` for the block (`$NATIVE_PREFIX/bin` is
`nest/clang-native/bin`), so it will not be found, and `bison@clang-native`
will build a fresh runnable one. Do not "fix" this by copying the
`aarch64-android24` binary across; it will not execute.

The two configure-time hard failures to recognise by sight:

- `configure.ac:156-163` in libnl-3 `AC_MSG_ERROR`s if `YACC` or `FLEX` is
  empty → means `flex@clang-native` / `bison@clang-native` did not land.
- libseccomp's `configure.ac:126-129` is `AC_CHECK_TOOL(GPERF, gperf)` +
  `AC_MSG_ERROR([please install gperf])` → means `gperf@clang-native` is
  missing. It is not, so this should not fire.

A third, *benign*, one: libnl-3's `configure.ac:85`
`PKG_CHECK_MODULES([CHECK], [check >= 0.9.0])` prints
`*** Disabling building of unit tests`. **That is a warning, not an error.**
`PKG_CONFIG_PATH` is empty and `PKG_CONFIG_LIBDIR` points at our prefix, so
`has_check=no` is the designed outcome. Do not go looking for a `check` package.

---

## 2. THE STALE-STAMP TRAP — operational procedure

### How the trap actually works

Per package, the emitted block is (`src/loader.lua:342-368`):

```sh
if [ -f $NESTDIR/<sys>/.retrolunar-<name> ] && [ <stamp> -nt <recipe> ] \
   && [ <stamp> -nt <system generic.lua> ] && [ <stamp> -nt <system dir> ]; then
  echo "skip <name>@<sys> (fresh)"
else
  ... real work ...
  touch <stamp>
fi
```

It is `touch`ed **only on success**, after `cmake --install` / `make install`
has populated `$OUT`. So the stamp means "this exact recipe produced this exact
prefix", and a stamp older than any of the three references forces a rebuild.

The trap: **`nest/aarch64-android24/` already holds a stamp for seven of the
fifteen**, left by an earlier run whose recipes were later discarded. If any of
the three references is *older* than that stamp, the block prints
`skip <name> (fresh)` and the new recipe never runs — and the artifacts already
sitting in `nest/aarch64-android24/lib/` are from the discarded recipes, not
from these. `abseil-cpp` and `glog` are the two named in the brief, and they are
the two with the most pre-existing artifacts (94 `libabsl_*.a` and
`libglog.a` respectively).

**Correction — see §6.1: right now, on this tree, none of the fifteen actually
prints `skip (fresh)`.** Every one of the seven existing stamps is older than its
own recipe, so all seven rebuild. The procedure below is still the right
procedure, but the builder should run the diagnosis rather than assume the trap
has already fired.

### Procedure — exact commands

Run this **before each build**, not once for the batch:

```sh
cd /home/si/ond/git/retrolunar

NAME=abseil-cpp          # substitute per package
SYS=aarch64-android24

# 1. Drop the stamp. This is unconditional and is the step that matters.
rm -f "nest/$SYS/.retrolunar-$NAME"
```

Delete `nest/source/<name>/` as well **when the source recipe's version, URL or
layout changed** — i.e. when `packages/<name>/source.lua` is not byte-identical
to what produced the tree currently in `nest/source/<name>/`. The source block
is separately stamped at `nest/source/.retrolunar-<name>`, and the tree is a
*copy*, not a symlink, so a stale stamp means the old tree gets `cp -r`'d into
`$WORK` and built:

```sh
rm -f nest/source/.retrolunar-$NAME
rm -rf "nest/source/$NAME"
```

For this batch, all fifteen `source.lua` files were compared against their
`stage1.md` forecasts and **every version and URL matches** — so no
source-tree deletion is required *for a version/URL reason*. Do it anyway for
`abseil-cpp` and `glog`: their `nest/source/` trees are from the discarded run,
and the two directories predate the current recipes.

```sh
# 2. Emit the script and confirm the block has no "skip" path.
./builddir/retrolunar install --nest ./nest --packages ./packages \
    "$NAME@$SYS" > build.sh
sh -n build.sh || exit 1

grep -n "^# --- $NAME@$SYS ---" -A2 build.sh | grep -q 'skip' \
    && echo "STILL SKIPPING — investigate" || echo "will really build"
```

```sh
# 3. Build it, capturing the real log to stage3.md.
ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0 \
    sh build.sh 2>&1 | tee /tmp/$NAME.log
```

`ANDROID_HOME` is mandatory: the system recipe's first act is
`: "${ANDROID_HOME:?set ANDROID_HOME to an Android SDK with an NDK}"`
(`packages/aarch64-android24/generic.lua:11`), and it picks the newest NDK by
`sort -V` (currently `28.2.13676358`). Unset, every block dies on line 1.

### What counts as a build

**A build counts as a build only if the log shows real work.** Concretely, the
log must contain evidence of compilation for that package — `Building C object`,
a `cc`/`clang` line, or an `ar`/`libtool` archiving step. The following are all
*not* builds and must never be recorded as one:

- `skip <name>@<sys> (fresh)` — the stamp was honoured; nothing ran.
- a log that only shows the `source` block (`curl`, `tar`, `cp`) and then the
  build block emitting nothing before `touch`.
- an exit 0 with no compile lines — `set -eu` plus `touch` will still stamp.

Cross-check the artifacts independently in §4. That is the real proof; the log
is only the record of it.

---

## 3. PREDICTED FAILURE POINTS, ranked

Ranked by likelihood × blast radius. Each package gets exactly one line unless
it genuinely has more.

### Rank 1 — `libnl-3`: four native tools must build first, and `m4` is the one nobody expects

`packages/flex/generic.lua:1` is `require("m4")` — **bare**, not `@native`, so it
resolves to `m4@clang-native`, which does not exist yet. The brief says
"libnl-3 requires flex@native and bison@native (bison transitively pulls
gperf@native)" — true but incomplete: `m4` is a fourth prerequisite, three levels
up. `nest/aarch64-android24/bin/bison` exists and looks like the tool is
already there; it is a cross-compiled aarch64 binary that cannot run on this
x86_64 host and is not on the block's `PATH`. If this build fails, look at the
`m4@clang-native` / `flex@clang-native` / `bison@clang-native` blocks first, not
at libnl-3's configure output.

### Rank 2 — `libunwind`: the `.S` file the reviews name is NOT the one that breaks, and the one that breaks is NOT in the Android build

See §6.2 — this is a correction, and it moves the risk off the list. The
predicted `src/aarch64/getcontext.S` assemble failure **does not happen**;
verified by probe. The file that genuinely fails to assemble is
`src/aarch64/setcontext.S`, and it is referenced only from the `OS_FREEBSD` block
(`src/Makefile.am:375`), which does not fire on Android. Residual real risk,
lower than advertised: `configure.ac:459-475`'s `AC_CHECK_LIB([z], [uncompress])`
probe **will succeed** on Android (the NDK ships `libz.so` and `zlib.h`), so
`LIBZ=-lz` lands in `libunwind_la_LIBADD` and a `-lz` will appear in
`libunwind.la`. Inert for a static archive, but expect it and do not "fix" it.

### Rank 3 — `glog` / `abseil-cpp`: `__android_log_write` — see §6.3, this is a **consumer** blocker, not a build blocker

Both build cleanly. `libglog.a` and `libabsl_log_internal_log_sink_set.a` will
each carry one `U __android_log_write`; verified by probe against the artifacts
already in the nest. Neither recipe reaches a link step. **Do not record a build
failure here.** Record the missing `-llog` as a system defect affecting
downstream consumers.

### The remaining thirteen, one line each

- **`abseil-cpp`** — if `ABSL_BUILD_TESTING=OFF` (`generic.lua:20`) fails to take, `CMakeLists.txt:136` falls through to `include(CMake/Googletest/DownloadGTest.cmake)`, which **network-fetches GoogleTest and builds it with a host compiler in the middle of a cross build**; symptom is a hang or a host-arch artifact in `$OUT`, not an error.
- **`glog`** — `WITH_GFLAGS=OFF` matters because there is **no `gflags` package** in `packages/`; leave it ON and `find_package(gflags 2.2.2)` (`CMakeLists.txt:77`) can find a *host* gflags on some systems. Already correct; flagged so nobody re-enables it.
- **`libconfig`** — the C++ binding stays ON (`generic.lua:9-10` says so deliberately): `BUILD_CXX` produces a second archive `libconfig++` with its own `.pc`, so an expectation of exactly one `.a` is the failure mode, not the build.
- **`libcbor`** — `-DCMAKE_C_STANDARD=99` (`generic.lua:19`) is load-bearing: without it upstream's C23 "nodiscard" probe succeeds on NDK clang and flips the *whole* build to `-std=c23`, which upstream's own comment calls a mode that "may fail".
- **`zopfli`** — builds `bin/zopfli` and `bin/zopflipng` as **target executables** (`CMakeLists.txt:136`/`:145`, unconditional, no upstream switch); their presence is expected and **executing them is forbidden** — no QEMU, no emulator.
- **`meshoptimizer`** — `-DMESHOPT_INSTALL=ON` is required because upstream defaults installation **off**; without it the build "succeeds" and installs nothing.
- **`nanopb`** — `CMakeLists.txt:19-23` `FATAL_ERROR`s on a missing protoc *above* the `if(nanopb_BUILD_GENERATOR)` check; it survives only because the release tarball ships `generator/protoc` mode 0755 and cmake resolves the relative `PATHS` entry. Confirmed present. Re-check this first on any version bump.
- **`rapidjson`** — safe only because `RAPIDJSON_BUILD_EXAMPLES=OFF` (`generic.lua:20`) stays: `example/CMakeLists.txt:22-37` has fifteen unconditional `add_executable`s with `-Werror -Weverything`, and the top level appends `-march=native` (`CMakeLists.txt:53`/`:76`), which every NDK wrapper except x86_64/i686 rejects outright.
- **`glm`** — `CMakeLists.txt:271` installs two `INTERFACE` targets with no destination; if the install step fails, the documented fallback is dropping `-DGLM_BUILD_LIBRARY=OFF` and accepting a one-file `libglm.a`.
- **`stb`** — nothing to fail: no build system upstream at all, the body is `mkdir -p` plus one `cp` (`generic.lua:14-15`). `cp` can only fail if a name is wrong; the 19 `stb*.h`, `stb_vorbis.c` and `LICENSE` all exist (verified).
- **`oniguruma`** — `make install` walks into `test/` and `sample/` (`Makefile.am:5`); that is three extra `make` invocations and **is not a failure**. `bin/onig-config` is produced by `config.status`'s `chmod`, so if it is missing the cause is that, not the recipe.
- **`libseccomp`** — the `arch-gperf-generate` rule **will** fire deterministically (`src/syscalls.perf.template` sorts after `syscalls.perf`, so it is strictly newer); if the build dies there the missing piece is a host tool (`bash`, `sed`, `nl`, `mktemp`) or gperf, not a flag.
- **`libnuma`** — the install trick must not produce `bin/numactl`: `make -j1 libnuma.la` then three named `install-*` targets (`generic.lua:17-18`). Plain `make install` would build all six `bin_PROGRAMS`. Check `test ! -e $PREFIX/bin/numactl`.

---

## 4. WHAT A PASS LOOKS LIKE, PER PACKAGE

Consolidated from each `stage2.md`'s "Carried to the build" table. `$PREFIX` is
`nest/aarch64-android24`. **One command per package is the proof**; the rest are
corroboration.

| package | the one command that proves it | also expect |
| --- | --- | --- |
| `libconfig` | `ls $PREFIX/lib/libconfig.a` | `include/libconfig.h++`; `lib/pkgconfig/libconfig.pc`; no `.so` |
| `libcbor` | `ls $PREFIX/lib/libcbor.a` | `include/cbor.h`; `lib/pkgconfig/cbor.pc`; no `.so` |
| `zopfli` | `[ -x $PREFIX/bin/zopfli ]` | `lib/libzopfli.a`, `lib/libzopflipng.a`; `include/zopfli.h`, `zopflipng_lib.h`; `lib/cmake/Zopfli/ZopfliConfig.cmake`. **No `.pc` and none is correct.** `bin/zopfli`+`bin/zopflipng` are target binaries, never run. |
| `nanopb` | `llvm-objdump -f $PREFIX/lib/libprotobuf-nanopb.a \| head -3` → `elf64-littleaarch64` | headers land in **`include/nanopb/`**, not `include/`; `lib/cmake/nanopb/nanopb-config.cmake`. **No `.pc`, none is correct.** No `bin/`. |
| `rapidjson` | `[ -f $PREFIX/include/rapidjson/document.h ]` | `lib/pkgconfig/RapidJSON.pc` (capitalised, → `1.1.0`); `lib/cmake/RapidJSON/RapidJSONConfig.cmake`; `share/doc/RapidJSON/readme.md`. **No library and no `lib/*.a` — correct**, rapidjson is header-only. `share/doc/RapidJSON/examples/**` is present and unavoidable. |
| `glm` | `[ -f $PREFIX/include/glm/glm.hpp ]` | `share/glm/glmConfig.cmake` — note **`share/glm`, not `lib/cmake/glm`**. **No `libglm.a` and no `.pc` — both correct.** Nothing is compiled, so there is no architecture to check. |
| `stb` | `[ "$(ls $PREFIX/include/stb*.h \| wc -l)" -eq 19 ]` | `[ -f $PREFIX/include/stb_vorbis.c ]`, `[ -f $PREFIX/include/LICENSE ]`; total `include/` entry count 21. No library, no `bin/`, no `.pc`, no CMake config — all four correct. |
| `meshoptimizer` | `test ! -e $PREFIX/bin/gltfpack` | `ls $PREFIX/lib/libmeshoptimizer.*`; `include/meshoptimizer.h`; `lib/pkgconfig/meshoptimizer.pc` |
| `oniguruma` | `llvm-nm --defined-only $PREFIX/lib/libonig.a \| grep ' T onig_init'` | `include/oniguruma.h`, `oniggnu.h`; `lib/pkgconfig/oniguruma.pc` → `6.9.10`; `test -x $PREFIX/bin/onig-config`; **no** `$PREFIX/share/man` |
| `libnuma` | `test ! -e $PREFIX/bin/numactl` | `llvm-nm --defined-only $PREFIX/lib/libnuma.a \| grep ' T numa_available'`; `include/{numa.h,numaif.h,numacompat1.h}`; `lib/pkgconfig/numa.pc` → `2.0.19`; `libnuma.la` present; **no** `share/man`. The `test !` is what proves the targeted-install trick worked. |
| `libunwind` | `llvm-nm --defined-only $PREFIX/lib/libunwind.a \| grep ' T unw_backtrace'` | `libunwind-aarch64.a` (+ coredump/ptrace/setjmp); `test -L $PREFIX/lib/libunwind-generic.a` — a **symlink**, use `test -L` not `test -f`; `libunwind.pc` → `1.8.3`; `include/{libunwind.h,unwind.h,libunwind-dynamic.h}`; **no** man pages, **no** `bin/` |
| `abseil-cpp` | `llvm-nm $PREFIX/lib/libabsl_log_internal_log_sink_set.a \| grep __android_log_write` → prints exactly one `U` | one `libabsl_<module>.a` per module — **record the real `ls lib/libabsl_*.a \| wc -l`**, do not reuse the "94" figure, see §6.4; `include/absl/base/options.h` is the *generated* one, its presence proves the ABI configure step ran; `absl_base.pc` → `20260817`; `lib/cmake/absl/abslConfig.cmake`. **No aggregate `absl.pc`** — `pkg-config --modversion absl` failing is correct. **No `bin/` and no `*_test` binaries.** |
| `glog` | `llvm-objdump -f $PREFIX/lib/libglog.a \| head -3` → `elf64-littleaarch64` | `include/glog/{logging.h,export.h}` (`export.h` is generated — its presence proves `generate_export_header` ran); `lib/pkgconfig/libglog.pc` → `0.7.1`; `lib/cmake/glog/glog-config.cmake`. **No `bin/`** — any `*_unittest` there means `BUILD_TESTING=OFF` did not take. |
| `libseccomp` | `llvm-nm --defined-only $PREFIX/lib/libseccomp.a \| grep ' T seccomp_init'` | `include/{seccomp.h,seccomp-syscalls.h}`; `lib/pkgconfig/libseccomp.pc` → `2.6.1`; `ls $PREFIX/share/man/man3 \| wc -l` → `35` |
| `libnl-3` | `test ! -e $PREFIX/bin` | `ls $PREFIX/lib/libnl-*-3.a \| wc -l` → `6`; `llvm-nm --undefined-only $PREFIX/lib/libnl-*-3.a \| grep -c dlopen` → `0`; `include/libnl3/netlink/route/link.h`; `pkg-config --modversion libnl-3.0` → `3.12.0`, `ls $PREFIX/lib/pkgconfig \| wc -l` → `6`; `share/man/man8` → `6` pages; `find $PREFIX -name pktloc`. **`libnl-cli-3.a` must be absent** and there must be no `libnl-cli-3.0.pc` — both prove `--enable-cli=no` took. |

### Contradictions between packages' expectations

None found. Two near-misses worth naming, both of which are *correct as
written* and only look contradictory:

1. **`share/` vs `lib/` for CMake package configs.** glm installs to
   `share/glm/`; nanopb, glog, abseil, rapidjson and zopfli install to
   `lib/cmake/<pkg>/`. Different packages, different upstream layouts — not a
   conflict, but a builder grepping for one pattern will miss glm.
2. **"No library file" is correct for glm, stb and rapidjson.** Three packages
   legitimately produce no `.a`. A generic "every package produced an archive"
   check will report three false failures.

One genuine caveat, inherited from `stage2.md` and not resolvable by the builder:
`$PREFIX/lib/libunwind-generic.a` is a symlink created by `install-exec-hook`
into `$OUT/lib`. The loader's publish step is `cp -rf "$OUT"/. "$PREFIX"/`,
which follows symlinks rather than recreating them. **If the published
`libunwind-generic.a` is a regular file containing a copy rather than a symlink,
that is the cause** — record it, do not treat the build as failed.

---

## 5. THE VERIFICATION EACH BUILD MUST END WITH

Every single build ends with the same two steps. Skipping them is how a
no-op gets recorded as a build.

**Step 1 — rerun the identical emitted script and confirm `skip`:**

```sh
ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0 sh build.sh
```

The expected output is exactly one line per already-built package, e.g.:

```
skip abseil-cpp@aarch64-android24 (fresh)
skip abseil-cpp@source (fresh)
```

This is **the only proof that the new stamp is real.** The stamp is written by
`touch` after `cp -rf "$OUT"/. "$NESTDIR/<sys>/"`, so a `skip` on the rerun
proves the install succeeded *and* the stamp is newer than the recipe. A build
that succeeded but whose rerun does not print `skip` has a broken freshness
chain — check the recipe's mtime against the stamp.

**Step 2 — verify the artifact independently**, using the one command from §4.
The `skip` proves the recipe ran; only the artifact check proves it produced the
right thing.

Both steps, per package, before writing `stage3.md`. `stage3.md` should record
the real compile output, the artifact command and its real output, and the
rerun's `skip` line. If a package's build failed, `stage3.md` records the failure
and the next package proceeds — the stamps are per-package, so one failure does
not block the others.

---

## 6. PREDICTIONS I THINK ARE WRONG

Four. Two change what the builder should do; two change what should be recorded.

### 6.1 "Without deletion the emitted script prints `skip <name> (fresh)`" — NOT TRUE on this tree right now

Every one of the fifteen **will build**. I evaluated the actual `test(1)`
`-nt` conditions for all of them:

```
abseil-cpp   REBUILDS  (stamp older than source.lua AND generic.lua)
glog         REBUILDS  (same)
nanopb       REBUILDS  (same)
glm          REBUILDS  (same)
oniguruma    REBUILDS  (same)
libseccomp   REBUILDS  (same)
libnuma      REBUILDS  (same)
libunwind libnl-3 libconfig libcbor zopfli rapidjson stb meshoptimizer
             NO STAMP -> builds
```

The seven stamps are all from `Sep 30 23:36`-ish; every recipe file was written
after that (`Oct 1 00:59`–`02:48`), and freshness requires the stamp to be
newer than **all three** references. So the `-nt` test already fails and the
blocks already rebuild.

This matters operationally: **the builder must not skip the `rm -f` step and
assume it is harmless-but-unnecessary.** It is harmless *today*; the trap is
armed the moment anyone touches a recipe file. Run §2's procedure anyway. But
the builder should not go looking for a *current* skip-failure to explain, and
should not record "the stale stamp nearly bit us" in `stage3.md` — it did not.

The **real** danger is different and is not in the brief: `nest/aarch64-android24/`
already contains 94 `libabsl_*.a`, `libglog.a`, `libonig.a`, `libnuma.a`,
`libseccomp.a` and `libprotobuf-nanopb.a` from the **discarded** recipes. Those
are from an earlier run, not from these. `cp -rf "$OUT"/. "$PREFIX"/` **merges**
and never deletes, so a stale artifact from the discarded run survives a
successful rebuild of the same name. §4's artifact checks are the only defence,
and for the `-llog` check (§6.3) they are reading a file that may be the old
one. **Check artifact mtimes are from this build.**

### 6.2 "libunwind's `src/aarch64/getcontext.S` was the one genuinely unresolved item — an assemble error naming a `.S` file" — the named file assembles cleanly; the file that fails is not in the build

I compiled all four aarch64 `.S` files with the real NDK clang. `getcontext.S`
— the file the brief names — **assembles with no diagnostics.** So does
`longjmp.S` and `siglongjmp.S`.

The file that genuinely fails is `src/aarch64/setcontext.S`:

```
src/aarch64/setcontext.S:48:19: error: invalid operand for instruction
 ldp q8, q9, [x9, #(0xb0 + SC_FPSIMD_OFF + 8 * 16)]
```

and it fails for a real reason, visible at `src/aarch64/ucontext_i.h`: the
`SC_FPSIMD_OFF` macro is defined **only** in the `__FreeBSD__ || __APPLE__`
branch (`ucontext_i.h:26-38`). The `__linux__` branch (`ucontext_i.h:40-57`)
does not define it, so on Android the operand is an unexpanded identifier. That
is an upstream FreeBSD bug in a FreeBSD-only file — and it is **not in the
Android build**: `aarch64/setcontext.S` is referenced only from the `OS_FREEBSD`
block at `src/Makefile.am:375`. The `OS_LINUX` block (`src/Makefile.am:351-365`)
supplies `aarch64/Gos-linux.c` and `aarch64/Los-linux.c`, no `.S`. The only
`.S` files that do enter are `getcontext.S` (`Makefile.am:420`, unconditional
under `ARCH_AARCH64`), `longjmp.S` and `siglongjmp.S` (`:439-440`), all of which
assemble.

**Consequence:** libunwind's aarch64 risk is materially *lower* than
`stage2.md` says. `stage2.md`'s item 1 under "Where the builder is most likely
to be wrong" can be struck. The builder should not go looking for a `.S` error.
(I flag one caveat in the interest of honesty: my probe assembled the files
standalone with the arch include path, which is not a substitute for the real
build. It settles the question the brief asked — *does this file assemble* — and
the answer is yes. It does not prove the rest of the configure.)

### 6.3 "`-llog` is needed for THIS package's own build" — NO. It is needed only downstream. Do not record a build blocker.

The brief asks for this worked out from the recipes, and the answer is
unambiguous. **`-llog` is not needed to build abseil-cpp or glog.** Both
produce static archives, and a static archive is not linked.

Worked out from the recipes, not asserted:

- `packages/abseil-cpp/generic.lua:20-22` — `-DBUILD_SHARED_LIBS=OFF`,
  `-DABSL_BUILD_TESTING=OFF`, then `cmake --build` + `cmake --install`. With
  `BUILD_SHARED_LIBS=OFF` every target is `add_library(... STATIC "")`
  (`CMake/AbseilHelpers.cmake:233`) and with testing off `absl_cc_test` returns
  before its `add_executable` (`AbseilHelpers.cmake:402-404`). There is no
  `add_executable` and no shared library in the whole build.
- `packages/glog/generic.lua:34-36` — `-DBUILD_SHARED_LIBS=OFF`,
  `-DBUILD_TESTING=OFF`. `WITH_FUZZING` defaults to `none`
  (`CMakeLists.txt:48`), so `fuzz_demangle` (`:530-533`) is not built;
  `BUILD_TESTING` gates the ten test executables from `:546` to `:961`, and it
  is off.

So neither recipe ever reaches a link step, and `__android_log_write` stays
unresolved in both archives. Upstream's own `-llog`
(`absl/log/CMakeLists.txt:237`, `$<$<BOOL:${ANDROID}>:-llog>`) is dead anyway —
`ANDROID` is unset because the toolchain files deliberately keep
`CMAKE_SYSTEM_NAME Linux` (`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`) —
and for a static archive `LINKOPTS` would contribute nothing regardless.

Probe confirmation, against the artifacts already in the nest:

```
$ llvm-nm --undefined-only nest/aarch64-android24/lib/libglog.a | grep -c android_log_write
1
$ llvm-nm --undefined-only nest/aarch64-android24/lib/libabsl_log_internal_log_sink_set.a | grep android_log_write
                 U __android_log_write
```

And the probe that settles the downstream question: a translation unit calling
`__android_log_write`, linked with the Android systems' actual LDFLAGS
(`-L$PREFIX/lib -Wl,-rpath-link,... -lm`) and no `-llog`, gives
`ld.lld: error: undefined symbol: __android_log_write`. Adding `-llog` clears it.

**What the builder should do:** **proceed.** Build both. Record in `stage3.md`
that the archives carry one `U __android_log_write` each (that is the evidence
the sink is compiled in), and record the missing `-llog` as a **system-level
consumer-link defect affecting all 56 Android systems**, not as a build failure
of these two packages. The fix belongs in the `LDFLAGS` section of
`packages/*android*/generic.lua` next to the `-lm` line
(`packages/aarch64-android24/generic.lua:79`) — which is outside this build's
scope, and outside what a builder may edit. Do not work around it in a recipe.

### 6.4 abseil's archive count — "94" is the number the discarded run left in the nest, not a prediction

`stage2.md` says 94 "must not be carried forward as fact" and estimates ~180
from parsing CMake sources. The nest currently holds **exactly 94**
`libabsl_*.a`. That is strong evidence the 94 in `topackage.md:163` was a real
count of an earlier run — and just as strong evidence that it is *not* a count
of the current recipe. **Record the real count from this build**; do not copy 94
forward, and do not expect 180 either.

---

## Summary for the builder

- **Order:** `m4`, `flex`, `gperf` (skips), `bison` — all `@clang-native` — then
  thirteen self-contained `@aarch64-android24` packages in any order, then
  `libnl-3`.
- **Before each build:** `rm -f nest/aarch64-android24/.retrolunar-<name>`; also
  `rm -rf nest/source/<name>` for `abseil-cpp` and `glog`.
- **Every build:** confirm the log shows real compilation, run §4's one command,
  then rerun and confirm `skip <name>@aarch64-android24 (fresh)`.
- **Top three risks:** (1) `libnl-3`'s four unmet native prerequisites, starting
  with the bare `require("m4")` in `packages/flex/generic.lua:1`;
  (2) `abseil-cpp` pulling a host-compiled GoogleTest if
  `ABSL_BUILD_TESTING=OFF` fails to take (`CMakeLists.txt:136`);
  (3) stale artifacts from the discarded run surviving `cp -rf` in
  `nest/aarch64-android24/lib/` and being mistaken for this build's output.
- **Do not spend time on:** the `__android_log_write`/`-llog` question as a build
  blocker (it is a downstream consumer issue — §6.3), or the libunwind `.S`
  assembly (it assembles — §6.2).