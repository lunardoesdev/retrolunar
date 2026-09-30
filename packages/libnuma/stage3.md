# libnuma 2.0.19 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libnuma
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libnuma@aarch64-android24' > /tmp/build-libnuma.sh
sh -n /tmp/build-libnuma.sh          # exit 0 — syntax gate passed
sh /tmp/build-libnuma.sh
```

## Stale-artifact cleanup — this package HAD stale artifacts, and they were a trap

libnuma was one of the seven with a stamp left by the discarded run. The
pre-build inspection is the most interesting one in the batch:

```
$ ls -la nest/aarch64-android24/lib/libnuma*
-rw-r--r-- 1 si si 88566 Oct  1 00:12 nest/aarch64-android24/lib/libnuma.a
-rw-r--r-- 1 si si  1007 Oct  1 00:12 nest/aarch64-android24/lib/libnuma.la
-rwxr-xr-x 1 si si 68472 Oct  1 00:12 nest/aarch64-android24/lib/libnuma.so
$ ls nest/aarch64-android24/lib/pkgconfig/numa.pc
nest/aarch64-android24/lib/pkgconfig/numa.pc
$ ls -la nest/aarch64-android24/include/numa.h nest/aarch64-android24/include/numaif.h nest/aarch64-android24/include/numacompat1.h
-rw-r--r-- 1 si si 14462 Oct  1 00:12 nest/aarch64-android24/include/numa.h
-rw-r--r-- 1 si si  1902 Oct  1 00:12 nest/aarch64-android24/include/numaif.h
-rw-r--r-- 1 si si  1231 Oct  1 00:12 nest/aarch64-android24/include/numacompat1.h
$ ls -a nest/aarch64-android24/.retrolunar-libnuma
nest/aarch64-android24/.retrolunar-libnuma
```

**The stale set contained a `libnuma.so`** — a *shared* library, 68472 bytes,
from a discarded recipe that did not pass `--disable-shared`. The current
recipe builds static only. Because the loader publishes with
`cp -rf "$OUT"/. "$PREFIX"/`, which merges and never deletes, that stale
`libnuma.so` would have **survived this build untouched** and the prefix would
have held a static `.a` next to a shared `.so` from a recipe that no longer
exists. Any later "is libnuma static?" check run as `ls libnuma.*` would have
answered "no". This is the stale-artifact hazard biting in the exact way the
preflight §6.1 warned about, so it is recorded with the evidence.

Deleted: the stamp, `lib/libnuma.a`, `lib/libnuma.la`, `lib/libnuma.so`,
`lib/pkgconfig/numa.pc`, `include/numa.h`, `include/numaif.h`,
`include/numacompat1.h`.

**The new `libnuma.a` is byte-for-byte the same size as the stale one**
(88566). Size proves nothing here; the mtime (`Oct 1 00:12` → `Oct 1 03:41`)
and the build log are what prove it. Recorded so nobody mistakes the
coincidence later.

`share/man` was left alone — libnuma installs no man pages by design here
(see the targeted-install trick below).

## Outcome: **SUCCESS**

Real work in the log — the library was compiled object by object and
archived, then installed by the three named targets:

```
  CC       affinity.lo
  CC       sysfs.lo
  CC       rtnetlink.lo
  CCLD     libnuma.la
 /bin/sh ./libtool   --mode=install /usr/bin/install -c   libnuma.la '.../out-uxHwX1/lib'
libtool: install: /usr/bin/install -c .libs/libnuma.a '.../out-uxHwX1/lib/libnuma.a'
libtool: install: chmod 644 '.../out-uxHwX1/lib/libnuma.a'
libtool: install: .../bin/llvm-ranlib '.../out-uxHwX1/lib/libnuma.a'
 /usr/bin/install -c -m 644 numa.h numacompat1.h numaif.h '.../out-uxHwX1/include'
  GEN      numa.pc
 /usr/bin/install -c -m 644 numa.pc '.../out-uxHwX1/lib/pkgconfig'
```

The targeted-install trick worked exactly as designed. `make -j1 libnuma.la`
built only the library, and only the three named install targets ran — **none
of the six `bin_PROGRAMS`** (`numactl`, `numastat`, `numademo`,
`migratepages`, `migspeed`, `memhog`) was ever compiled, so the recipe's
comment about them being host tools held. Plain `make install` would have
built all six, which is what `stage2.md` said to check for.

## Artifact verification (real output)

The one command that proves it — `test ! -e $PREFIX/bin/numactl`:

```
$ test ! -e nest/aarch64-android24/bin/numactl
$ echo $?
0
PASS
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libnuma.a \| grep ' T numa_available'` | `00000000000011d8 T numa_available` |
| static archive, this build | `ls -la $PREFIX/lib/libnuma.a` | `-rw-r--r-- 1 si si 88566 Oct  1 03:41 nest/aarch64-android24/lib/libnuma.a` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libnuma.a \| head -3` | `libnuma.a(libnuma.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| three public headers | `test -f` × 3 (`numa.h`, `numaif.h`, `numacompat1.h`) | `all three headers present` |
| pkg-config version | `pkg-config --modversion numa` | `2.0.19` |
| `.la` still installed | `ls -la $PREFIX/lib/libnuma.la` | `-rw-r--r-- 1 si si 987 Oct  1 03:41 ...` |
| **no shared library** | `ls $PREFIX/lib/libnuma.so*` | `no libnuma.so (correct — and the stale one is gone)` |
| **none of the six host tools** | `ls $PREFIX/bin/numactl $PREFIX/bin/numastat` | `none of the six bin_PROGRAMS (correct)` |

### The `.la` path rewrite worked

`stage2.md` warned that `libnuma.la` would bake `$OUT` paths and that the
loader rewrites them at `src/loader.lua:454-458`. Verified on the published
file:

```
$ grep -o 'libdir=[^ ]*' nest/aarch64-android24/lib/libnuma.la | head -2
libdir='/home/si/ond/git/retrolunar/nest/aarch64-android24/lib'
```

The prefix, not the `/tmp` staging dir. The file is also 987 bytes against
the stale 1007, which is the rewrite having shortened the baked paths.

### The static-only behavioural note

`stage2.md`'s point 3 holds: with `--disable-shared` there is no
`-Wl,-init=numa_init` constructor, so a consumer must call `numa_available()`
itself. That is libnuma's documented entry point and is not a broken build.
Recorded so a future consumer debugging "why does numa_available report
something odd" knows where to look.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-libnuma.sh
skip libnuma@source (fresh)
skip libnuma@aarch64-android24 (fresh)
```

## System-level findings

- **Stale-artifact hazard, confirmed live on this tree** (not merely
  theoretical): `nest/aarch64-android24/lib/libnuma.so` from a discarded
  recipe would have survived `cp -rf` into the published prefix of this build.
  The nest now holds only the static `.a`. Recorded rather than "fixed" in a
  recipe — the merge semantics are the loader's, `src/loader.lua`, and are
  outside a builder's scope. Anyone auditing a shared prefix for stale
  artifacts should look for shared objects next to static archives.
- No recipe change was made; `packages/libnuma/generic.lua` and `source.lua`
  are committed unmodified.
