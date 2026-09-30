# perl build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 5.44.0 (cpan.org)
- Build system: **neither autoconf nor cmake** — perl ships its own hand-written
  `Configure`. So `$AUTOCONF_CONFIGURE_FLAGS` does not apply *and neither do
  the exported `$CC`/`$CPPFLAGS`/`$LDFLAGS`*, which is why every setting is
  forwarded by hand as a `-D` option. The recipe says so at `:6-9`, and it is
  the clearest statement of that rule in the shard.
- Installs: `bin/perl`, `bin/cpan`, the full core module tree
  (`lib/perl5/5.44/core_perl/` and `site_perl/` under **`$PREFIX`**, not
  `$OUT`), man pages under `$OUT/share/man/`. No library, no `.pc`.
- Requires: `perl@source` only.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **UNCERTAIN** | The build is a host-perl mechanism done properly, but three Android-specific facts are unresolved and I cannot settle them by reading. See risks 2, 3 and 4. |
| aarch64-android24 | **UNCERTAIN** | As above. |
| aarch64-android35 | **UNCERTAIN** | As above. |
| x86_64-android35 | **UNCERTAIN** | As above. |
| x86_64-mingw | **UNCERTAIN** | As above, plus perl's Windows port has its own target list. |
| clang-native | WILL BUILD | This is the one system `topackage.md:66` records as actually built: *"built for the NATIVE clang-native system as a static x86-64 perl, which is what a native package is supposed to be. A TARGET aarch64-android perl is still blocked: upstream's Android cross-build requires a reachable adb/ssh"*. The recipe is written for the native case and works there. |

**API level notes.** Unresolved for the Android rows, and the reason is
interesting: `topackage.md:66` says the Android path is blocked not by an API
symbol but because *upstream's own Android cross-configuration requires a
reachable adb or ssh transport* to install the cross-built perl onto the
device. That is an upstream design choice, not a Bionic gap. So the API level
is not the variable here.

**Risks / what a reviewer should check.**

1. **The `-D` forwarding at `:15-29` is the most complete in the shard and is
   correct.** `sh Configure -des -Dcc="$CC" -Doptimize -Dcppflags -Dldflags` —
   perl's `Configure` ignores the environment, so every one of these is
   necessary. `-Des` answers both `e` (accept defaults) and `s` (silent), which
   is the right invocation for a non-interactive build.
2. **The `-Dprivlib`/`-Darchlib` split to `$PREFIX` instead of `$OUT` is the
   single cleverest thing in this recipe, and the comment explains why at
   `:12-21`.** perl bakes absolute paths for its module search path into the
   binary with no relocation support. `$OUT` is a staging directory deleted
   after publish, so pointing the library paths there would leave the installed
   perl unable to find its own core modules — every consumer would then need
   `PERL5LIB`. The install target stays `$OUT` (binaries are staged and copied
   verbatim) while the module trees name `$PREFIX`, which is where the emitter
   actually publishes them. **The result is a self-consistent perl needing no
   `PERL5LIB`.** This is exactly the reasoning AGENTS.md wants recorded, and it
   is what `intltool` and `libxcrypt` then depend on for their `PERL5LIB`.
3. **The unresolvable question: does `make install` honour `-Dprivlib=$PREFIX`
   and write *outside* `$OUT`?** If it does, those files are written straight
   into `$NESTDIR/<sys>/` **before** the recipe's success publish step
   (`cp -rf "$OUT"/. …`). That would mean a partial or failed build leaves
   half-written module trees in the published prefix — a real violation of the
   "publish only on success" invariant in AGENTS.md:113-116. **What would
   settle it: build it and check whether `$NESTDIR/<sys>/lib/perl5/` exists
   after a deliberately failed build.** This is the single most important open
   question in this file.
4. **`-Dusethreads` and Android.** With it, perl uses pthreads via Bionic's
   libc. Bionic has pthreads at every API level, so this should be fine — but
   combined with the unproven `$PREFIX` module path, the risk is that the
   thread-local `PL_*` structures end up in a place the staged binary cannot
   find. Worth checking `llvm-objdump -s -j .data bin/perl` for a plausible
   `perl5/5.44/core_perl` string pointing at `$PREFIX` and not `$OUT`.
5. **`BUILD_ZLIB=False` / `BUILD_BZIP2=0` at `:23-24`** correctly make perl
   link this prefix's zlib and bzip2 instead of building private copies. Those
   two packages are in the tree. Good.
6. **`cp -r $NESTDIR/source/perl/. .` with the leading dot at `:11` is
   load-bearing**, and the comment says why: perl's `MANIFEST` lists dotfiles
   such as `.dir-locals.el`, and `Configure` aborts with "THIS PACKAGE SEEMS
   TO BE INCOMPLETE" when they are missing. `cp -r src/* .` would omit them.
   Anyone "tidying" that line breaks the build in a confusing way.
7. **The tarball guard at `:15` uses `find . -name 'Makefile.in' -o -name
   'Makefile.pre.in' | xargs touch`** — the AGENTS.md:234 addition of
   `Makefile.pre.in` for python, applied here too. Correct: perl has both.
8. `topackage.md:66` is accurate and, again, unusually precise: it records
   what *was* built (native, static, x86-64) and states plainly that the
   Android cross path is blocked and why. **Not stale.**

**How to verify once built** (native, which is the case that works).

- `bin/perl` exists; `file bin/perl` reports a static x86-64 ELF.
- `lib/perl5/5.44/core_perl/` exists **under `$PREFIX`**, not under `$OUT` —
  that is the check for risk 3, and it is the whole point of the recipe's
  cleverness.
- `llvm-objdump -s -j .rodata bin/perl | grep perl5/5.44` should show
  `$PREFIX`-rooted paths and **no** `$OUT`/mktemp paths. If an
  `/tmp/tmp.XXXX` path appears, the relocation reasoning has failed.
- `bin/cpan` exists; `share/man/man1/perl.1` exists.
- **Do not run `bin/perl`.** It is a target binary on the cross systems, and
  even natively this recipe's output should be verified statically per the
  tree's convention.
- For the Android rows, there is nothing to verify until `topackage.md:66`'s
  adb/ssh blocker is resolved; a build attempt should be expected to fail at
  the cross-install step, not at compile.
