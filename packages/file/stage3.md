# file 5.46 — stage 3 build record

System built for: **`aarch64-android24`** — plus the prerequisite
**`clang-native`** build that the new `packages/file/clang-native.lua`
introduces.

## Outcome: **SUCCESS**, on both systems

This is the first build of `file` in the tree, and it confirms the whole
arrangement the rework created: a cross build of `file` 5.46 requires a
`file` of *exactly* 5.46 on the build host, the build host has 5.48, and the
fix is a separate native recipe that puts a real 5.46 in
`$NATIVE_PREFIX/bin`.

## Command sequence

Two builds, in this order — the native one **must** come first, because the
Android configure probes for `file` on `PATH` and `$NATIVE_PREFIX/bin` is
what the loader puts there.

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0

# 1. the native tier — new recipe
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'file@clang-native' > /tmp/build-file-native.sh
sh -n /tmp/build-file-native.sh          # exit 0
sh /tmp/build-file-native.sh             # exit 0

# 2. the target
rm -f nest/aarch64-android24/.retrolunar-file
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'file@aarch64-android24' > /tmp/build-file-android.sh
sh -n /tmp/build-file-android.sh         # exit 0
sh /tmp/build-file-android.sh            # exit 0
```

Both runs exited **0**.

## Stale-artifact cleanup

Neither system had stale artifacts or a stamp — `file` has never been built
in this tree:

```
$ ls -a nest/clang-native/.retrolunar-file
ls: cannot access '.../.retrolunar-file': No such file or directory
$ ls nest/clang-native/bin/file
ls: cannot access '.../bin/file': No such file or directory
$ ls -a nest/aarch64-android24/.retrolunar-file
ls: cannot access '.../.retrolunar-file': No such file or directory
```

The stamp delete was still run unconditionally before the Android build. All
artifacts below are mtime-checked at `Oct 1 05:34`, from this build.

## Why the native build exists — confirmed at the source

`magic/Makefile.am:366-385`, read rather than assumed:

```make
if IS_CROSS_COMPILE
FILE_COMPILE = file${EXEEXT}
...
		@(if expr "${FILE_COMPILE}" : '.*/.*' > /dev/null; then \
		    echo "Using ${FILE_COMPILE} to generate ${MAGIC}" > /dev/null; \
		  else \
		    v=$$(${FILE_COMPILE} --version | sed -e s/file-// -e q); \
		    if [ "$$v" != "${PACKAGE_VERSION}" ]; then \
			echo "Cannot use the installed version of file ($$v) to"; \
			echo "cross-compile file ${PACKAGE_VERSION}"; \
```

Under `IS_CROSS_COMPILE` the generator is a **bare PATH lookup**, and the
rule hard-fails unless that `file` reports exactly `PACKAGE_VERSION` — 5.46.
The measured state of this host:

```
$ /usr/bin/file --version | head -1
file-5.48
$ nest/clang-native/bin/file --version | head -1
file-5.46
```

5.48 ≠ 5.46, so without the native recipe the Android build would abort with
`Cannot use the installed version of file (5.48) to cross-compile file 5.46`.
The new recipe removes the mismatch by construction rather than by hoping.

**The key safety property, confirmed:** `FILE_COMPILE` is a bare name under
`IS_CROSS_COMPILE`, so the binary that generates `magic.mgc` is the one from
`PATH` — which is `$NATIVE_PREFIX/bin/file`, an **x86-64 host binary**. The
target `file` is never executed to build itself. That is what keeps this
package inside the no-emulation rule.

## Artifact verification (real output)

### `file@clang-native` — SUCCESS

The one command that proves it — architecture first, because a native tool
that is not a host binary is useless here:

```
$ file nest/clang-native/bin/file
nest/clang-native/bin/file: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, ... for GNU/Linux 4.4.0, not stripped
```

```
$ ls -la nest/clang-native/bin/file
-rwxr-xr-x 1 si si 36128 Oct  1 05:34 nest/clang-native/bin/file
```

```
$ nest/clang-native/bin/file --version | head -1
file-5.46
```

It **is run**, deliberately and legally: `IS_CROSS_COMPILE` is false on a
native build, so `FILE_COMPILE` becomes `$(top_builddir)/src/file` and the
build executes the x86-64 binary it just built. That is a host binary on an
x86-64 host. The repository's ban is on running a **target** binary; no
target binary was run.

Rerun proves the stamp:

```
$ sh /tmp/build-file-native.sh
skip file@source (fresh)
skip file@clang-native (fresh)
```

### `file@aarch64-android24` — SUCCESS

The one command that proves it:

```
$ llvm-objdump -f nest/aarch64-android24/bin/file | head -3

nest/aarch64-android24/bin/file:	file format elf64-littleaarch64
architecture: aarch64
```

```
$ file nest/aarch64-android24/bin/file
ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 24, built by NDK r28c (13676358), not stripped
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| the tool, this build | `ls -la $PREFIX/bin/file` | `-rwxr-xr-x 1 si si 202072 Oct  1 05:34 .../bin/file` |
| `magic.mgc` generated | `find $PREFIX -name 'magic.mgc'` | `nest/aarch64-android24/share/misc/magic.mgc` |
| libmagic installed | `ls -la $PREFIX/lib/libmagic.*` | `libmagic.la` (1006 B), `libmagic.so` (314464 B) |
| pkg-config | `pkg-config --modversion libmagic` | `5.46` |

`libmagic` is a **shared** object. `file`'s configure selects shared unless
`--disable-shared` is passed, and the recipe passes neither — this is
upstream's own default and not something this build changed. Flagging it
because the xz commit in the rework series added `--disable-shared` on
policy grounds; `file` is a candidate for the same treatment and is recorded
here as an observation, not a change I made.

Rerun proves the stamp:

```
$ sh /tmp/build-file-android.sh
skip file@source (fresh)
skip file@aarch64-android24 (fresh)
```

## A note on the self-reference finding

The `clang-native.lua` comment claims that `require("file@native")` from
`generic.lua` would be a self-reference, because the loader falls back to
`packages/file/generic.lua` when no `clang-native.lua` exists, and with no
module cache and no cycle guard that dies with `C stack overflow` at
`src/loader.lua:104`.

I did not reproduce the crash — that would mean reverting the file, and the
fix is already in place and demonstrably works. The claim is recorded as the
reviewer's finding, not as something this build verified. What *is* verified
is the part that matters operationally: with `clang-native.lua` present, the
emitted script resolves cleanly and `file@clang-native` builds and installs
without incident.

## System-level findings

- **`require("<pkg>@native")` from `<pkg>/generic.lua` is a latent trap for
  every package.** The loader's `@native` resolution falls back to the
  requiring file when no system-specific recipe exists, and there is no cycle
  guard. `file` is the first package in the tree to need a native
  self-build, so it is the first to hit this; anything else needing one will
  hit the same wall and must be given a genuinely different `clang-native.lua`
  rather than a `require`. A cycle guard in `src/loader.lua` would be the
  general fix, and is outside this build's scope.
- The build host carries `file-5.48` while this package pins 5.46. That skew
  is what makes the native recipe necessary, and it will reappear on any
  build host whose `file` differs from the pinned version.

## Recipe changes

**None.** `packages/file/clang-native.lua` was created by the rework and is
committed in the rework series; this build neither changed it nor added to
it. No system file was touched.
