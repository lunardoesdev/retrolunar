# intltool build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.51.0
- Build system: autotools (perl scripts, not compiled C)
- Installs: `bin/intltoolize`, `bin/intltool-extract`,
  `bin/intltool-merge`, `bin/intltool-update`, `bin/intltool-check` and
  `share/aclocal/intltool.m4`. No library, no headers, no `.pc`.
- Requires: `perl@native` (exists), `intltool@source`.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (blocked)** | `configure` hard-requires the `XML::Parser` perl module and aborts with `configure: error: XML::Parser perl module is required for intltool`. `xml-parser/` exists in this tree but `topackage.md:87` records it as blocked in turn, so the chain does not close. The failure is in `configure`, before any compilation. |
| aarch64-android24 | **WILL NOT BUILD (blocked)** | Same; `topackage.md:40`. |
| aarch64-android35 | **WILL NOT BUILD (blocked)** | Same. |
| x86_64-android35 | **WILL NOT BUILD (blocked)** | Same. |
| x86_64-mingw | **WILL NOT BUILD (blocked)** | Same; the blocker is a perl module, not a target fact, so it is identical on every system. |
| clang-native | **WILL NOT BUILD (blocked)** | Same. `XML::Parser` is a perl-level dependency, so the native system is no different. |

**Blocker, faithfully recorded.** `topackage.md:40`: *configure hard-requires
the XML::Parser Perl module*, and no perl on the host has it — neither
`/usr/bin/perl` 5.42.2 nor the prefix's native perl 5.44.0. `XML::Parser` is
itself a backlog entry, blocked at `topackage.md:87` for a different and more
interesting reason: its `Makefile.PL` cannot complete a cross build because
`Devel::CheckLib`'s `_findcc` reads only `$Config{cc}` and ignores `$ENV{CC}`,
so the probe compiles with the native x86-64 clang and fails to link the
aarch64 `libexpat.a`. Forcing `$Config{cc}` to the cross wrapper makes the
probe link but then `assert_lib` **executes** it, which needs an aarch64
binary on this x86-64 host — forbidden.

**This is a chain, not a leaf.** intltool → XML::Parser → expat, and the link
in the middle is the one that cannot be made cross-safe without running a
target binary. **No API level fixes it.**

**Risks / what a reviewer should check.**

1. **The workaround still in the recipe is correct and still needed.**
   `generic.lua:9` sets
   `PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"` before `./configure`.
   intltool's compiled-in `@INC` names the build staging dir, so without this
   the native perl cannot find its own core modules. That is a
   `$NATIVE_PREFIX`-relative path with nothing hardcoded — good design, and it
   is the same fix `libxcrypt` uses at its `generic.lua:9`.
2. **`make` at `generic.lua:15` is not `make -j1`.** AGENTS.md:225-229 asks for
   a serial build. intltool's `make` only installs perl scripts, so the
   practical risk is nil, but it is a rule deviation. Worth normalising when
   the package is unblocked.
3. **The source URL is a Debian pool mirror, not upstream** (`source.lua:6-8`),
   and the recipe explains why: upstream's launchpad URL 502s and
   download.gnome.org only carries up to 0.40. The tarball is stated to be the
   unmodified upstream 0.51.0 release. A reviewer should spot-check that if
   this ever gets built.
4. **Blocked ≠ broken recipe.** The recipe itself is well-formed. When
   `XML::Parser` lands, intltool should build; nothing here needs redesign.

**How to verify once unblocked.**

- `bin/intltoolize` and `share/aclocal/intltool.m4` exist.
- `bin/intltoolize --version` must **not** be run under the target — it is a
  perl script and runs fine, but the point is that the whole package is host
  tooling, so verify statically: `head -1 bin/intltoolize` shows `#!/usr/bin/perl`
  and no ELF magic.
- `ls share/aclocal/` shows `intltool.m4`.
- The configure log must contain no `XML::Parser` error. If it does, the
  blocker is still live.
