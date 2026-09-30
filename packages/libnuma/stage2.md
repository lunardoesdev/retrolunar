REJECT

# libnuma — stage 2 review

Reviewed against `AGENTS.md`, `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`, and
the real 2.0.19 release asset plus the tag archive (both downloaded — nothing
built).

## What the recipe gets right

- **The load-bearing provenance claim is TRUE, and I verified it independently.**
  The GitHub **release asset** `numactl-2.0.19.tar.gz` ships `Makefile.in`,
  `config.h.in`, `configure`, `aclocal.m4` and `build-aux/`. The **tag
  archive** `archive/refs/tags/v2.0.19.tar.gz` ships `configure` and
  `aclocal.m4` but **no `Makefile.in` and no `config.h.in`**. The two trees
  also differ in content (the tag archive has `fuzz/`, `manlinks/`,
  `numa.spec`, `autogen.sh`, `stream_main.c`, `numastat_diff`, `SECURITY.md`;
  the release asset does not), so they are genuinely different snapshots and
  "just use the tag archive" would be a real regression. `source.lua`'s
  comment is accurate and correctly warns against that "simplification".
- **Config template name is the real one**: `configure.ac:8` is
  `AC_CONFIG_HEADERS([config.h])` and `config.h.in` is at the top level.
  `generic.lua:11` is correct.
- **Guard position correct**; one non-recursive `Makefile.in`, covered by the
  `find`.
- **No `config.status` / `libtool` shipped** (the release-asset listing has
  neither), so omitting them is right.
- **All three install targets the recipe names really exist**, at the exact
  lines stage1 claims: `Makefile.in:862 install-libLTLIBRARIES:`, `:1349
  install-pkgconfigDATA:`, `:1370 install-includeHEADERS:`, `:897 libnuma.la:`.
  I read each body.
- **The `numa.pc` generation works with no separate build step.**
  `Makefile.in:2076` is `%.pc: %.pc.in Makefile` and `install-pkgconfigDATA:`
  depends on `$(pkgconfig_DATA)` = `numa.pc`, so asking for the install target
  triggers the pattern rule. `SED_PROCESS` is defined at `Makefile.in:738`.
  stage1's claim holds.
- **The `bin_PROGRAMS` problem is real and correctly solved.** `Makefile.am:5`
  is `bin_PROGRAMS = numactl numastat numademo migratepages migspeed memhog`,
  there is no `SUBDIRS` at all, so `make` (any target) would build six programs.
  The two-line targeted form is the right answer.
- **Version 2.0.19 is current** (`releases/latest`), URL 200, top dir
  `numactl-2.0.19/` stripped, `dl/` guard + `curl -C -`, lands in
  `$OUT/libnuma/`. `require("libnuma@source")` correct.

## Required changes

1. **`packages/libnuma/stage1.md:109` — a factually wrong claim about the NDK
   that will mislead the builder.** It says for `x86_64-android35`:
   "`syscall.c` has an explicit `#if defined(__x86_64__)` fallback block …
   and on the NDK it *is* unavailable, which is exactly the path that block
   exists for." `<asm/unistd.h>` **is** available on every Android target. I
   compiled `#include <asm/unistd.h>` / `int x = __NR_mbind;` with
   `x86_64-linux-android35-clang`, `aarch64-linux-android24-clang`,
   `armv7a-linux-androideabi24-clang` and `i686-linux-android24-clang` — all
   four succeed. The NDK ships `sysroot/usr/include/<triple>/asm/unistd.h`
   and puts that directory on the default search path (verified with
   `clang -E -v`). `syscall.c:20`'s `#include <asm/unistd.h>` therefore
   resolves and `__NR_mbind` etc. are all defined, so the
   `#if !defined(__NR_mbind) … #error "Add syscalls for your architecture…"`
   block is **never entered** on any Android target.
   Replace stage1.md:109's second and third sentences with:
   "The `#if defined(__x86_64__)` fallback block in `syscall.c:31-135` is dead
   code on every Android target: `<asm/unistd.h>` resolves from
   `sysroot/usr/include/<triple>/asm/unistd.h`, which is on clang's default
   search path, and it defines `__NR_mbind`/`__NR_set_mempolicy`/
   `__NR_get_mempolicy`/`__NR_migrate_pages`/`__NR_move_pages`, so the
   `#error` arm is unreachable. I compiled the include on aarch64, armv7a,
   i686 and x86_64 NDK targets to confirm."
   **The verdict for that row does not change — it still builds — but the
   reason was wrong.**

