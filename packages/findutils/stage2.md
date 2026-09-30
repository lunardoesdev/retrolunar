ACCEPT

# findutils 4.10.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/findutils/`. I did not build.

## What the recipe gets right

- **The guard is correct** — verified against the real unpacked tree:
  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/findutils/configure.ac
  AC_CONFIG_HEADERS([config.h])
  $ ls nest/source/findutils/config.h.in
  nest/source/findutils/config.h.in
  ```
  `config.h.in` is genuinely the right file here. That is a minority in this
  shard, where sixteen of the autotools recipes guard a template the project
  does not have (see `packages/coreutils/stage2.md` for the full list), so it
  is worth stating plainly.
- `./configure $AUTOCONF_CONFIGURE_FLAGS` with no extra flags is right: a
  package with no dependencies needs none, and nothing is hardcoded to a
  target. `make -j1` / `make -j1 install` are serial.
- `require("findutils@source")` names no missing package.
- There is no `android.lua`, and that is correct rather than an omission: no
  flag can work around a missing libc symbol, so there is nothing
  Android-specific for such a file to carry.

## The forecast is right

`mktime_z` is a genuine API-level gate, exposed by Bionic only at API 35. So
this package builds on `aarch64-android35`, `x86_64-android35` and
`clang-native`, and not below — which is a different situation from
`<stdbit.h>` (diffutils) or `argp.h` (elfutils), where no API level helps
because the header is simply not shipped.

## One backlog note (category iii, not a recipe defect)

`topackage.md` records "blocked: needs mktime_z, Bionic exposes it at API 35".
That is accurate, but in a list full of blockers the two kinds read alike and
lead people to opposite conclusions. Sharpen it to:

```
- [ ] Findutils 4.10.0 (blocked below Android API 35: needs mktime_z, which
  Bionic introduces at API 35. android35 exists, so this is an API-level
  blocker and android35 should build it - unlike diffutils' <stdbit.h> and
  elfutils' argp.h, which no API level fixes)
```

`stage1.md`'s per-system verdicts already draw the distinction; the backlog
line should match them.

## Carried to the build

Buildable on `aarch64-android35`, `x86_64-android35` and `clang-native` only.

- `bin/find`, `bin/xargs`, `bin/realpath` — `llvm-objdump -f bin/find | head -3` → `elf64-littleaarch64`, and `llvm-objdump -p` should name **Android 35**, which is the entire story for this package.
- `bin/find` must be the real `find`, not a link to something else — `[ -L bin/find ]` should be false.
- `share/info/findutils.info` — `[ -s share/info/findutils.info ]`.
- `share/man/man1/find.1` — `[ -s share/man/man1/find.1 ]`.
- No library and no `.pc`; findutils is programs.
- **Never run `bin/find`.** The API level in the ELF note is the check that the `mktime_z` gate was cleared.

## Rework verification

**Verdict: ACCEPT.** First line stays `ACCEPT`.

### Nothing needed changing, and nothing was

This recipe is already correct in every respect the brief asked me to check,
so the adder was right to leave it alone.

### The config template — verified, and `config.h.in` is the right one

The tree has five spellings in circulation (`config.h.in`, `config.hin`,
`ac_config.h.in`, `configure.h.in`, `configh.in`), so this had to be checked
against the real tree rather than the house style:

```
$ grep -n 'AC_CONFIG_HEADERS' nest/source/findutils/configure.ac
50:AC_CONFIG_HEADERS([config.h])
$ ls nest/source/findutils/config.h.in
nest/source/findutils/config.h.in
```

Bare `config.h`, default `config.h.in`, and the file exists. `generic.lua:7`'s
`touch aclocal.m4 configure config.h.in` guards the **real** template — one of
the genuine minority in the tree, as this file already says.

### The guard's position — verified

```
6:        ./configure $AUTOCONF_CONFIGURE_FLAGS --localstatedir="$OUT/var/lib/locate"
7:        touch aclocal.m4 configure config.h.in
8:        find . -name 'Makefile.in' | xargs touch
9:        make -j1
10:       make -j1 install
```

After `./configure` (line 6), before `make` (line 9). The tree's standard
three-part shape: touch the autotools inputs so they are newer than the
generated `Makefile`s, then touch every `Makefile.in` so `make` does not try
to re-run automake on a prefix that ships 1.18 rather than the 1.17 the
tarballs name. Correct, and in the conventional order.

### `mktime_z` / android35 — confirmed against the NDK, and stage1.md says it precisely

The brief asked for the floor to be stated exactly, so I read the header
rather than trusting the transcript. NDK r28b sysroot,
`usr/include/time.h:171`:

```c
time_t mktime_z(timezone_t _Nonnull __tz, struct tm* _Nonnull __tm) __INTRODUCED_IN(35);
```

`__INTRODUCED_IN(35)` verbatim. `stage1.md` states this correctly and with
the right precision:

- `:11` android21 — WILL NOT BUILD, 21 < 35
- `:12` android24 — WILL NOT BUILD, 24 < 35
- `:13` android35 — **WILL BUILD**, "At exactly 35 the symbol is declared"
- `:14` x86_64-android35 — WILL BUILD, "arch-independent"
- `:15` x86_64-mingw — WILL NOT BUILD, for a *second, independent* reason
  (mingw has no `mktime_z` and no `timezone_t` at all)
- `:16` clang-native — WILL BUILD, glibc has it unconditionally

`:20-22` names 35 as the floor and ties it to `time.h:171`. android35 is
exactly the floor and is called out as the one Android row that works. That is
precise, and it is the distinction `stage2.md:29-35` asks for: findutils'
blocker *is* API-level, unlike diffutils' `<stdbit.h>` or elfutils' `argp.h`
where no API level helps. Nothing to correct.

### Damage check

- `./configure $AUTOCONF_CONFIGURE_FLAGS` plus one flag,
  `--localstatedir="$OUT/var/lib/locate"`, which is `$OUT`-derived, not a
  target fact, and is the documented reason for `updatedb`/`locate` to keep
  their database inside the stage (`stage1.md:34-39`).
- `make -j1` / `make -j1 install` — serial.
- `require("findutils@source")` names a real package.
- No `export` of search flags, no `sed`/`patch`/`/dev/null`, no
  `config.status` clobbering, no per-target copy.
- Correctly no `android.lua`: nothing Android-specific can be fixed by a flag
  when the gap is a missing libc declaration, as this file says.

### Target-binary execution

Not applicable and not attempted — no program of the target's own is run
during the build, and the man pages ship pre-built in the tarball.
