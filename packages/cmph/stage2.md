REJECT

# cmph review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, cmph 2.0.2.
Tarball verified with `tar tf` before extraction (717 entries), extracted to
`/home/si/.revE/src2/cmph-2.0.2`.

## 1. Is it using the SYSTEM?

Almost entirely. `./configure $AUTOCONF_CONFIGURE_FLAGS …`, `make -j1`,
`make -j1 install`. No hardcoded triplet/API, no `export` of search flags, no
`sed`/patch, no fan-out.

**The one violation is `autoreconf -fi` at line 36.** AGENTS.md's build-body
hygiene is stated as a hard rule: "only `cp`, `./configure`, `cmake`, `make`,
`make install`, `ninja`, `touch`, `find`, `mkdir`, `cat`-heredocs. NEVER
`sed`, patches, `/dev/null`, or multi-job builds." `autoreconf` is not on that
list. It is a code generator that produces `configure` and `Makefile.in` — the
same category of step as the `configure` it stands in for, and the list names
`./configure` but not the thing that makes it.

Everything *around* it is right, and worth saying so the adder does not undo
it: the four `require(…@native)` calls are exactly correct, because
`autoreconf`, `automake`, `libtool` and `m4` are host tools that must run on
the build machine, and all four packages exist in this tree
(`packages/{autoconf,automake,libtool,m4}` all present). Passing them as make
variables or exporting them would be wrong; `@native` is right. The comment
explains it too. The only thing wrong is that the verb is not sanctioned.

## 2. Is it doing what the package needs?

**The premise is correct — verified, and by the strictest method.** The claim
is that the 2.0.2 tarball ships `configure.ac` but no generated build system.
I checked the **tarball index**, not just the extracted tree, so this is not a
missed extraction:

```
$ tar tzf cmph.tar.gz | grep -c 'Makefile\.in'   →  0
$ find . -name 'Makefile.in' | wc -l             →  0
configure       → absent
aclocal.m4      → absent
configure.ac    → present (2682 bytes)
```

717 entries, zero `Makefile.in`. `./configure` genuinely does not exist until
something generates it. `configure.ac:5` is
`AC_CONFIG_HEADERS([config.h])` and `grep -c AC_CONFIG_SUBDIRS` → 0, so the
guard's template name and scope are right. The guard is genuinely load-bearing
here — `config.h.in` does not exist in the tarball either, and `autoreconf -fi`
creates it, which is why the `touch` after it is not merely tidy. That
observation is correct and well made.

**The three `--disable-*` flags are all real and correctly justified.** I
confirmed `--disable-cxxmph` (`configure.ac:38-53`, errors without a C++0x
compiler), `--disable-benchmarks` (`:56-62`, needs host-only
`hopscotch_map.h`) and `--disable-check` (`:67-69`, already the upstream
default). None is a nonexistent flag.

**The generator claim is correct too.** `src/Makefile.am:2` declares
`noinst_PROGRAMS = bm_numbers` and `:36` builds it, but nothing invokes it,
and the bdz table that looks generated is a literal array already in the tree
(`src/bdz.c:20`, `const cmph_uint8 bdz_lookup_table[] =`). So there is no
second hidden generator. The adder checked this properly.

**So: the recipe is factually accurate in every particular, and still out of
rules.** The single defect is the verb.

## The cross-cutting question, adjudicated

The brief asks which of cmph/minizip is wrong. I checked the whole tree, and
the answer is unambiguous:

```
$ grep -lE '^\s*autoreconf' packages/*/generic.lua
packages/cmph/generic.lua      ← the only build body in the repo that runs it
```

Every other recipe that faces a missing generated build system **avoids** it
by choosing the other build system. The explicit precedent is wolfssl, ACCEPTed:

> `packages/wolfssl/stage2.md:25` — "This is the 'tarball ships no generated
> build system' case, handled by choosing the other build system rather than by
> invoking `autoreconf`."

