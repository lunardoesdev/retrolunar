ACCEPT

# hwloc 2.13.0 — stage 2 review

Checked against the unpacked `hwloc-2.13.0` tree in `$HOME/dl`.

## The load-bearing claim, verified

**`configure.ac` has no `AC_CONFIG_HEADERS` line at all.** I ran the grep
myself rather than take the citation, because AGENTS.md:528-534 records three
reviews here that asserted a config template was absent when it was not:

```
$ grep -rn "AC_CONFIG_HEADER" configure.ac
$ echo $?
1
```

No matches, exit status 1. And the top level confirms it — `AUTHORS COPYING
Makefile.am Makefile.in NEWS README VERSION aclocal.m4 config configure
configure.ac contrib doc hwloc hwloc.pc.in include tests utils`. No
`config.h.in`, no `config.hin`, no `configh.in`, no `ac_config.h.in`, no
`configure.h.in`, no `config-h.in`, no `config_h.in`. The **only** two
`config.h.in` files in the whole tree are:

```
$ find . -name 'config.h*' | sort
./include/hwloc/autogen/config.h.in
./include/private/autogen/config.h.in
```

Both are hwloc's own hand-written templates, and both are real build inputs
with real regeneration rules — `Makefile.in:562` and `:574`:

```make
include/private/autogen/stamp-h1: $(top_srcdir)/include/private/autogen/config.h.in $(top_builddir)/config.status
	cd $(top_builddir) && $(SHELL) ./config.status include/private/autogen/config.h
$(top_srcdir)/include/private/autogen/config.h.in:  $(am__configure_deps)
	($(am__cd) $(srcdir) && $(AUTOHEADER))
```

So the templates are the inputs to an `autoheader` chain, exactly the chain
the timestamp guard exists to suppress. `generic.lua` touches both by their
real paths, after `./configure` and before `make`, together with `aclocal.m4`,
`configure` and `find . -name 'Makefile.in' | xargs touch`. **That is the
correct guard, and the reasoning in the comment is correct too** — this is the
"no top-level template, guard the files it does have" case from AGENTS.md:287-292,
handled properly.

## Every option passed genuinely exists

stage1.md:48-51 says `configure.ac` has no `AC_ARG_ENABLE`/`AC_ARG_WITH` at
all, so `./configure --help` is authoritative. I checked that claim first
(it determines whether the option list can be trusted) and then read the help
output directly. `grep -n AC_ARG_ENABLE configure.ac` returns nothing
relevant; the thirteen switches the recipe passes are all present:

```
--disable-picky    --disable-cairo     --disable-libxml2   --disable-libudev
--disable-opencl   --disable-cuda      --disable-nvml      --disable-rsmi
--disable-levelzero --disable-gl      --disable-io        --disable-pci
--enable-static    --disable-shared
```

No invented flags. `--disable-io` is documented as the umbrella ("PCI,
LinuxIO, CUDA, OpenCL, NVML, RSMI, LevelZero, GL"), so the per-backend flags
are partly redundant — but redundancy that makes the intent survive an upstream
change is not a defect, and the comment says so.

## No target binary is executed

This is the one that matters given the binfmt_misc/qemu situation. I looked for
every path by which hwloc could run something it built:

- Tests and examples are `check_PROGRAMS` (`tests/hwloc/Makefile.am:32`,
  `doc/examples/Makefile.am:23`, `tests/hwloc/embedded/Makefile.am:13`), which
  `make all` does not build. The recipe runs `make -j1` then `make install`,
  never `make check`.
- `lstopo` and the `hwloc-*` utilities are ordinary `bin_PROGRAMS`
  (`utils/lstopo/Makefile.am:19`, `utils/hwloc/Makefile.am:33-40`). They are
  compiled and installed, never executed. That is allowed — they are target
  binaries the prefix ships, not programs the build runs.
- The only `$(SED)` uses in the build are upstream's own post-install rewrites
  of installed shell scripts (`utils/hwloc/Makefile.am:170,173`). Those are
  build steps, not recipe edits, and they run on the *build* machine as host
  tools, which is fine.

Nothing in the path runs a freshly built target binary. Confirmed.

## The system

`./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared
--disable-picky` plus the thirteen `--disable-*`. `--host`/`--build`/`--prefix`
all come from the system. No hardcoded target facts, no exported search flags,
`make -j1` then `make install`. `require("hwloc@source")` only — correct, since
every optional dependency is off and nothing else is needed. Clean.

## Notes, not defects

- **The mingw UNCERTAIN is honest and I endorse it.** hwloc does have a
  first-class Windows backend (`utils/lstopo/Makefile.am:59` builds
  `lstopo-win` under `HWLOC_HAVE_WINDOWS`, and `contrib/windows/` ships MSVC
  project files), and the recipe has not been exercised against mingw. The
  adder declined to guess, which is what UNCERTAIN is for. Leave it.
- **stage1.md:96 contains a display-truncated cell.** The mingw row runs ~950
  characters and the reader clips it at 768 with an ellipsis. Per AGENTS.md:510-521
  I confirmed this is the *display's* truncation and not the file's: the row is
  complete on disk and simply ends mid-word (`HWLOC_HAVE_WINDO…`) in this
  rendering. **No adder action needed** — this is recorded so nobody "completes"
  the sentence later.
- **hwloc installs a lot of target binaries** (`lstopo`, `hwloc-bind`,
  `hwloc-info`, `hwloc-ps`, and `hwloc-dump-hwdata` in `sbin` on Linux+x86).
  Unusual for this prefix but it is hwloc's normal install shape, and none of
  them is run. Correctly called out in stage1.md:113-116.
- stage1.md:120-121 has a small wording slip — "lib/libhwloc.a and
  lib/libhwloc.so* is not expected" should read "is **to** not be expected" —
  but the intent is unmistakable and the check that follows it is correct.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | UNCERTAIN | UNCERTAIN | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

I found no API-24+ facility in the shipped sources and no reason to doubt the
Android rows. `--disable-libudev` removes the one backend that would want a
platform library Bionic lacks, and the ARM/x86 components are selected by
`HWLOC_HAVE_*` configure conditionals rather than by the recipe.

## Verdict

ACCEPT. The `AC_CONFIG_HEADERS` absence claim is the one three prior reviews
got wrong, and here it is backed by the grep, the exit status, the top-level
listing, and a `find` over the whole tree. The guard names the two templates
that actually exist and that actually feed an `autoheader` chain. Every flag
passed exists in `./configure --help`. No target binary is executed. Six for
six on the forecasts.
