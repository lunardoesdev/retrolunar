# libseccomp 2.6.1 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS**, after one recipe change

**A recipe defect was found on the first run and fixed: the recipe built the
library but never installed it.** Details, with the evidence, are under
"Recipe change made" below. The rule that allows this is narrow — an
unambiguously wrong line in the recipe, not a platform wall and not an
upstream defect — and it qualifies on both counts.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libseccomp
rm -f nest/aarch64-android24/lib/libseccomp*.a nest/aarch64-android24/lib/libseccomp*.so* \
      nest/aarch64-android24/lib/libseccomp*.la \
      nest/aarch64-android24/lib/pkgconfig/libseccomp.pc \
      nest/aarch64-android24/include/seccomp.h \
      nest/aarch64-android24/include/seccomp-syscalls.h \
      nest/aarch64-android24/bin/scmp_sys_resolver \
      nest/aarch64-android24/share/man/man3/seccomp_*.3 \
      nest/aarch64-android24/share/man/man1/scmp_sys_resolver.1
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libseccomp@aarch64-android24' > /tmp/build-libseccomp.sh
sh -n /tmp/build-libseccomp.sh          # exit 0 — syntax gate passed
sh /tmp/build-libseccomp.sh
```

This package was built **twice**: once with the recipe as reviewed, which
exposed the missing install, and once after the fix. Both logs are quoted
below; only the second one produced the published artifacts.

## Stale-artifact cleanup — this package HAD stale artifacts

Pre-build inspection, all dated `Sep 30 23:38` — the discarded run:

```
$ ls -la nest/aarch64-android24/lib/libseccomp*
-rw-r--r-- 1 si si 281708 Sep 30 23:38 nest/aarch64-android24/lib/libseccomp.a
-rw-r--r-- 1 si si  1000 Sep 30 23:38 nest/aarch64-android24/lib/libseccomp.la
-rwxr-xr-x 1 si si 180912 Sep 30 23:38 nest/aarch64-android24/lib/libseccomp.so
$ ls nest/aarch64-android24/lib/pkgconfig/libseccomp.pc
nest/aarch64-android24/lib/pkgconfig/libseccomp.pc
-rw-r--r-- 1 si si 52710 Sep 30 23:38 .../include/seccomp-syscalls.h
-rw-r--r-- 1 si si 27915 Sep 30 23:38 .../include/seccomp.h
$ ls -a nest/aarch64-android24/.retrolunar-libseccomp
nest/aarch64-android24/.retrolunar-libseccomp
```

**A stale `libseccomp.so` again** — a *shared* library, from a discarded
recipe that did not pass `--disable-shared`. Left in place it would have
survived `cp -rf` and left a shared `.so` sitting beside this build's static
`.a`. Deleted, and confirmed absent after the build.

**Man pages were cleaned name-scoped, and this mattered.** `share/man` is a
shared prefix directory holding 5145 files from `man-pages`, `systemd-man-pages`
and `tcl`. The cleanup removed only `share/man/man3/seccomp_*.3` and
`share/man/man1/scmp_sys_resolver.1` — 36 paths. Verified before and after
that nothing else moved:

```
$ ls nest/aarch64-android24/share/man/man3 | wc -l      # before
3261
$ ls nest/aarch64-android24/share/man/man3 | wc -l      # after cleanup
3261
$ find nest/aarch64-android24/share/man -type f | wc -l # before
5145
```

The `man-pages` package's own seccomp-related pages
(`man2/seccomp.2`, `man2/seccomp_unotify.2`, `man5/proc_pid_seccomp.5`,
`man2const/PR_*_SECCOMP.2const`) are in `man2`/`man5`/`man2const`, not `man3`,
and were not touched. After the rebuild the total is **5181** — 5145 + 36, the
exact set this package ships.

No stale libseccomp man pages existed beforehand, so the count was stable
across the cleanup.

## The recipe defect, and the fix

### What was wrong

The recipe as reviewed ended its build with:

```sh
make -j1 -C src
make -j1 -C include install-includeHEADERS
make -j1 -C doc install-man
make -j1 -C . install-pkgconfDATA
```

`make -j1 -C src` **builds and archives but does not install**. The first run
exited **0** and published a coherent-looking prefix — headers, 36 man pages
and a `libseccomp.pc` — with **no library in it**:

```
$ llvm-nm --defined-only nest/aarch64-android24/lib/libseccomp.a | grep ' T seccomp_init'
llvm-nm: error: nest/aarch64-android24/lib/libseccomp.a: No such file or directory
```

The log shows the archive being created and then the directory being left
without any install of it:

```
  CCLD     libseccomp.la
