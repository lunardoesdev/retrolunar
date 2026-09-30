# bash 5.3 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **FAILURE — platform wall, API level, exactly as forecast**

bash does not build at API 24, and `stage1.md`'s WILL NOT BUILD row for this
system was correct in every particular: the same three functions, the same
file, the same reason. Nothing was published and no stamp was written.

```
$ ls nest/aarch64-android24/bin/bash
no bash binary (correct)
$ ls -a nest/aarch64-android24/.retrolunar-bash
no stamp (correct)
```

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-bash
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'bash@aarch64-android24' > /tmp/build-bash.sh
sh -n /tmp/build-bash.sh          # exit 0 — syntax gate passed
sh /tmp/build-bash.sh             # exit 2
```

## Stale-artifact cleanup

No stale artifacts and no stamp existed:

```
$ ls -a nest/aarch64-android24/.retrolunar-bash
ls: cannot access '.../.retrolunar-bash': No such file or directory
```

The stamp delete was still run unconditionally, as procedure. The build
produced nothing, so no false pass is possible.

## The error, quoted in full

`/tmp/build-bash.log:2782-2802`, the four errors (the 10 warnings alongside
them are `-Wparentheses` noise from 2015-era C and are not the failure):

```
bashline.c:2739:7: error: call to undeclared function 'setgrent'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
 2739 |       setgrent ();
      |       ^
bashline.c:2742:18: error: call to undeclared function 'getgrent'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
 2742 |   while (grent = getgrent ())
      |                  ^
bashline.c:2742:16: error: incompatible integer to pointer conversion assigning to 'struct group *' from 'int' [-Wint-conversion]
 2742 |   while (grent = getgrent ())
      |                ^ ~~~~~~~~~~~
bashline.c:2750:7: error: call to undeclared function 'endgrent'; ISO C99 and later do not support implicit function declarations [-Wimplicit-function-declaration]
 2750 |       endgrent ();
      |       ^
...
10 warnings and 4 errors generated.
make: *** [Makefile:107: bashline.o] Error 1
```

- **File and line:** `bashline.c:2739`, `:2742` and `:2750`, in
  `nest/source/bash/bashline.c`.
- **Failing object:** `bashline.o`, rule `Makefile:107`.

The second error is a *consequence* of the first, not a separate defect:
with `getgrent` undeclared it is implicitly typed `int`, so the assignment to
`struct group *` is then invalid. There is one root cause and three call
sites.

## Classification: platform wall (Bionic API level)

Bionic's `grp.h` gates all three functions at API 26. Read from the NDK r28c
sysroot:

```
$ grep -nE 'getgrent|setgrent|endgrent' .../sysroot/usr/include/grp.h
56:struct group* _Nullable getgrent(void) __INTRODUCED_IN(26);
58:void setgrent(void) __INTRODUCED_IN(26);
59:void endgrent(void) __INTRODUCED_IN(26);
```

Confirmed at the API-24 wrapper, which does not declare them at all:

```
$ aarch64-linux-android24-clang -E /tmp/g.c | grep -E 'getgrent|setgrent|endgrent'
(no output)
```

And confirmed the other side of the gate, so the wall is known to be exactly
API 26 and nothing else. The same source compiles clean at API 35:

```
$ aarch64-linux-android35-clang -c /tmp/g35.c -o /dev/null
API 35: COMPILES CLEAN — the wall is exactly API 26
```

**No flag, and no recipe change, can fix this.** The functions are simply not
declared below API 26, and the calls are not behind any `#if`. Patching
`bashline.c` is forbidden by AGENTS.md, and supplying the declarations by
hand would be both a source patch and a lie about the target libc.

`stage1.md`'s row is confirmed: API 21, 23 and 24 all fail for this reason,
and 35 builds. Its note that "the `CC_FOR_BUILD` line in `generic.lua:19`
only affects bash's host-side `builtins/` helper and does not touch this" is
also confirmed — the failure is in the *target* compile of `bashline.c`, not
in the host helper.

## What this build does and does not tell us about the rework

The `CC_FOR_BUILD`/`CFLAGS_FOR_BUILD` move from `android.lua` to
`generic.lua` is in this build, and **the build got past `builtins/`
successfully** — the failure is at `bashline.o`, which comes later in the
link order than the host helper. So the host-helper fix works on
`aarch64-android24`.

That is the Android half. The move was made **for `x86_64-mingw`
specifically**, and mingw is not built here, so **the original motivation is
still unconfirmed.** What the reasoning establishes is that the premise is
sound and system-independent: the wall is `CROSS_COMPILING`, and mingw is
cross while `clang-native` is not. To actually confirm it, someone needs to
build `bash@x86_64-mingw`. I have not done that and am not claiming it.

## Rerun

Not applicable — no stamp was written, so a rerun would rebuild rather than
print `skip`, which is the correct signal that no artifact was produced.

## No target binary was executed

No QEMU, no emulator, no `binfmt_misc` registration was used or installed.
Every check above is static compilation (`-c`, `-E`) — no linking of a target
executable, let alone running one.

## System-level findings

- **`getgrent`/`setgrent`/`endgrent` are API-26 in Bionic**, which makes
  `aarch64-android21`, `aarch64-android23` and `aarch64-android24` a dead end
  for bash as the recipe stands. The `android26` and `android35` targets in
  this tree are both above the gate, so the package is recoverable on this
  tree without any recipe change — the same conclusion recorded in the
  `topackage.md` sysklogd correction, and it now has a build behind it
  rather than only a header read.
- This is the third API-26-or-higher wall in the prefix (after `getsubopt`
  for sysklogd). **Bionic's API-level gating is the dominant class of
  platform wall in this repository**, and it is not a flag problem — no
  amount of recipe work raises a declared-since-26 symbol at API 24.

## Recipe changes

**None.** `packages/bash/generic.lua` is committed unmodified by this build;
the `CC_FOR_BUILD` move and the `buildconf.h.in` guard are already in the
tree from the rework commits. No system file was touched.
