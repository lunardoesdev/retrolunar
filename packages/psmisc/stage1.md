# psmisc build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 23.7 (SourceForge `.tar.xz`)
- Build system: autotools
- Installs: `bin/fuser`, `bin/killall`, `bin/pkill`, `bin/peekfd`, `bin/prlimit`,
  `bin/pwdx`, `bin/slabtop`, `bin/uname`, the `misc` terminfo entry, and the
  `xkill`/`xdviinfo` scripts. No `.pc`.
- Requires: `psmisc@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `topackage.md` records: *"blocked: Android cross link leaves rpl_malloc and rpl_realloc undefined"*. This is a **link-time** failure, not a compile error: psmisc's configure detects that `malloc`/`realloc` are not usable as declared and substitutes its autoconf `rpl_malloc`/`rpl_realloc` replacements, which are *supposed* to be compiled into a `lib/` object. The cross link leaves them undefined, so the archive is incomplete. |
| aarch64-android24 | **WILL NOT BUILD** | Same. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | **WILL NOT BUILD** | Same, and additionally psmisc's core (`fuser`, `killall`) is built on Linux `/proc` semantics that do not exist on Windows. |
| clang-native | **UNCERTAIN** | The rpl substitution is an autoconf *feature*, not a Bionic artifact: autoconf decides it is needed when the plain `malloc` declaration is missing or unsuitable. On a glibc host the decision normally goes the other way and no rpl symbols are generated, so the native build may well succeed. **What would settle it: whether configure emits the rpl objects at all** — check for `lib/replace.o` or a `rpl_malloc` mention in the generated `Makefile`. |

**Blocker, faithfully recorded.** `topackage.md`: *Android cross link leaves
rpl_malloc and rpl_realloc undefined.* The entry names the two symbols, which
is precise. What it does not say is *why*, and the why is the interesting part:
this is autoconf's replace mechanism firing, which means configure believes
Bionic's `malloc` declaration is somehow unsuitable. Since Bionic's
`stdlib.h` declares `malloc` normally, the most likely cause is a configure
cache answer left over or a test that fails under cross-compilation. **A
reviewer should read `configure.ac`'s `AC_CHECK_FUNCS`/`AC_REPLACE_FUNCS` for
`malloc` before concluding the blocker is irreducible** — the same class of
question the `libxcrypt` stage1 raised about its own flags.

**API level notes.** None. As with `procps`, the blocker is not an API level or
a Bionic symbol gap. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **This is a cross-compilation artifact, not a platform gap, and that
   distinction should be recorded.** autoconf's `AC_REPLACE_FUNCS` exists
   precisely for cross builds. A cache answer (`ac_cv_func_malloc=no` or
   similar) supplied by a system would suppress it — and that would be a
   **system** change, not a recipe change, by the rule at AGENTS.md:206-210
   ("when a rule describes the target system rather than one package … put it
   in `packages/<sys>/generic.lua`"). **That is the one route worth
   investigating**, and it is the same pattern the Android systems already use
   for `ac_cv_func_ffsl` and `gl_cv_func_strcasecmp_works`
   (`aarch64-android24/generic.lua:88-89`). Nobody has tried it for psmisc.
2. **The recipe is a bare `./configure` with no switches** (`:6`), so like
   `procps` it carries no record of why it is expected to fail. A pointer to the
   recorded blocker would help the next reader — the same mild omission noted
   in the `procps` forecast.
3. **`-lm` is not involved here** but `-lrt`-style clock functions might be:
   psmisc's `prlimit` and `fuser` call `clock_gettime` and `getrusage`, both in
   Bionic's libc. No action needed.
4. **A `/proc`-reading package on Android is largely non-functional regardless**
   — `fuser`, `killall` and `slabtop` all read `/proc`, which is restricted for
   an ordinary Android app. Same category as `procps`, `lfs-bootscripts` and
   `less`: staged, not usable. Relevant to whether this is worth unblocking at
   all.
5. `make` at `:9` is not `make -j1` — the usual rule deviation.
6. `topackage.md`'s entry is accurate in naming the symbols. **The omission is
   that it does not distinguish "cross artifact" from "platform gap",** which
   is what would tell a reader whether risk 1 is worth trying.

**How to verify once built.**

- `bin/fuser`, `bin/killall` and `bin/pkill` exist at minimum.
- `file bin/fuser` reports the target machine on a cross system; `$OBJDUMP -f`
  confirms it.
- **The decisive check on a link that succeeded:**
  `llvm-nm --undefined-only bin/fuser | grep -cw rpl_malloc` must be **0**.
  A non-zero result means the rpl object was never linked — which is precisely
  the recorded blocker, and it would produce a binary that looks built but
  cannot link a consumer.
- `grep -rn 'rpl_malloc' $WORK/Makefile` before linking would show whether
  configure generated the replacement at all; that is the cleanest way to tell
  whether risk 1's cache-answer approach is viable.
- `ls $OUT/share/terminfo/` should show `misc`.
- **Do not run any psmisc binary here.**