make[1]: Leaving directory '.../work-tXJeoY/src'
```

and the only `lib/` write in the whole log was the `.pc`:

```
 /usr/bin/mkdir -p '.../out-Y7zzC7/lib/pkgconfig'
 /usr/bin/install -c -m 644 libseccomp.pc '.../out-Y7zzC7/lib/pkgconfig'
```

`stage2.md` asked for exactly this file in its artifact table
(`$PREFIX/lib/libseccomp.a`) while its own recipe comment said only that "the
narrow targets below keep both headers, the .pc and all 36 man pages". The
narrowing went one step too far and dropped the library along with
`tools/`, and because the build still exited 0 **and** the prefix still had
headers and a `.pc` pointing at a library that was never there, this would
have shipped as a silent, plausible-looking success. It is exactly the failure
mode the "check the artifact, not the exit code" rule exists to catch — and
the artifact check is what caught it.

### The fix

One line, minimal, with a comment saying why:

```diff
-        make -j1 -C src
+        # install-libLTLIBRARIES builds AND installs the library: a plain
+        # `make -C src` only archives it into .libs/ and copies nothing into
+        # $OUT, which would leave libseccomp.a missing from the prefix while
+        # its headers, man pages and .pc all shipped.
+        make -j1 -C src install-libLTLIBRARIES
```

**Why this qualifies as a recipe defect rather than something to work around.**
The build succeeded and the toolchain was fine; a line of the recipe simply
failed to do its job. `lib_LTLIBRARIES = libseccomp.la` and
`install-libLTLIBRARIES: $(lib_LTLIBRARIES)` both exist at
`src/Makefile.in:536` and `:590`, so the target is upstream's own and needs no
new switch. There is no `install-exec-hook` in `src/Makefile.am`, so the
narrow target pulls in nothing that `make -C src install` would have avoided —
it installs exactly the one library. It also preserves the recipe's original
intent: `tools/` is still never built.

It is not a platform wall (nothing about Bionic is involved — the compile and
archive both succeeded) and not an upstream defect (upstream's
`install-libLTLIBRARIES` works). **Only `packages/libseccomp/generic.lua` was
changed. No system file was touched.**

### Second run, after the fix

```
libtool: install: /usr/bin/install -c .libs/libseccomp.lai '.../out-snR36C/lib/libseccomp.la'
libtool: install: /usr/bin/install -c .libs/libseccomp.a '.../out-snR36C/lib/libseccomp.a'
libtool: install: chmod 644 '.../out-snR36C/lib/libseccomp.a'
libtool: install: .../bin/llvm-ranlib '.../out-snR36C/lib/libseccomp.a'
```

## Real work in the log

```
checking host system type... aarch64-unknown-linux-android
checking for aarch64-linux-android-gperf... no
checking for gperf... gperf
  CC       libseccomp_la-api.lo
  CC       libseccomp_la-system.lo
  ...
  CC       libseccomp_la-arch-x86_64.lo
  ...
gperf -m 100 --null-strings --pic -tCEG -T -S1 syscalls.perf > syscalls.perf.c
  CC       libseccomp_la-syscalls.perf.lo
  CCLD     libseccomp.la
