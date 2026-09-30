REJECT

# texinfo 7.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/texinfo/`. I did not build.

**Adder A's finding #5 is CORRECT, and it is the most useful thing in this
shard: the recipe contains the fix for the recorded blocker, and the backlog
does not know it exists.**

## Required changes

### 1. `topackage.md:81` — the blocker entry is stale and must be replaced with a re-test, not a deletion

It currently reads:

```
- [ ] Texinfo 7.3 (LFS 7.2; blocked: nested tta configure falls back to cc and cannot create executables)
```

That description no longer matches the recipe. `generic.lua:7` pins the nested
build's own tools and path:

```
        PATH="/usr/bin:/bin:$PATH" BUILD_CC=/usr/bin/cc BUILD_AR=/usr/bin/ar BUILD_RANLIB=/usr/bin/ranlib ./configure $AUTOCONF_CONFIGURE_FLAGS
```

and `generic.lua:11` attacks the reconfigure half of the problem directly:

```
        # Keep nested config.status newer to prevent make from reconfiguring native helpers.
        find . -name config.status | xargs touch
```

`$AUTOCONF_CONFIGURE_FLAGS` is `$PATH`-independent, so prefixing `PATH` cannot
shadow the cross compiler, and the top-level configure still cross-compiles
while the nested `tta` subdir builds its native helpers with `/usr/bin/cc`.
That is the correct shape for a project with a nested native build, and it is
documented in a comment.

**Replace the line with** (leave the verdict open until a build says otherwise):

```
- [ ] Texinfo 7.3 (LFS 7.2; UNTESTED since the recipe gained two mitigations for the old
  blocker: generic.lua:7 pins PATH and BUILD_CC/AR/RANLIB to the host tools for the
  nested tta sub-configure, and :11 touches every config.status so make does not re-run
  it. The recorded "nested tta configure falls back to cc and cannot create executables"
  blocker predates both and no longer describes the recipe. Needs one build to settle)
```

Do **not** simply flip it to `[x]` — nothing has been built since the
mitigations landed, and the honest state is "unretested".

### 2. `packages/texinfo/stage1.md` — it must not inherit the stale blocker

If `stage1.md` still reports WILL NOT BUILD with the tta/`cc` reason, it is
reporting a state the recipe has already moved past. It should instead:
claim WILL BUILD on the grounds that both mitigations are present, and name the
`/usr/bin/cc` dependency as the thing to watch. That is a genuine host-tool
dependency, and — like `perl@native` in `xml-parser` or `gperf@native` in
`bison` — it should arguably be a `require("...@native")` rather than a bare
`/usr/bin/cc`, so the build host's toolchain is not assumed to be GCC at a
specific path. Worth raising, not worth failing on.

## What the recipe gets right

- **The top-level guard is correct.** Verified: `AC_CONFIG_HEADERS([config.h])`
  with `config.h.in` at the top level, which is what `generic.lua:8` touches.
  The nested `tta/config.h.in` belongs to the sub-configure, and change 1's
  `config.status` sweep is the right tool for that rather than a second
  `touch`.
- The `find . -name config.status | xargs touch` at line 11 is a genuinely
  good piece of engineering: a freshly generated `config.status` is newer than
  its `Makefile.in`, and make's default rule would otherwise re-run the
  *native* sub-configure, which is the second half of the original failure.
- All build-system flags come from the system. `BUILD_CC`, `BUILD_AR` and
  `BUILD_RANLIB` are automake's own native-build variables being pointed at
  host tools on purpose — that is the documented `--build` half of a cross
  build, not a hardcoded target fact. Nothing names an architecture or API
  level.
- `make` and `make install` at lines 12-13 are bare. **Not a defect**: bare
  `make` is serial by default, which I verified.

## Carried to the build

- `bin/makeinfo`, `bin/tex`, `bin/texi2any`, `bin/texinfo` — `[ -x bin/makeinfo ]` and `[ -x bin/tex ]`. texinfo installs a dozen `*info` programs; all are target binaries.
- `share/info/*.info` — `[ -s share/info/texinfo.info ]`. texinfo **generates** these with its own `makeinfo` at install time, so they are a real build product here, not a shipped file; a missing or empty `.info` means the generation step failed.
- `share/man/man1/texinfo.1` — `[ -s share/man/man1/texinfo.1 ]`.
- `include/` — texinfo installs no headers; the library `libtexinfo.a` exists upstream but is not built by the top-level `make` in this recipe, so record whether `lib/libtexinfo.a` appears.
- No `.pc`.
- **The check that settles this package:** the configure log must show the *nested* `tta` subdir being configured with `/usr/bin/cc` (a host x86-64 compiler) while the top level used the cross wrapper. If `tta` was configured with the cross compiler, the `PATH`/`BUILD_CC` prefix did not take and the old blocker is back.
- **Never run any installed texinfo binary.**
