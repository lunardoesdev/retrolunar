REJECT

# intltool — stage 2 review

## The reported blocker is CONFIRMED and correctly classified

`XML::Parser` is a **pure-Perl** module, and the reason it cannot be built
for the target is not "no Perl module" but that `Devel::CheckLib`'s
`assert_lib` **executes** its probe. That probe is a compiled XS object, so
checking it requires running a target binary — which this repo never does
(`AGENTS.md:373-379`, "No emulation, ever"). The result is a toolchain wall,
not a target fact, and `stage1.md` is right to say so.

That part of the forecast stands and does not need changing.

## Required changes

1. **`packages/intltool/generic.lua:12` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

2. **`packages/intltool/generic.lua:10` — the guard touches a `config.h.in`
   that does not exist.** I checked the unpacked tree: intltool 0.51.0 has
   **no `AC_CONFIG_HEADERS` at all**. `configure.ac` contains only
   `AC_CONFIG_SRCDIR` (line 5), `AC_CONFIG_FILES` (line 35) and `AC_OUTPUT`
   (line 45); there is no config header template in the tarball and no
   `config.h.in` on disk.

   So line 10's `touch aclocal.m4 configure config.h.in` **creates a bogus
   empty `config.h.in`**. It is harmless in itself (nothing references it), but
   per `AGENTS.md` a guard must not name a file that does not exist, and a
   reader cannot tell a deliberate no-op from a mistake. Replace line 10 with:

   ```sh
           touch aclocal.m4 configure
   ```

   and append a comment so the omission is clearly deliberate:

   ```sh
           # intltool 0.51.0 has no AC_CONFIG_HEADERS, so there is no config
           # template to touch.
   ```

3. **`packages/intltool/stage1.md` — state the consequence for the builder.**
   The forecast is right that this is blocked, but it should say plainly that
   the blocker is **upstream of any flag**: there is no `--without-xml-parser`
   equivalent to reach for, and the only fixes are running a target binary
   (forbidden) or patching (forbidden). That makes this package *dropped*
   rather than *deferred*, which is a different bookkeeping outcome from
   `less`/`ninja` (where a newer API target would fix it) and should be
   recorded as such.

## What the forecast gets right

- `require("perl@native")` at `generic.lua:1` is correct and is the right
  shape: intltool is a **host** tool (it runs during builds of *other*
  packages), so it must be built for the native system, not the target.
- `generic.lua:8`'s `export PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"`
  is a recipe-local workaround **with a comment saying why** — the native
  perl's compiled-in `@INC` names the build staging dir — which is exactly the
  exception `AGENTS.md:219-222` permits. Same pattern, same comment style, as
  `packages/libxcrypt/generic.lua:8-9`. Good.

## One fragility worth recording

`generic.lua:8` hardcodes the perl core path `5.44`, and
`packages/perl/generic.lua:16-21` also hardcodes `5.44` in six `-D` flags. Those
two must move together. Since `require("perl@native")` already puts the native
perl first on `PATH`, a more robust form would be to read the version rather
than hardcode it — but that is a refactor, not a fix for this review. Note the
coupling in `stage1.md` so a future perl bump does not silently break
intltool (and libxcrypt).

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/intltoolize`, `$PREFIX/bin/intltool-merge` | `test -x $PREFIX/bin/intltoolize` |
| `$PREFIX/share/intltool/pkg.m4` | `test -f $PREFIX/share/intltool/pkg.m4` |
| **the check that decides the package** | `perl -MXML::Parser -e 1` against `$NATIVE_PREFIX` — if this fails, the package is dropped, not retried |
| the guard fix | the build log must contain no `autoheader` invocation |