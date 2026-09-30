ACCEPT

# diffutils 3.12 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/diffutils/`. I did not build.

**Adder B's finding #4 (diffutils half) is CORRECT on the fact, and the
forecast states it better than the backlog does.** Verified directly:

```
$ find $NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include -name 'stdbit*'
(no output)
$ ls .../sysroot/usr/include/stdbit.h
ls: cannot access ...: No such file or directory
```

No `stdbit.h` anywhere in the sysroot. Compare the genuinely API-level
blockers in the same backlog — `nl_langinfo` (`langinfo.h`,
`__INTRODUCED_IN(26)`), `mktime_z` (API 35), `stderr` (API 23) — each of which
*is* an `__INTRODUCED_IN` gate that a newer `aarch64-androidNN` directory
clears. `stdbit.h` is not gated at all; it simply is not shipped. **No new
Android system directory unblocks diffutils.** Only a newer NDK that adds the
header, or a patch, which the no-patch rule forbids.

Host side, which is what makes `clang-native` the only candidate row:

```
/usr/include/stdbit.h                      exists
/usr/x86_64-w64-mingw32/include/stdbit.h   does not exist
```

So the mingw WILL NOT BUILD is right on its own evidence, independent of the NDK.

## Required changes

### 1. `packages/diffutils/generic.lua:7` — the guard names a file diffutils does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/diffutils/configure.ac
AC_CONFIG_HEADERS([lib/config.h:lib/config.hin])
$ find nest/source/diffutils -maxdepth 2 \( -name 'config.h.in' -o -name 'config.hin' \)
nest/source/diffutils/lib/config.hin
$ ls nest/source/diffutils/config.h.in
ls: cannot access ...: No such file or directory
```

`config.hin`, in a subdirectory — the same trap AGENTS.md names outright, and
the same one `coreutils`, `grep` and `gzip` fall into in this shard.

**Replace line 7 with:**

```
        touch aclocal.m4 configure lib/config.hin
