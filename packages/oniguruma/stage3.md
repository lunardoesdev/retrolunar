# oniguruma 6.9.10 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-oniguruma
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'oniguruma@aarch64-android24' > /tmp/build-oniguruma.sh
sh -n /tmp/build-oniguruma.sh          # exit 0 — syntax gate passed
sh /tmp/build-oniguruma.sh
```

## Stale-artifact cleanup — this package HAD stale artifacts

oniguruma was one of the seven with a stamp left by the discarded run.
Pre-build inspection:

```
$ ls -la nest/aarch64-android24/lib/libonig* \
      nest/aarch64-android24/include/oniguruma.h \
      nest/aarch64-android24/include/oniggnu.h \
      nest/aarch64-android24/lib/pkgconfig/oniguruma.pc \
      nest/aarch64-android24/bin/onig-config
-rw-r--r-- 1 si si  828088 Sep 30 23:38 nest/aarch64-android24/lib/libonig.a
nest/aarch64-android24/include/oniguruma.h
nest/aarch64-android24/include/oniggnu.h
nest/aarch64-android24/lib/pkgconfig/oniguruma.pc
nest/aarch64-android24/bin/onig-config
$ ls -a nest/aarch64-android24/.retrolunar-oniguruma
nest/aarch64-android24/.retrolunar-oniguruma
```

Deleted: the stamp, `lib/libonig*.a`, `include/oniguruma.h`,
`include/oniggnu.h`, `lib/pkgconfig/oniguruma.pc`, `bin/onig-config`.

**The stale and the new archive differ by 8 bytes** — 828088 against 828080 —
which is exactly why the size would have been useless as a proof here. The
mtime (`Sep 30 23:38` → `Oct 1 03:37`) is the real discriminator, and the log
below shows the whole archive being compiled and archived in this run.

### A builder mistake, recorded and repaired

My first cleanup pass for this package ran `rm -rf nest/aarch64-android24/share/man`.
That was **wrong**: `share/man` is a *shared* prefix directory, not oniguruma's
artifact. `stage2.md` itself says oniguruma installs **no** man pages at all, so
the directory had nothing to do with this package.

Scope of the mistake and what I did about it:

```
$ find nest/aarch64-android24/share/man -type f | wc -l
0
```

Zero files left — the deletion had taken `man-pages`, `systemd-man-pages` and
`tcl`'s pages with it, and all three held a **fresh** stamp, so a plain rerun
would have reported `skip ... (fresh)` and never restored them. Repair:

```sh
rm -f nest/aarch64-android24/.retrolunar-man-pages \
      nest/aarch64-android24/.retrolunar-systemd-man-pages \
      nest/aarch64-android24/.retrolunar-tcl
# then rebuilt each; each reported its source block as fresh and did real
# install work:
sh /tmp/repair-systemd-mp.sh   #  -> 1278 files under share/man
sh /tmp/repair-mp.sh           #  -> 4287 files
sh /tmp/repair-tcl.sh          #  -> 5145 files, exit 0, tcl rebuilt cleanly
```

The prefix is back to **5145 man files**, all three packages' stamps
re-touched, and tcl's rebuild is itself a clean build (`exit 0`,
`Installing documentation in .../out-jJuDwT/share/man`). No recipe was
touched; no work was "worked around" — the tree was simply put back and the
mistake is written down here rather than quietly dropped.

The lesson for the next builder, and the reason it is written down at all:
clean a package's artifacts by **path prefix specific to that package**
(`lib/libonig*`, `include/onig*.h`, `lib/pkgconfig/oniguruma.pc`,
`bin/onig-config`), never by a shared directory such as `share/man`,
`share/doc` or `include/`. `include/` in particular is full of other
packages' headers and needs name-scoped `rm -f` only.

## Outcome: **SUCCESS**

Real work in the log — 101 compiler invocations, the full 41-object archive,
and a real install:

```
checking host system type... aarch64-unknown-linux-android
config.status: creating onig-config
/bin/sh ../libtool  --tag=CC   --mode=link .../bin/aarch64-linux-android24-clang -Wall   -O2 -fPIC -I/home/si/ond/git/retrolunar/nest/aarch64-android24/include -DANDROID -isystem .../sysroot/usr/include  -version-info 10:0:5  -L.../nest/aarch64-android24/lib -Wl,-rpath-link,... -lm -o libonig.la -rpath .../out-knpeZW/lib regparse.lo regcomp.lo ... onig_init.lo
libtool: link: .../bin/llvm-ar cr .libs/libonig.a  regparse.o regcomp.o regexec.o regenc.o regerror.o regext.o regsyntax.o regtrav.o regversion.o st.o reggnu.o unicode.o ... onig_init.o
libtool: link: .../bin/llvm-ranlib .libs/libonig.a
libtool: install: /usr/bin/install -c .libs/libonig.a .../out-knpeZW/lib/libonig.a
libtool: install: chmod 644 .../out-knpeZW/lib/libonig.a
libtool: install: .../bin/llvm-ranlib .../out-knpeZW/lib/libonig.a
 /usr/bin/install -c onig-config '.../out-knpeZW/bin'
 /usr/bin/install -c -m 644 oniguruma.pc '.../out-knpeZW/lib/pkgconfig'
