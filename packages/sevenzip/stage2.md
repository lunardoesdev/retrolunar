REJECT

# sevenzip review (stage2)

Recipes: `generic.lua`. Source: `source.lua`, 7-Zip 26.03.
Tarball verified with `tar tf` before extraction (1292 entries), extracted to
`/home/si/.revE/src2`.

## The blocking defect: the load-bearing premise is FALSE

`source.lua` and `stage1.md` both assert that the `7z2603-src.tar.xz` release
asset's tarball root is **the contents of upstream's `CPP/` directory,
flattened**, so that `C/`, `7zip/`, `Common/`, `Windows/` sit side by side with
no `CPP/` present, and that upstream's `../../../../C/...` references are then
one level too deep. Every one of the six WILL NOT BUILD verdicts rests on that,
and `stage1.md:40` quotes the specific dry-run failure
`make: *** No rule to make target '../../../../C/7zBuf2.c'`.

**That is not what the tarball contains.** Measured directly:

```
$ tar tJf 7z2603-src.tar.xz | grep -c '^CPP/'      →  1092
$ tar tJf 7z2603-src.tar.xz | grep -vc '^CPP/'     →   200
```

The 1092 figure the adder quotes is real — but it is the count of members
**already under a `CPP/` prefix**, which is the opposite of the claim. The
other 200 members are a separate `Asm/`, `C/` and `DOC/` set at the root.
Extraction gives a normal, intact 7-Zip source tree:

```
$ ls
Asm  C  CPP  DOC
$ ls CPP/
7zip  Build.mak  Common  Windows
$ ls CPP/7zip/Bundles/Alone2/
StdAfx.cpp  StdAfx.h  makefile  makefile.gcc  resource.rc
```

`CPP/` is present, `CPP/7zip/Bundles/Alone2/makefile.gcc` is present, and
`CPP/7zip_gcc.mak` — the file `makefile.gcc` includes as `../../7zip_gcc.mak` —
is present at `CPP/7zip/7zip_gcc.mak`.

**The recipe fails for a different, much shallower reason: a missing `CPP/`
prefix in the `make -C` path.** Two dry runs:

```
A) make -C 7zip/Bundles/Alone2 -f makefile.gcc        ← what the recipe runs
   make: *** 7zip/Bundles/Alone2: No such file or directory.  Stop.

B) make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc    ← what the tree contains
   mkdir -p _o
   cc -O2 -c -Werror -Wall -Wextra -DNDEBUG … -o _o/7zBuf2.o ../../../../C/7zBuf2.c
   cc -O2 -c … ../../../../C/7zCrc.c
   … 322 compile lines, no "No rule to make target", no error
```

So `../../../../C/7zBuf2.c` **resolves correctly** from
`CPP/7zip/Bundles/Alone2` — four levels up is the tree root, where `C/` sits.
The adder's central diagnostic, quoted verbatim in its own forecast table for
all six rows, is not reproducible: that error cannot occur against this
tarball.

Note the difference between A and B is `No such file or directory` (the
directory the recipe names does not exist) versus `No rule to make target` (a
missing prerequisite). `stage1.md` reports the second; the recipe produces the
first. That mismatch alone shows the dry run in the forecast was not run
against the tarball the recipe actually fetches.

## What this means for the verdicts

The six WILL NOT BUILD verdicts may still turn out to be right — but they are
right for reasons this recipe has not yet established, and they are justified
by a false premise. Per AGENTS.md, "a reviewer may also reject a recipe whose
flags are all correct but whose stated reason is false: a wrong justification is
a real defect, because it is what makes the next person 'fix' a correct flag."
Here the false premise would send the next person hunting for a tarball-layout
problem that does not exist.

Two real obstacles do exist downstream of the path fix, and the adder found
both — they just need to be re-based on the corrected layout:

1. **`-Werror` is on by default.** `CPP/7zip/7zip_gcc.mak:27`:
   `CFLAGS_WARN_WALL = -Werror -Wall -Wextra`, and it is folded into
   `CFLAGS_BASE` at `:53` and into the compile rule at `:172`. Any warning
   fails the build. This is upstream's default for its supported compilers and
   will need an explicit answer for a newer toolchain.
2. **The compiler is hardcoded.** The dry run shows `cc`, not `$CC`.
   `CPP/7zip/7zip_gcc.mak` uses `$(CC)`/`$(CXX)` with no default, so the
   make-inherited value applies — but the recipe passes **no** `CC=`, so a
   cross build would silently use the host `cc`. This is a genuine
   system-integration defect that only becomes visible once the path is fixed.