```

**This does not fail the build** — `touch` of a missing *file* in an existing
directory creates it and exits 0 (verified under the emitted `set -eu`; only a
missing *directory* aborts). So the stray `config.h.in` is harmless and the
block continues. The defect is that the guard is **inert**: `lib/config.hin` is
exactly the file whose staleness re-triggers `autoheader` through the `missing`
wrapper, and nothing refreshes it.

### 2. `packages/diffutils/generic.lua:12` — the `touch man/*.1` list must match the tarball

The recipe touches `man/cmp.1 man/diff.1 man/diff3.1 man/sdiff.1`. `touch` on a
file the release does not ship **creates an empty man page**, and because it is
now newer than the binary, `make install` would install a zero-byte `.1`
instead of regenerating it with help2man.

Before this recipe is ever unblocked, check the tarball for those four names
and correct the list to exactly what it ships. This is the one thing in the
recipe that could turn a would-be-working build into a silently broken one,
and `stage1.md` does not raise it.

### 3. `topackage.md:18` — the framing invites the wrong next action

It currently reads:

```
- [ ] Diffutils 3.12 (blocked: src/system.h needs <stdbit.h>, absent in the NDK)
```

Factually accurate, and — unlike the bash line — it does not actually claim an
API level. But the list it sits in is full of API-level blockers, and "absent
in the NDK" reads as "the NDK is too old", which sends someone to a newer NDK
(correct) or to a new API level (pointless). Sharpen it:

```
- [ ] Diffutils 3.12 (blocked: src/system.h needs <stdbit.h>, which is absent from
  the whole NDK sysroot at every API level - this is NOT an API-level blocker, so no
  new aarch64-androidNN system unblocks it. Needs an NDK that ships the header.
  mingw-w64 has no <stdbit.h> either; only clang-native resolves the include)
```

### 4. Nothing else is required

`generic.lua:11` `make -j1 -C src` then `:13` `make -j1` is serial, and the
ordering trick is sound: building `src` first, then touching the man pages,
keeps the shipped `.1` newer than the binaries so help2man is not needed.
`./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system, so
install goes to `$OUT`. `require("diffutils@source")` names no missing
package.

`stage1.md:32-36` already says the man-page guard "is currently untested in
practice. Do not read it as evidence the recipe works" — that is exactly right
and should be kept. Add the one clause change 2 above supplies: it is correct,
and it is untested, and here is what would go wrong.

## Carried to the build

Not buildable on any cross target today. The only candidate row is
`clang-native`, where `/usr/include/stdbit.h` exists — and that row is
`UNCERTAIN`, not WILL BUILD, which is the honest call.

- `bin/diff`, `bin/cmp`, `bin/diff3`, `bin/sdiff` — `llvm-objdump -f bin/diff | head -3`; on `clang-native` the artifact is host x86_64 ELF. A target row would need `elf64-littleaarch64`.
- `share/man/man1/diff.1` — `[ -s share/man/man1/diff.1 ]`. Use **`-s`, not `-f`**: a zero-byte file here is exactly the failure mode of change 2, and it would install silently.
- `info/diffutils.info` — `[ -s info/diffutils.info ]`.
- No library and no `.pc`; diffutils is four programs. **Never run any of them.**

---

## Rework verification

**ACCEPT.** This verdict supersedes line 1, so line 1 has been changed from
  `REJECT` to `ACCEPT`.

### Correctly fixed

- **Required change 1 is done and correct.** `packages/diffutils/generic.lua:7`
  reads `touch aclocal.m4 configure lib/config.hin`, which is the real template:

      $ grep -m1 AC_CONFIG_HEADERS nest/source/diffutils/configure.ac
      AC_CONFIG_HEADERS([lib/config.h:lib/config.hin])

      $ find nest/source/diffutils -maxdepth 2 \( -name 'config.h.in' -o -name 'config.hin' \)
      nest/source/diffutils/lib/config.hin

  Guard position is right: `./configure` line 6, guard lines 7-8,
  `make -j1 -C src` line 11. `find . -name 'Makefile.in' | xargs touch` covers
  all 7, including the four in subdirectories (`doc/`, `gnulib-tests/`,
  `lib/`, `man/`, `src/`, `tests/`).

- **Required change 2 is satisfied without a recipe edit, and I checked it
  rather than assuming.** The review asked for the `touch man/*.1` list to be
  corrected "to exactly what it ships". It already is — all four names exist in
  the release tree and all four are non-empty, so `touch` refreshes real files
  and creates nothing:

      $ ls -l nest/source/diffutils/man/*.1
      2272  cmp.1      6544  diff.1      2869  diff3.1      2892  sdiff.1

      $ grep -n 'dist_man1_MANS' nest/source/diffutils/man/Makefile.am
      dist_man1_MANS = cmp.1 diff.1 diff3.1 sdiff.1

  So the failure mode this stage2 warned about — `touch` creating a zero-byte
  man page that then installs silently — cannot occur here, and leaving the line
  alone was the correct response. The ordering trick also still holds:
  `make -j1 -C src` (line 11) runs before `touch man/*.1` (line 12), so the
  shipped pages end up newer than `src/cmp.c` and help2man is not needed; and
  `man/Makefile.am`'s rule `cmp.1: $S/cmp.c cmp.x` is satisfied by that
  ordering.

- Recipe hygiene is clean: `$AUTOCONF_CONFIGURE_FLAGS`, `$PREFIX`, `$OUT`,
  `$NESTDIR` only; no `export`, no `sed`, no `/dev/null`, no patch,
  `make -j1` throughout (including `make -j1 install`); `require("diffutils@source")`
  resolves and is the only dependency.

- **The blocker is correctly characterised, and I re-verified it.** The NDK r28b
  sysroot really has no `<stdbit.h>` at any API level:

      $ ls $SYSROOT/usr/include/stdbit.h
      ls: cannot access ...: No such file or directory
      $ find $ANDROID_HOME/ndk -name 'stdbit*'
      (no output)

  against `nest/source/diffutils/src/system.h:50`, `#include <stdbit.h>`. For
  contrast the genuinely API-gated symbols really do carry
  `__INTRODUCED_IN` in the same sysroot (`grp.h:56` `getgrent` at 26,
  `langinfo.h:97` `nl_langinfo` at 26, `stdio.h:64` `stderr` at 23,
  `time.h:171` `mktime_z` at 35), which is the distinction the forecast draws
  and gets right. This is the one forecast in the shard whose blocker claim is
  both cited and correct.

### Outstanding, and why it does not change the verdict

- **Required change 3 was not applied.** `topackage.md:18` still reads
  `- [ ] Diffutils 3.12 (blocked: src/system.h needs <stdbit.h>, absent in the NDK)`.
  This stage2 asked for that line to be sharpened to say explicitly that no new
  `aarch64-androidNN` directory unblocks it. I am not permitted to edit
  `topackage.md`, so it is recorded rather than fixed — but note that
  `stage1.md:12-13`, `:18-28` and `:42-44` already carry the sharpened version
  in full, three times, so the package's own forecast is not at risk of sending
  anyone to try API 35. The backlog line is a shared file and a bookkeeping
  item; the recipe and the forecast are both correct.

- `stage1.md:32-36` still says the man-page guard is "currently untested in
  practice" and warns against reading it as evidence the recipe works. That
  warning is still fair (nothing here is built), but the stage2 clause
  explaining what *would* go wrong — a zero-byte `.1` installed silently — was
  not added. It is now moot for 3.12, because the tarball check above shows all
  four names are real files; it would need redoing on a version bump.

- Cosmetic drift: `stage1.md:16` says "The host clang is 19/20-era". On this
  host it is 22.1.8, and `/usr/include/stdbit.h` exists as claimed, so the
  substance of the `clang-native` row is unaffected.

### Broken by the rework

Nothing. One line of recipe was changed (the guard) and it was changed to the
  right value.

## Rework verification — summary

The one recipe defect is fixed and verified against the tree, and required
  change 2 turns out to need no edit: all four man pages the recipe touches are
  real, non-empty files in the release, so the `touch` line cannot manufacture a
  zero-byte page. The `<stdbit.h>` blocker is real, correctly cited, and
  correctly distinguished from the API-level gates. Accepted; the only
  unapplied item is the shared `topackage.md:18` wording, with the sharpened
  version already present three times in this package's own `stage1.md`.
