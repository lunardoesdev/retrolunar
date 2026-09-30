# xml-parser build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.47
- Build system: **perl `Makefile.PL` + make** — an XS module, so the split is
  that `Makefile.PL` and `xsubpp` are *generators* that must run under a
  **native** perl, while the XS sources they emit are compiled by the Android
  cross-compiler into a target `.so`. Neither autotools nor cmake.
- Installs: `lib/perl5/5.44/site_perl/auto/XML/Parser/Parser.so` (the compiled
  XS module) plus `XML/Parser.pm` and its `.bs`/`.c` sources. No `.pc`.
- Requires: `expat` (exists), `perl@native` (exists).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | The recorded blocker, and it is a subtle one — see below. `topackage.md:87` records it as *"blocked, and NOT for the reason first recorded"*. |
| aarch64-android24 | **WILL NOT BUILD** | Same. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | **WILL NOT BUILD** | Same; the blocker is in `Devel::CheckLib`, which is perl-side and target-independent. |
| clang-native | **UNCERTAIN** | `Devel::CheckLib`'s `_findcc` reading `$Config{cc}` and ignoring `$ENV{CC}` is fine natively, because the host compiler *is* the right compiler there. The recipe's `EXPATINCPATH`/`EXPATLIBPATH` point at `$PREFIX` regardless. So the native case may well work — but the module is only *useful* on a target. |

**Blocker, faithfully recorded — and it is the most interesting entry in the
backlog.** `topackage.md:87` says a native perl running `Makefile.PL` is the
correct XS cross-build mechanism and `perl@native` now exists, but upstream's
own `Makefile.PL` cannot complete a cross build: its `Devel::CheckLib` probe is
not cross-aware.

The mechanism, in full:

1. `Devel::CheckLib`'s `_findcc` (`inc/Devel/CheckLib.pm:459`) reads only
   `$Config{cc}` and **ignores `$ENV{CC}`**.
2. So the probe compiles with the *native* perl's x86-64 clang and then tries
   to link the *cross-built* aarch64 `libexpat.a` — which fails with
   *"libexpat.a(xmlparse.c.o) is incompatible with elf64-x86-64"*.
3. Forcing `$Config{cc}` to the cross wrapper makes the probe **link** — but
   `assert_lib` then **executes** the probe (`inc/Devel/CheckLib.pm:404`).
4. Executing it requires running an aarch64 binary on this x86-64 host, which
   is **forbidden outright** (AGENTS.md:373-379), and the host has no
   `qemu-aarch64` registered — which the tree would not use even if it did.

**So this blocker cannot be worked around.** It is not a libc gap, not an API
level, and not a flag problem: it is a configure-time probe in a perl module
that *must execute a target binary to answer its question*. Every available
route — accept the wrong compiler, force the right one, or skip the probe —
either fails the link or requires the forbidden execution.

**API level notes.** None. **No API level fixes this.**

**Risks / what a reviewer should check.**

1. **The recipe encodes the correct architecture and it is worth preserving
   even while blocked** (`:6-12`). It splits the build into native generators
   (`Makefile.PL`, `xsubpp` — using the `perl` on `PATH`, which the loader has
   pointed at `$NATIVE_PREFIX/bin`, and the comment says so explicitly and
   notes "nothing is hardcoded") and cross-compiled XS sources. That is the
   right shape, and the comment's comparison to `gperf@native` in
   `packages/bison` shows it follows an established pattern in this tree.
2. **The three `make`-line overrides at `:21-25` are individually justified and
   collectively load-bearing.** The generated `Makefile` records the *native*
   perl's `-march`/optimisation flags and its x86-64 `CORE` include directory,
   so `OPTIMIZE` and `perl_inc` are reset to target-appropriate values. And
   `to_cflags="-D_I_CRYPT_H=0 -DHAS_UNION_SEMUN=1"` disables two libc-only
   feature macros perl's `CORE/config.h` carries, because Bionic has no
   `crypt.h` or `shadow.h`, and Bionic's `<sys/sem.h>` already provides
   `union semun` which `perl.h` would otherwise redefine. **That is three real
   Bionic facts, each correct, each commented** — this is the quality of
   platform reasoning the rest of the tree should aspire to. It is a shame the
   blocker sits upstream of all of it.
3. **`require("expat")` and `require("perl@native")` are both correct and both
   necessary** — expat is the C library the XS module wraps, and `perl@native`
   is the generator interpreter. Confirmed both exist in `packages/`.
4. **The blocker is in `inc/Devel/CheckLib.pm`, which is bundled inside the
   XML::Parser sdist** — so it is not something the tree can substitute. That
   is worth stating explicitly, because a reader might otherwise assume
   `Devel::CheckLib` is a separately-installable module that could be replaced.
5. **`PERL5LIB` at `:20`** is the same fix `intltool` and `libxcrypt` use, for
   the same reason (the native perl's compiled-in `@INC` names the build staging
   dir). Consistent across the tree — good.
6. **If this is ever unblocked, the only honest route is upstream**:
   `Devel::CheckLib` gaining cross-awareness, or XML::Parser dropping the
   `CheckLib` probe. A local patch is forbidden by AGENTS.md:28-29. Worth
   recording so nobody burns time looking for a recipe-level workaround.
7. `topackage.md:87` is accurate and its framing — *"blocked, and NOT for the
   reason first recorded"* — is unusually good practice: it records that the
   earlier diagnosis was superseded. **Not stale.**

**How to verify once unblocked** (nothing to verify today; the build stops in
`Makefile.PL`).

- `lib/perl5/5.44/site_perl/auto/XML/Parser/Parser.so` exists under
  `$PREFIX` — note it is under `site_perl`, and that is because `perl`'s recipe
  deliberately points `sitelib` at `$PREFIX` (see the `perl` forecast, risk 3).
  These two recipes are coupled and should be built together.
- `Parser.so` must be an **aarch64** shared object:
  `$OBJDUMP -f` shows `aarch64`. A `x86-64` object here would mean the XS
  sources were compiled with the native compiler, which is the *other* half of
  the recorded failure.
- `llvm-nm -u …/Parser.so | grep -cw XML_ExpatParse` must be **non-zero**,
  proving it links against this tree's expat.
- The build log must contain neither `incompatible with elf64-x86-64` (wrong
  compiler) nor any attempt to *run* the CheckLib probe (the forbidden
  execution). Both strings are the blocker's two faces.
- **Never** let a CheckLib probe execute. If the log shows one being run, stop
  the build.
