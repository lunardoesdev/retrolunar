ACCEPT

# libcap 2.78 — stage 2 review

Checked against the unpacked `libcap-2.78` tree in `$HOME/dl`. This is the
cleanest recipe in the batch: every one of the adder's three load-bearing
claims is real, verified line by line, and the recipe is right about all three.

## The three claims, verified

**1. `Make.Rules:68` is a hard `:=` that beats an exported env var.** Confirmed
by reading the file, not by inference:

```
$ grep -n 'CC := \|^AR :=\|^RANLIB :=\|BUILD_CC ?=\|USE_GPERF ?=\|PAM_CAP ?=\|GOLANG ?=\|^PTHREADS ?=\|^SHARED ?=' Make.Rules
68:CC := $(CROSS_COMPILE)gcc
70:AR := $(CROSS_COMPILE)ar
71:RANLIB := $(CROSS_COMPILE)ranlib
72:OBJCOPY := $(CROSS_COMPILE)objcopy
88:BUILD_CC ?= $(CC)
106:USE_GPERF ?= $(shell which gperf >/dev/null 2>/dev/null && echo yes)
118:SHARED ?= yes
123:PAM_CAP ?= $(shell if [ -f /usr/include/security/pam_modules.h ]; then echo $(SHARED) ; else echo no ; fi)
134:PTHREADS ?= yes
138:GOLANG ?= $(shell if [ -n "$(shell $(GO) version 2>/dev/null)" ]; then echo yes ; else echo no ; fi)
```

`CC :=` at exactly line 68, as claimed. A `:=` in a makefile overrides an
environment variable (only `?=` and `-e` defer to the environment), so an
exported `$CC` would be silently discarded and every object built with a bare
host `gcc`. Command-line variables beat makefile assignments of any kind, so
`make CC="$CC" AR="$AR" RANLIB="$RANLIB"` is the only correct delivery. The
recipe does exactly that. **Correct, and load-bearing.**

**2. `BUILD_CC` must stay the host compiler, and the recipe's `cc` is right.**
`libcap/Makefile:82-86`, confirmed:

```
_makenames: _makenames.c cap_names.list.h
	$(BUILD_CC) $(BUILD_CFLAGS) $(BUILD_CPPFLAGS) $< -o $@

cap_names.h: _makenames
	./_makenames > cap_names.h
```

Line 83 compiles with `$(BUILD_CC)`, line 86 **executes `./_makenames`**. With
`Make.Rules:88` defaulting `BUILD_CC ?= $(CC)`, a cross build would compile a
target binary and then run it here — precisely the no-emulation wall. The
recipe passes `BUILD_CC="cc"`, and `which cc` → `/usr/bin/cc` on this host.
`cap_names.h` is genuinely generated (absent from the tarball; `libcap.h:29`
is `#include "cap_names.h"`, confirmed at that line), so the step cannot be
skipped. Following the `packages/texinfo/generic.lua:7` convention is right.
**Correct, and load-bearing.**

**3. `lib=lib` is load-bearing.** Confirmed at `Make.Rules:20-22`:

```
20:ifndef lib
21:lib=$(shell ldd /usr/bin/ld|grep -E "ld-linux|ld.so"|cut -d/ -f2)
22:endif
```

This is a `$(shell ...)` running `ldd` **on the build machine**. On this x86_64
host the answer is `lib64`, which would put `libcap.pc` in `$OUT/lib64/pkgconfig`
— outside the `$PREFIX/lib/pkgconfig` every system searches. The recipe passes
`lib=lib`. **Correct, and load-bearing.**

## No host binary is run on a target build

I checked this exhaustively, because it is the failure mode that would be
invisible here (qemu-aarch64 is registered via binfmt_misc, so a target binary
would run silently rather than erroring).

- The recipe uses `make -C libcap`, **not** the top-level `Makefile`. The
  top-level recurses into `pam_cap`, `go`, `tests`, `progs` and `doc`
  (`Makefile:11-22`, confirmed) — all excluded, and the `PAM_CAP=no GOLANG=no`
  on the line would have covered them anyway.
- `BUILD_CC` is the only host-compiler use, and its output is a host binary
  that is *supposed* to run. Everything else compiles with `$CC`.
- `SHARED=no` removes the `loader.txt` path (`libcap/Makefile:118-122`), which
  would build `empty` and run `$(OBJCOPY) --dump-section` over it.
- The `install` target's `/sbin/ldconfig` is inside `ifeq ($(FAKEROOT),)`
  (`libcap/Makefile:200-201`, confirmed at that line) *and* inside
  `install-shared-cap`/`install-shared-psx`, which `SHARED=no` skips entirely.
  Unreachable, as claimed.
- `libcapsotest` / `libpsxsotest` (`libcap/Makefile:156-161`) do run
  `$(CAPLIBNAME)`, but they are under `test:`, which the recipe never invokes.

Clean. **No target binary is executed on any system.**

## The system

Every value comes from the system: `CC="$CC"`, `AR="$AR"`, `RANLIB="$RANLIB"` on
both the build and install lines. `prefix="$OUT"` and `lib=lib` are package
decisions with the reasons documented. The host-probe pins — `USE_GPERF=no`
(`Make.Rules:106` probes `which gperf` on the build machine), `PAM_CAP=no`
(`:123` probes `/usr/include/security/pam_modules.h`), `GOLANG=no` (`:138`
probes for `go`) — are all genuinely host-machine-dependent and all pinned
with a comment. `BUILD_CC="cc"` is a host fact, permitted by AGENTS.md:216-222
as a "recipe-local workaround", and it cites the texinfo precedent.

`make -j1` on both lines. `require("libcap@source")` resolves. No missing
dependency.

## The one thing the recipe should have said

Not a defect, but worth recording because the stage1 does not: **there is no
autotools guard and that is correct.** No `configure`, no `aclocal.m4`, and no
config header template of any spelling — the build is hand-written make, so
there is nothing for a timestamp guard to protect. I confirmed the tree has no
`configure.in`/`configure.ac`/`Makefile.in` at all. The recipe's comment says
so. Correct, and the kind of absence claim AGENTS.md:528-534 demands evidence
for; here the evidence is structural (no autotools build system exists), not a
failed grep.

Also: stage1.md:123-124's last check is phrased as "must show `cap_get_proc`
and **no** `psx_load_syscalls` undefined reference problem" — that is not a
command, it is a description of a condition. A builder cannot paste it. The
concrete form is `llvm-nm -u lib/libcap.a | grep -c psx_load_syscalls` → expect
a *non-zero* count of weak definitions and no hard undefined refs; worth
rewording so it can actually be run, but it is documentation, not the recipe.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL NOT BUILD | WILL NOT BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

The mingw **WILL NOT BUILD** is a property of the package, not of the recipe,
and I agree with it: libcap is a Linux capabilities library built on
`prctl`/`capget`/`capset`/`syscall`, none of which exist on Windows. The
adder's probe list (`<grp.h>`, `<sys/syscall.h>`, `<byteswap.h>`, `uid_t` in
`include/sys/capability.h:163`) is the right kind of evidence. A recipe that
honestly forecasts its own non-portability is not defective for having a
`WILL NOT BUILD` row — the loader simply never builds it there.

## Verdict

ACCEPT. Three load-bearing claims, all independently verified at the cited
lines. No target binary executed anywhere in the build or install path. All
flags from the system, all host-machine-dependent probes pinned with reasons,
no autotools guard needed and none present. Nothing to fix.