```

## The gperf hazard fired, and it was fine

`stage2.md` rank 1 predicted `arch-gperf-generate` would fire deterministically
and that it would need `bash`, `sed`, `nl`, `mktemp` from the build host plus
native gperf. It fired, at `/tmp/build-libseccomp.log:245`:

```
gperf -m 100 --null-strings --pic -tCEG -T -S1 syscalls.perf > syscalls.perf.c
```

and `syscalls.perf.c` was then compiled. `configure` resolved the host tool
correctly, trying the cross-prefixed name first and falling back, exactly as
`configure.ac:126-129` intends:

```
checking for aarch64-linux-android-gperf... no
checking for gperf... gperf
```

`configure.ac:128`'s `AC_MSG_ERROR([please install gperf])` did **not** fire,
because the loader prepends `$NATIVE_PREFIX/bin` to `PATH` for every block. The
rerun confirms the native tool is real and stamp-fresh:

```
skip gperf@source (fresh)
skip gperf@clang-native (fresh)
```

This is the preflight's one prediction that came true exactly as written.

## `tools/` was correctly kept out

`stage2.md` item 2 flagged `tools/`'s `util.la` (`noinst_LTLIBRARIES` with
`-module`) as the most likely place for an unexpected libtool complaint under
`--disable-shared`. It never arose — `tools/` is never entered, because the
recipe targets `src/`, `include/`, `doc/` and the top level only:

```
$ ls nest/aarch64-android24/bin/scmp_sys_resolver
absent (correct)
```

**No target binary was built and none was executed.** No QEMU, no emulator, no
`binfmt_misc` registration was used or installed at any point in this batch.

## Artifact verification (real output)

The one command that proves it —
`llvm-nm --defined-only $PREFIX/lib/libseccomp.a | grep ' T seccomp_init'`:

```
$ llvm-nm --defined-only nest/aarch64-android24/lib/libseccomp.a | grep ' T seccomp_init'
000000000000024c T seccomp_init
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls -la $PREFIX/lib/libseccomp.a $PREFIX/lib/libseccomp.la` | `-rw-r--r-- 1 si si 281708 Oct  1 04:25 .../libseccomp.a`, `-rw-r--r-- 1 si si 974 Oct  1 04:25 .../libseccomp.la` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libseccomp.a \| head -3` | `libseccomp.a(libseccomp_la-api.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| both headers | `test -f $PREFIX/include/seccomp.h` and `seccomp-syscalls.h` | `both headers present` |
| pkg-config version | `pkg-config --modversion libseccomp` | `2.6.1` |
| 35 man3 pages | `ls $PREFIX/share/man/man3 \| grep -c '^seccomp_'` | `35` |
| the man1 page | `ls $PREFIX/share/man/man1/scmp_sys_resolver.1` | present |
| **no shared library** | `ls $PREFIX/lib/libseccomp.so*` | `no libseccomp.so (correct)` — the stale one is gone |
| **no `tools/` binary** | `ls $PREFIX/bin/scmp_sys_resolver` | `absent (correct)` |
| shared man tree intact (**build-time snapshot — do not re-run as a check**) | `find $PREFIX/share/man -type f \| wc -l` **at the time of this build** | `5181` = 5145 before + 36 from this package. This figure was true when written and is **not** a re-runnable assertion: `share/man` is prefix-wide and grows with every package that installs man pages (libnl-3 later added 36 more in `man8`, taking the total to 5194). It is recorded because the *arithmetic* is the evidence — 5145 before, 5181 after, delta exactly 36 — not because the total is a stable property. A package-scoped equivalent that stays true is `ls $PREFIX/share/man/man3 \| grep -c '^seccomp_'` → `35` |

**Size coincidence, again.** The rebuilt `libseccomp.a` is *also* 281708 bytes,
identical to the deleted stale one. Byte count would have been a false pass for
the third time in this batch. The mtime (`Sep 30 23:38` → `Oct 1 04:25`) and the
install lines above are what prove it.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-libseccomp.sh
skip gperf@source (fresh)
skip gperf@clang-native (fresh)
skip libseccomp@source (fresh)
skip libseccomp@aarch64-android24 (fresh)
```

## System-level findings

None specific to this package. The `-llog` blocker recorded in
`packages/abseil-cpp/stage3.md` and `packages/glog/stage3.md` is a system-wide
Android defect; libseccomp does not use `__android_log_write` and is unaffected
by it.

One observation worth passing on: `share/man` in this prefix is populated by
four packages (`man-pages`, `systemd-man-pages`, `tcl`, `libseccomp`) and is a
**shared** directory. A builder cleaning a package's artifacts must scope man
page removal by name, never `rm -rf share/man`. I made that mistake earlier in
this batch on oniguruma, found it, repaired the nest and wrote it up in
`packages/oniguruma/stage3.md`.
