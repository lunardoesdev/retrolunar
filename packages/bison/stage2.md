REJECT

# bison 3.8.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/bison/`. I did not build.

## Required changes

### 1. `packages/bison/generic.lua:9` and `packages/bison/android.lua:12` — the guard names a file bison does not have

Both files carry the same wrong line:

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/bison/configure.ac
AC_CONFIG_HEADERS([lib/config.h:lib/config.in.h])
$ find nest/source/bison -maxdepth 2 -name '*.in*h*'
nest/source/bison/lib/config.in.h
$ ls nest/source/bison/config.h.in
ls: cannot access ...: No such file or directory
```

Note the name: `config.in.h`, not `config.hin` and not `config.h.in` — a third
variant, and the only one in this shard. `Makefile.in` carries the maintainer
rule `$(top_srcdir)/lib/config.in.h: $(am__configure_deps) → $(AUTOHEADER)`,
which is precisely the re-run the guard exists to prevent.

**Replace the line in BOTH files with:**

```
        touch aclocal.m4 configure lib/config.in.h
```

**This does not fail today's build** — bison is `[x]` and did build, because
`touch` of a missing file in an existing directory exits 0 (verified under the
emitted `set -eu`); it only aborts on a missing *directory*. The guard is
inert, not fatal.

### 2. `packages/bison/android.lua` — it duplicates `generic.lua` exactly

`android.lua` is byte-identical to `generic.lua` apart from the guard. There
is nothing Android-specific in it, and AGENTS.md is explicit: *"`generic.lua`
is a fallback build recipe when the package has no recipe for the requested
system"*, and *"`packages/<name>/android.lua` is found for all of them"*. With
no Android-only content, `generic.lua` alone serves every Android system
through `recipe_fallbacks`, and the second file is a copy that can drift — as
it has.

**Delete `packages/bison/android.lua`.** Change 1 then applies to
`generic.lua:9` alone.

If the adder prefers to keep the file, it must carry the Android-only content
only, and `generic.lua` must lose the `gperf@native` workaround's Android
justification if any. There is none here, so deletion is the clean answer.

### 3. Nothing else is required

`require("gperf@native")` is the correct and only host-tool need: gnulib's
gperf module lists generated `lib/iconv_open-*.h` files in `BUILT_SOURCES`, so
a *host* gperf is genuinely needed to build the target library. `@native`
resolves to the DEFAULT_SYSTEM, which is exactly right for a build-host tool.
bison needs no m4. `make -j1` is serial. The six WILL BUILD verdicts stand, and
`doc/bison.info` ships pre-built in the release so no `makeinfo` is required.

## Carried to the build

- `bin/bison`, `bin/yacc` — `llvm-objdump -f bin/bison | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). `bin/yacc` must be present.
- `share/bison/skeleton.h` — `[ -f share/bison/skeleton.h ]`.
- `info/bison.info` — `[ -s info/bison.info ]`; the release ships it pre-built (≈685 KB), so a small file means `makeinfo` was invoked.
- `share/man/man1/bison.1` — `[ -s share/man/man1/bison.1 ]`.
- No library and no `.pc`; bison is a program. **Never run `bin/bison`.**
- `$PREFIX/bin/gperf` must exist, because `bison@native` needs it — that is the cross-package check worth making here.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- **Required change 1 is done and correct.** `packages/bison/generic.lua:8`
  reads `touch aclocal.m4 configure lib/config.in.h`, and that is the real
  third-spelling template. Verified against the tree, not the adder's comment:

      $ grep -m1 AC_CONFIG_HEADERS nest/source/bison/configure.ac
      AC_CONFIG_HEADERS([lib/config.h:lib/config.in.h])

      $ find nest/source/bison -maxdepth 2 -name '*.in*h*'
      nest/source/bison/lib/config.in.h

      $ ls nest/source/bison/config.h.in
      ls: cannot access ...: No such file or directory

  Guard position is right: `./configure` line 7, guard lines 8-9,
  `make -j1` line 11. bison 3.8.2 is a single non-recursive automake build with
  exactly one `Makefile.in`, at the top level, so the `find` sweep covers
  everything there is.