3. The mingw-specific items `stage1.md:65` lists (`RC=windres.exe` at
   `7zip_gcc.mak:18`, `resource.rc` at `:270-274`, the `-loleaut32 -luuid
   -ladvapi32 …` link set at `:146`) are independent of the layout question
   and remain valid.

## Required changes

1. **Fix the path** in `generic.lua`: `make -C CPP/7zip/Bundles/Alone2 -f
   makefile.gcc`. Then re-derive every verdict — the tarball supports the
   build, so the rows may move to UNCERTAIN or WILL BUILD.
2. **Pass the system compiler**: `make -C CPP/7zip/Bundles/Alone2 -f
   makefile.gcc CC="$CC" CXX="$CXX"`. `$(CC)`/`$(CXX)` are used by
   `7zip_gcc.mak:1151+`, so the override takes; leaving it out builds host
   objects on a cross system, which is exactly the "no host program compiled
   cross" rule.
3. **Decide `-Werror` explicitly** and record why, in the recipe comment.
4. **Correct `stage1.md`**: delete the flattening claim, the `tar tf |
   grep -c '^CPP/'` → 1092 evidence, and the
   `No rule to make target '../../../../C/7zBuf2.c'` quotation. Replace the
   six rows with what the corrected layout actually does.
5. **Correct `source.lua`'s header comment**, which repeats the flattening
   claim as fact.

If the intent was to drop the package, that is a legitimate call — but it
should be recorded as "not attempted" rather than as an impossible tarball.

## 1. Is it using the SYSTEM?

Not yet, which is part of the defect. No hardcoded triplet or API level, no
`export` of search flags, no `sed`/patch, no fan-out (`make` defaults to
serial). But the recipe passes **no** `CC`/`CFLAGS` at all, so the build takes
the toolchain from whatever `make` finds — a hardcoded target fact by
omission. Once the `CPP/` path is fixed this becomes the live defect, because
`7zip_gcc.mak` compiles with bare `$(CC)`.

## 2. Is it doing what the package needs?

The entry point is upstream's documented one, which is the right instinct:
`CPP/7zip/Bundles/Alone2/makefile.gcc` exists and its include chain
(`../Format7zF/Arc_gcc.mak` → `../../7zip_gcc.mak`) is intact. To the adder's
other question — *does any entry point work, including the `cmpl_*.mak`
files?* — I can now answer directly: the `cmpl_*.mak` files live under
`CPP/7zip/cmpl_*.mak`, i.e. they **are** present (the `cmpl_gcc.mak` was in my
file listing). The concern about "a directory where that file may not exist"
does not arise, because the directory does exist once `CPP/` is intact. The
whole class of problem the adder describes is an artifact of the wrong path.

Also worth recording: the recipe has **no install step**. Even with the path
fixed, `makefile.gcc` produces a local `7zz`/`7za` and nothing copies it into
`$OUT`, so `ninja`-equivalent publication would publish an empty tree. Any
fixed recipe needs an explicit copy, as p7zip's does.

## Other notes

- The `sevenzip` package name is well chosen and the reasoning in `source.lua`
  (avoid a leading digit in a `require()` token) is sound.
- Tarball integrity is fine: 1,552,200 bytes, `tar tf` clean, 1292 entries.

## Forecast

I believe **0 of 6** rows. All six WILL NOT BUILD verdicts are justified by a
premise I have disproved with the tarball in hand. The verdicts may survive on
the `-Werror`/toolchain grounds above, but they are not *this* verdict's
reason, and `stage1.md:40` quotes a diagnostic that cannot be produced by this
tarball.

## Carried to the build

Nothing to carry — this package must not be built as it stands. After the
recipe is fixed, these are the checks that would settle it:

```sh
# The corrected entry point must reach real compile lines. This is the check
# that disproves the flattening claim, and it should run BEFORE any build.
make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc -n 2>&1 | head -5
# expect: mkdir -p _o, then cc/gcc lines naming ../../../../C/*.c

# and the recipe's own path must fail differently:
make -C 7zip/Bundles/Alone2 -f makefile.gcc -n 2>&1 | head -3
# expect: "No such file or directory", NOT "No rule to make target"

# the compiler must be the system's, not the host default:
make -C CPP/7zip/Bundles/Alone2 -f makefile.gcc -n CC="$CC" CXX="$CXX" 2>&1 \
  | grep -c -- "$CC"
# expected: > 0

# if it ever builds, the binary must be copied into $OUT or nothing publishes
test -x "$OUT/bin/7zz" -o -x "$OUT/bin/7za" || echo "MISSING: recipe has no install step"
$OBJDUMP -f "$OUT"/bin/7z* | head -3
```