**Adjudication: `cmph`'s WILL BUILD is the incorrect verdict, not
`minizip`'s WILL NOT BUILD.** autoreconf is not a sanctioned build-body verb
today, so a recipe that runs it is outside the rules; minizip, which refuses to
run it and records the blocker, follows the rule, and cmph, which runs it,
does not.

**But the honest finding underneath is that the RULE is probably wrong**, and
the reviewer should say so rather than let a rule defect harden into precedent:

- `autoreconf` here does nothing a build step cannot: it runs four **native**
  host tools, all four already packaged in this tree, and emits files into
  `$WORK` that the rest of the body then consumes exactly as a dist tarball's
  generated files would. It is deterministic, offline, and target-neutral.
- The hygiene list's purpose is to forbid *patching upstream*, *sed-ing
  sources*, *fanning out*, and *reaching outside `$WORK`/`$OUT`*.
  `autoreconf -fi` violates none of those.
- Refusing it makes a legitimate package unbuildable for a reason that is about
  bookkeeping, not correctness — and produces exactly the asymmetry the brief
  spotted: minizip permanently WILL NOT BUILD for a solvable problem.

**Recommendation to the director (not a reviewer's call to make unilaterally):**
amend AGENTS.md's hygiene list to admit `autoreconf -fi` alongside the existing
`./configure`, explicitly conditioned on the four `@native` autotools requires,
which is the shape cmph already has right. If that amendment is made,
**cmph's recipe becomes ACCEPTable as written, and minizip's six rows flip to
WILL BUILD** — `autoreconf -fi` is all that separates it from a staged
`libminizip.a`, since I have read the tree and nothing else stands in the way.

Until then, this recipe is out of rules and must not be accepted, because
accepting it would make cmph the first of a silent two-verdict precedent for
the same need.

## Required changes

One of:

1. **Director amends AGENTS.md** to permit `autoreconf -fi` with the
   `@native` autotools requires → this recipe is then correct as written.
   Prefer this: the recipe is otherwise sound.
2. **Recipe avoids autoreconf.** cmph has no CMake build, so there is no
   alternative build system — this package would become WILL NOT BUILD like
   minizip, which is a worse outcome for the tree and an argument for (1).

What is not acceptable is shipping the current state, where cmph builds and
minizip does not for one identical reason.

## Forecast

I believe **0 of 6**. All six rows are WILL BUILD on the strength of a build
body that invokes an unsanctioned verb. The forecasts' *technical* content
(tarball shape, flag existence, generator analysis) is accurate throughout —
I verified each — but the verdict rests on the recipe being allowed to run,
and it is not.

## Carried to the build

```sh
# Precondition. If the rule is amended, these are the checks.
test -f "$WORK/configure" || echo "no configure: autoreconf did not run"
test -f "$WORK/config.h.in" || echo "no config.h.in: autoheader did not run"
test -f "$WORK/Makefile.in" || echo "no Makefile.in: automake did not run"

# artifacts (expected: all present)
test -f "$OUT/lib/libcmph.a"        || echo "MISSING libcmph.a"
test -f "$OUT/include/cmph/cmph.h"  || echo "MISSING cmph.h"
test -f "$OUT/bin/cmph"             || echo "MISSING cmph generator"

# static: scoped by cmph's own name so a sibling's .so cannot satisfy it
find "$OUT/lib" -name 'libcmph.*' | grep -c '\.a$'   # expected 1
find "$OUT/lib" -name 'libcmph.so*' | wc -l           # expected 0

# version expected 2.0.2
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion cmph 2>/dev/null \
  || grep -E '^Version' "$OUT/lib/pkgconfig/cmph.pc" 2>/dev/null

# --disable-cxxmph worked: no C++ binding objects in the archive
llvm-nm "$OUT/lib/libcmph.a" | grep -cw 'Cmph'    # low; no mangled C++ symbols

# ELF machine per family
$OBJDUMP -f "$OUT/lib/libcmph.a" | head -3
$OBJDUMP -f "$OUT/bin/cmph" | head -3
```