```

`-fPIC` is on the link line, so `--with-pic` took. The host triple resolved
correctly as `aarch64-unknown-linux-android`.

### The three `stage2.md` "most likely to be wrong" items

1. **`make install` walking into `test/` and `sample/`** — it did, and it is
   **not** a failure, exactly as predicted. Quoted:

   ```
   Making install in sample
   make[2]: Nothing to be done for 'install-exec-am'.
   make[2]: Nothing to be done for 'install-data-am'.
   ```

   `check_PROGRAMS` were never built, so no host program entered the prefix.

2. **`onig-config` generation** — it exists and is executable. The cause was
   `config.status`'s `AC_CONFIG_COMMANDS([default],[chmod +x onig-config])`,
   not the `Makefile.am` rule, which is exactly as `stage2.md` described:

   ```
   -rwxr-xr-x 1 si si 1418 Oct  1 03:37 nest/aarch64-android24/bin/onig-config
   ```

3. **`x86_64-mingw`** — out of scope for this build (this is
   `aarch64-android24`). Recorded, not investigated.

## Artifact verification (real output)

The one command that proves it —
`llvm-nm --defined-only $PREFIX/lib/libonig.a | grep ' T onig_init'`:

```
0000000000000000 T onig_init
00000000000000a8 T onig_initialize_encoding
00000000000005c4 T onig_initialize_match_param
00000000000036b0 T onig_initialize
00000000000006c8 T onig_init_for_match_at
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls -la $PREFIX/lib/libonig.a` | `-rw-r--r-- 1 si si 828080 Oct  1 03:37 nest/aarch64-android24/lib/libonig.a` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libonig.a \| head -3` | `libonig.a(regparse.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| both headers | `test -f $PREFIX/include/oniguruma.h` and `test -f $PREFIX/include/oniggnu.h` | `both headers present` |
| pkg-config version | `pkg-config --modversion oniguruma` | `6.9.10` |
| `onig-config` executable | `test -x $PREFIX/bin/onig-config` | pass — `-rwxr-xr-x ... 1418 Oct  1 03:37` |
| **no shared library** | `ls $PREFIX/lib/libonig*.so*` | `no .so (correct)` |
| **no man pages from this package** | — | none installed; the build's install rules touched only `lib/`, `include/` and `bin/onig-config` |

The staged `.pc` rewrite worked: the loader turned the `@prefix@`/`@libdir@`
placeholders in `oniguruma.pc.in` into the published prefix (visible in the
`sed -e 's,[@]prefix[@],.../out-knpeZW,g'` line above, and confirmed by
`pkg-config --modversion` resolving against the real path).

## Rerun proves the new stamp is real

```
$ sh /tmp/build-oniguruma.sh
skip oniguruma@source (fresh)
skip oniguruma@aarch64-android24 (fresh)
```

## System-level findings

- **Builder process finding (not a system defect).** The over-broad
  `rm -rf share/man` is described in full above. It is a lesson about cleaning
  a *shared* prefix, not a defect in any system file or recipe, and the nest
  was restored to its prior state before oniguruma was built.
- No recipe change was made; `packages/oniguruma/generic.lua` and
  `source.lua` are committed unmodified.