- **Required change 2 is done: `packages/bison/android.lua` is gone**, which is
  the clean answer this stage2 asked for. `ls packages/bison` now shows only
  `generic.lua`, `source.lua`, `stage1.md`, `stage2.md`. Nothing Android-only
  was lost with it — the only Android-relevant line was the duplicate guard.
- Recipe hygiene is clean: `$AUTOCONF_CONFIGURE_FLAGS`, `$PREFIX`, `$OUT`,
  `$NESTDIR` only; no `export`, no `sed`, no `/dev/null`, no patch,
  `make -j1`. `require("gperf@native")` and `require("bison@source")` both
  resolve; `packages/gperf` exists and `@native` is the right spelling for a
  build-host tool.

### Still wrong

The deletion was not carried through to the forecast, so `stage1.md` now
  describes a file that does not exist and a language that is not in the
  package:

- **`packages/bison/stage1.md:3`** — "Recipe: `generic.lua` **and** `android.lua`
  (byte-identical bodies), source `source.lua`". `android.lua` was deleted by
  this very rework. **Fix:** "Recipe: `generic.lua`, source `source.lua` (no
  platform-specific file)".

- **`packages/bison/stage1.md:27-28`** — "`gperf@native`, not `gperf` is the
  whole trick (`generic.lua:1`, `android.lua:1`)". The `android.lua:1`
  citation is dead. **Fix:** drop it.

- **`packages/bison/stage1.md:11`** — "bison's C++ sources (`src/scan-gram.c`,
  `src/parse-gram.c`, `src/symtab.cc`, `src/tables.cc`) use only libstdc++".
  Two of those four files do not exist, and the two that do are C, not C++.
  Checked:

      $ ls nest/source/bison/src/symtab.cc nest/source/bison/src/tables.cc
      ls: cannot access ...: No such file or directory

      $ ls nest/source/bison/src/ | grep -E '^(symtab|tables)\.'
      symtab.c  symtab.h  tables.c  tables.h

      $ ls nest/source/bison/src/*.cc | wc -l
      0

  The `.cc` count in bison's `src/` is **zero**. bison 3.8 dropped the C++ core;
  `src_bison_SOURCES` (`src/local.mk:28-128`) is entirely `.c`, and the only
  `.cc` files in the tarball are `data/skeletons/*.cc` and
  `examples/c++/*.cc`, which `make all` does not build (`Makefile.am:21`,
  `SUBDIRS = po runtime-po gnulib-po .`). **Fix:** rewrite the row around
  `src/scan-gram.c`, `src/parse-gram.c`, `src/symtab.c`, `src/tables.c` as C
  sources.

- **`packages/bison/stage1.md:5` and `:37-39`** follow from the same error.
  Line 5 says the build system is "C++ for the skeleton compiler, C for the
  tables", and lines 37-39 list "bison's C++ link needs the target libstdc++" as
  a risk. Neither holds for `bin/bison` at 3.8.2: `src_bison_LDADD`
  (`src/local.mk:133-147`) is `lib/libbison.a`, libm, libpthread, librt, libdl,
  libintl and libtextstyle — no `-lstdc++`. This matters beyond tidiness: a
  builder who believes `bin/bison` needs the target libstdc++ will read a
  missing runtime as expected rather than as a defect. The separate claim that
  bison 3.8.2's configure has an explicit `mingw*` branch does check out (178
  occurrences of `mingw` in the generated `configure`).

- Minor drift: `stage1.md:35-36` cites "the comment at `generic.lua:11`" as
  sitting above `make -j1`. The comment is line 10 and `make -j1` is line 11, so
  the observation still holds but the number moved.

### Broken by the rework

Nothing in the recipe. The deletion is the only structural change and it is the
  one this stage2 asked for; the damage is confined to `stage1.md` not being
  updated alongside it.

## Rework verification — summary

Both required changes are correct: the guard names the real `lib/config.in.h`,
  and `android.lua` is deleted as instructed. Rejected because `stage1.md` still
  lists the deleted file as part of the recipe and still describes bison 3.8.2
  as a C++ program — `src/` contains no `.cc` file at all — so the forecast now
  contradicts both the recipe directory and the tree.
