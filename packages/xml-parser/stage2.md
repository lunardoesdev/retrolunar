REJECT

# XML::Parser 2.47 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

**The blocker analysis in `stage1.md` is the best in this shard and needs no
change** — see the end of this review for why. The one defect is a single
hardcoded flag on the make line.

## Required changes

### 1. `packages/xml-parser/generic.lua:25` — `OPTIMIZE="-O2 -fPIC"` hardcodes flags the system already provides

```
        make CC="$CC" LD="$LD" OPTIMIZE="-O2 -fPIC" \
            perl_inc="$NATIVE_PREFIX/lib/perl5/5.44/core_perl" \
            to_cflags="-D_I_CRYPT_H=0 -DHAS_UNION_SEMUN=1"
```

The line already does the right thing twice — `CC="$CC"` and `LD="$LD"` take
the system's toolchain — and then hardcodes the optimisation flags anyway. The
Android systems export `CFLAGS="-O2 -fPIC -I$PREFIX/include -DANDROID -isystem
$SYSROOT/usr/include"`
(`packages/aarch64-android24/generic.lua:64-66`), so `-O2 -fPIC` is a **stale
copy of the system's own defaults** that silently drops `-DANDROID` and the
sysroot `-isystem`. The moment the systems change their optimisation level,
this recipe keeps the old one and nothing reports it.

**Replace `OPTIMIZE="-O2 -fPIC"` with `OPTIMIZE="$CFLAGS"`**, and extend the
comment at lines 17-22 to note that the whole make line takes its values from
the system — `$CC`, `$LD` and now `$CFLAGS` — with only `perl_inc` and
`to_cflags` being package-local corrections, each for a stated Bionic reason.

This is a one-word fix and the same class of finding as `vim`'s hardcoded
`--host`, just smaller: a target fact written into a recipe instead of read
from the system.

### 2. Nothing else is required

## What the recipe gets right, and should be preserved as written

- **The native-generator / cross-compiler split at lines 8-15 is the right
  architecture for an XS module**, and the comment says why: `Makefile.PL` and
  `xsubpp` are *generators* that must run under a native perl, while the XS
  sources they emit are compiled by the target compiler. `require("perl@native")`
  is the correct declaration, and the comment's explicit note that "the loader
  exports `NATIVE_PREFIX` and puts it on `PATH`, so `perl` here is the native
  one; nothing is hardcoded" is exactly the reasoning AGENTS.md wants recorded.
  Its comparison to `gperf@native` in `packages/bison` is apt — same shape, same
  reason.
- `require("expat")` is the C library the module wraps and exists in `packages/`;
  `EXPATINCPATH=$PREFIX/include EXPATLIBPATH=$PREFIX/lib` are *search* paths
  pointing at the prefix, which is correct.
- **`to_cflags="-D_I_CRYPT_H=0 -DHAS_UNION_SEMUN=1"` is a package-local
  workaround with a proper reason**, and this is where the forecast's count goes
  wrong in the recipe's favour: there are **two** macro overrides, not three.
  Each is justified by a concrete Bionic fact stated in the comment — no
  `crypt.h`, no `shadow.h`, and `<sys/sem.h>` already providing `union semun`
  which `perl.h` would otherwise redefine. That is the sanctioned exception, used
  correctly.
- `export PERL5LIB=...` points at the native perl's `CORE` include tree. This is
  an `export` in a recipe, but not of `CPPFLAGS`/`LDFLAGS`/`CFLAGS`, and it
  exists because the native perl's compiled-in `@INC` names a build staging dir.
  `stage1.md:76-78` notes `intltool` and `libxcrypt` do the same for the same
  reason, which is the consistency argument that makes it acceptable.

## The blocker is correctly recorded and unrecoverable here

`stage1.md` and `topackage.md:87` agree, and the analysis is sound: upstream's
own `Makefile.PL` uses `Devel::CheckLib`, whose `_findcc`
(`inc/Devel/CheckLib.pm:459`) reads only `$Config{cc}` and ignores `$ENV{CC}`.
Accepting the wrong compiler fails the link against the cross-built
`libexpat.a`; forcing the right one makes `assert_lib`
(`inc/Devel/CheckLib.pm:404`) **execute** the probe, which needs a target
binary on the build host — forbidden outright by AGENTS.md, with no emulator
permitted.

So the correct verdict for every cross row is **WILL NOT BUILD**, and the
correct disposition is *blocked pending upstream*, not "needs a recipe fix".
`stage1.md:79-82` says exactly that, and `topackage.md:87`'s framing — "blocked,
and NOT for the reason first recorded" — is unusually good practice: it records
that the earlier diagnosis was superseded. **Not stale; leave it.**

The forecast's own risk list is also right that `Devel::CheckLib` ships *inside*
the XML::Parser sdist, so it cannot be substituted.

## Carried to the build

Nothing is buildable today; the build stops inside `Makefile.PL`. After change 1
and once the blocker is resolved upstream, on an Android target:

- `lib/perl5/5.44/site_perl/auto/XML/Parser/Parser.so` — `llvm-objdump -f` on it must show **`aarch64`**. An `x86-64` object here is the other half of the recorded failure: the XS sources were compiled with the native compiler.
- `lib/perl5/5.44/site_perl/XML/Parser.pm` — `[ -f lib/perl5/5.44/site_perl/XML/Parser.pm ]`. Note the `site_perl` path, not `site_lib`; `perl`'s recipe deliberately points `sitelib` at `$PREFIX`, so **these two recipes are coupled and should be built together**.
- `llvm-nm -u …/Parser.so | grep -cw XML_ExpatParse` → **non-zero**, proving it links this tree's expat.
- The build log must contain **neither** the string `incompatible with elf64-x86-64` (wrong compiler) **nor** any attempt to *run* the CheckLib probe. Both are the blocker's two faces. If a probe is executed, stop the build.
- **Never** let a CheckLib probe execute, and never load the resulting `.so` on the build host.