2. **`packages/libnuma/stage1.md:88-92` — the `AC_SEARCH_LIBS([__atomic_fetch_and_1],
   [atomic])` note says "On a target with no `libatomic`, clang satisfies it
   with a builtin and the search comes back 'none required'".** That is right in
   effect but the mechanism deserves one clause, because it is a *link* probe
   and a wrong guess here would be fatal at configure time. Replace the
   sentence with:
   "`AC_SEARCH_LIBS` is a link test; on aarch64 clang expands a 1-byte atomic
   inline (`ldaxrb`/`stlxrb`) so the probe needs no `-latomic` and returns
   'none required'. If a target ever did need it, `AC_SEARCH_LIBS` would add
   `-latomic` to `LIBS` and every subsequent link would fail, because the NDK
   ships no `libatomic` — so a failure here would appear as a link error
   during `make libnuma.la`, not as a configure error."

3. **`packages/libnuma/stage1.md:130` — the `-Wl,-init`/`-Wl,-fini` note
   claims they are "inert for a static archive" without saying why, and the
   neighbouring text at :109 calls them "ELF-only".** Add the mechanism, since
   it is the single most surprising thing about this recipe: with
   `--disable-shared`, libtool satisfies a `.la` from `archive_cmds` (`ar cru`)
   and **never invokes the linker**, so every `-Wl,…` in
   `libnuma_la_LDFLAGS` (`Makefile.am:44`: `-Wl,--version-script`,
   `-Wl,-init,numa_init`, `-Wl,-fini,numa_fini`) is recorded in `libnuma.la`
   and passed to nothing. If you ever see a link error mentioning
   `--version-script`, the build was not static — check the configure line."

None of these three change what gets built. They are required because a stage1
that asserts a false NDK fact is exactly the document the builder trusts when
the build surprises them, and AGENTS.md asks for forecasts that are honest
rather than plausible.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libnuma.a` | `llvm-nm --defined-only $PREFIX/lib/libnuma.a` shows `T numa_available` |
| `$PREFIX/include/numa.h`, `numaif.h`, `numacompat1.h` | `test -f` all three (`Makefile.am:9`) |
| `$PREFIX/lib/pkgconfig/numa.pc` | `pkg-config --modversion numa` → `2.0.19` |
| `$PREFIX/lib/libnuma.la` | present — `--disable-shared` still installs the `.la` |
| **no** `$PREFIX/bin/numactl`, **no** `$PREFIX/share/man` | `test ! -e $PREFIX/bin/numactl` — this is the check that proves the targeted-install trick worked |

`$PREFIX/lib/libnuma.la` will bake `$OUT` paths; the loader rewrites
`$OUT/lib/*.la` and `$OUT/lib/pkgconfig/*.pc` to `$PREFIX` at
`src/loader.lua:454-458`, so do not be surprised by the rewrite.

## Where the builder is most likely to be wrong

1. **`make -j1 libnuma.la` alone.** If this target ever stops existing or
   starts pulling in more, everything after it fails. It is at
   `Makefile.in:897`. The two `install-*` targets are independent of each
   other but both depend on `Makefile` having been regenerated — which it has,
   because the recipe touches `Makefile.in` after `./configure`.
2. **The `%.pc` pattern rule and `Makefile`.** `numa.pc`'s rule depends on
   `Makefile`, which `config.status` regenerates because the recipe touched
   `Makefile.in`. If a future edit removes the `find ... | xargs touch`, the
   first `make` regenerates `Makefile` and `numa.pc` in the same pass anyway.
   Low risk, but if `numa.pc` comes out empty, the cause is `SED_PROCESS` /
   `@VERSION@`, not the install target.
3. **Static means no `numa_init` constructor.** stage1:70-77 is right and this
   is the real behavioural difference from a distro libnuma: consumers must
   call `numa_available()`. If a consumer misbehaves, this is why — it is not
   a broken build.
4. **armv7a / i686 Android.** stage1 says they "match the aarch64 rows". For
   the library that is now well founded (required change 1 above makes
   `asm/unistd.h` resolve on all of them). For `syscall6`, aarch64 takes
   `#define syscall6 syscall` (no `__GLIBC__`, no `__x86_64__`, no `__i386__`)
   while x86_64 takes the out-of-line inline-asm definition at `syscall.c:170-180`
   — plain AT&T `movq`/`syscall`, no GNU-only directive. Both fine; i686 and
   armv7a take `#elif defined(__i386__)` / the `__arm__` branch respectively.