REJECT

# minizip review (stage2)

Recipe: `generic.lua`. Source: `source.lua` (re-fetches zlib 1.3.1).
Tarball verified with `tar tf` before extraction (290 entries), extracted to
`/home/si/.revE/src2/zlib-1.3.1`.

## 1. Is it using the SYSTEM?

Yes. `./configure $AUTOCONF_CONFIGURE_FLAGS --disable-demos`, `make -j1`,
`make install`. No hardcoded triplet/API, no `export` of search flags, no
`sed`/patch, no fan-out. The `require("zlib")` and the source path are both
correct. This is not where the package fails.

## 2. Is it doing what the package needs?

**The premise is correct — I verified it.** In
`zlib-1.3.1/contrib/minizip/`:

```
-rw-r--r-- 818   Mar 27  2012  Makefile.am
-rw-r--r-- 786   Jan 23  2024  configure.ac
configure        → does not exist
Makefile.in      → does not exist
aclocal.m4       → does not exist
```

`configure.ac:4` is `AC_INIT([minizip], [1.3.1], …)`, matching the recipe's
version. So there is genuinely no `./configure` to run and the recipe as
written cannot work. The six WILL NOT BUILD verdicts are honest.

**But the recipe is not a recipe — it is a note.** It runs a command that
cannot exist, and its own comment says so:

```
# No configure ships (contrib/minizip/configure.ac exists, the
# generated script does not), so this cannot run as-is: autoreconf is
# not one of the allowed build-body verbs. Recorded, not worked around.
./configure $AUTOCONF_CONFIGURE_FLAGS --disable-demos
```

AGENTS.md: "'@source' never compiles"; a build body that is guaranteed to fail
on its first line is not a build recipe. Shipping one means the builder's
stage3.md records `No such file or directory` rather than the real blocker,
which is the opposite of what a hand-off is for. This is the same class of
defect as sevenzip's: a recipe written to document a diagnosis instead of a
diagnosis.

## The alternative the adder dismisses — I checked it, and it is correctly dismissed

`contrib/minizip/Makefile` is a 2012-era hand-written makefile. Every rule in
it:

```
all: miniunz minizip
miniunz:  $(UNZ_OBJS)
minizip:  $(ZIP_OBJS)
test:	miniunz minizip
clean:
```

**There is no `install` target** — confirmed by both `grep -n install Makefile`
(returning nothing) and the complete rule listing above. So it cannot produce a
staged `libminizip.a`, exactly as the adder says. It also links two demo
programs against `../../libz.a`, i.e. it needs zlib built in place, and it
would build *executables* rather than a library. The adder's judgement is
right and I endorse it.

**Is there a legitimate route within the hygiene rules?** This is the question
the brief poses, and the honest answer is **no**:

- `autoreconf`/`autogen.sh` is not in AGENTS.md's build-body verb list
  (`cp`, `./configure`, `cmake`, `make`, `ninja`, `touch`, `find`, `mkdir`,
  `cat`). It is a *code generator*, like the `configure` it would produce.
- There is no cmake path: `contrib/minizip/` ships no `CMakeLists.txt`.
- There is no hand-written makefile with an install target.

So the two candidates are both blocked, and one of them (autoreconf) is
blocked *by the project's own rule*, not by anything intrinsic to minizip.

## The cross-cutting question: cmph vs minizip must be treated the SAME

The brief asks me to adjudicate this explicitly, because `cmph` is marked WILL
BUILD while running `autoreconf -fi` and `minizip` is marked WILL NOT BUILD for
needing it. **Those two verdicts cannot both be right**, and I have checked the
whole tree to settle it.

`cmph/generic.lua:36` is the **only** build body in this repo that actually
runs `autoreconf`:

```
$ grep -lE '^\s*autoreconf' packages/*/generic.lua
packages/cmph/generic.lua          ← the only hit
```

Everything else that mentions autoreconf does so in a *comment*, choosing the
other build system instead. The clearest precedent is wolfssl, which is
**ACCEPT**ed and whose stage2 says so in as many words
(`packages/wolfssl/stage2.md:25`):

> This is the "tarball ships no generated build system" case, handled by
> choosing the other build system rather than by invoking `autoreconf`.

**My adjudication: `minizip`'s WILL NOT BUILD is the correct verdict, and
`cmph`'s WILL BUILD is the wrong one.** autoreconf is a build-body verb the
project has not sanctioned; until AGENTS.md is amended to allow it, a recipe
that invokes it is outside the rules, and cmph's recipe is the outlier that
should be fixed rather than minizip's forecast that should be softened.

That is a rule question for the director, not something a reviewer should
settle by fiat — but it must be settled consistently, and **not by accepting
cmph and rejecting minizip for the same need.**

If the director does amend the rule to permit `autoreconf` (with the
`require("autoconf@native")` / `automake@native` / `libtool@native` /
`m4@native` requires that cmph already gets right, and which do exist in this
tree), then **minizip becomes buildable** and its six WILL NOT BUILD rows all
flip — `autoreconf -fi` in `contrib/minizip/` is all that stands between this
recipe and a staged `libminizip.a`. I am confident of that because I have read
the tree and there is nothing else in the way.

## Required changes

1. **Either** add `autoreconf -fi` before `./configure` (with the four
   `@native` autotools requires, exactly as `cmph/generic.lua` does), **or**
2. remove the doomed `./configure` line and record in `stage1.md` that the
   package is deliberately unbuilt pending a decision on autoreconf.

Do not ship the body as it stands. It cannot succeed, and a builder running it
learns nothing except the first line's error.

## Artifacts, had it built

From `contrib/minizip/Makefile.am`: `lib_LTLIBRARIES = libminizip.a`
(plus `libmz.a`), `include/minizip.h`, and with `--disable-demos` neither
`miniunz` nor `miniunz` — so no `$OUT/bin` at all.

## Forecast

I agree with **6 of 6** on the *verdicts* (all WILL NOT BUILD, and the missing
`configure` is real), but the recipe body contradicts them by attempting the
build anyway. The verdicts are right; the recipe is the defect.

## Carried to the build

```sh
# The precondition that decides this package, and it must be checked BEFORE
# anything else: there is no configure to run.
test -f "$NESTDIR/source/minizip/contrib/minizip/configure" \
  && echo "configure EXISTS - re-derive the forecast" \
  || echo "CONFIRMED: no generated configure; autotools route needs autoreconf"

# and the hand-written alternative really has no install target:
grep -cE '^install' "$NESTDIR/source/minizip/contrib/minizip/Makefile"  # expected 0

# Once a route exists, the checks that matter:
test -f "$OUT/lib/libminizip.a"  || echo "MISSING libminizip.a"
test -f "$OUT/include/minizip.h" || echo "MISSING minizip.h"
test -d "$OUT/bin" && echo "REGRESSION: --disable-demos should leave no bin/"
$OBJDUMP -f "$OUT/lib/libminizip.a" | head -3
# libminizip must resolve zlib symbols from THIS prefix, not a host one
llvm-nm -u "$OUT/lib/libminizip.a" | grep -cwE 'deflate|inflate'   # expected >=1
```