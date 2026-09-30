# procps build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.0.7 (procps-ng, SourceForge `.tar.xz`)
- Build system: autotools
- Installs: `bin/ps`, `bin/top`, `bin/free`, `bin/kill`, `bin/pgrep`, `bin/pkill`,
  `bin/pmap`, `bin/skill`, `bin/slabtop`, `bin/sysctl`, `bin/tload`,
  `bin/uptime`, `bin/vmstat`, `bin/watch`, `bin/who`, `bin/w`, plus the
  `x`/`sl`/`skins` terminfo entries and library modules. No `.pc`.
- Requires: `procps@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `topackage.md` records: *"blocked: Clang 19 rejects FLT_MIN token-pasting in src/ps/common.h:101"*. That is a **compile-time language error, not a libc gap**, so it is identical on every target — aarch64, armv7a, i686, x86_64 and mingw alike. The NDK r28 clang is a recent clang, so it hits the same diagnostic. |
| aarch64-android24 | **WILL NOT BUILD** | Same. |
| aarch64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | **WILL NOT BUILD** | Same; and additionally procps-ng's `slabtop`/`pmap` read `/proc` and `/proc/slabinfo`, which do not exist on Windows at all. |
| clang-native | **UNCERTAIN** | Same compile error is expected — clang 19 is the host compiler here too, and `FLT_MIN` token-pasting is a C99 removal that affects every target. But the host clang's version should be checked: if `/usr/bin/clang` is older than the NDK's, the native build might get further. **What would settle it: `clang --version` compared against the NDK's.** |

**Blocker, faithfully recorded.** `topackage.md`: *Clang 19 rejects FLT_MIN
token-pasting in `src/ps/common.h:101`.* The classic case is a macro defined as
`##FLT_MIN##` or similar, which is invalid in C99 and later because `FLT_MIN`
is a macro and cannot be pasted. It is a genuine upstream defect against
modern compilers, it predates every C11/C23 tightening, and **no API level and
no Bionic gap is involved** — so unlike `less` or `pkgconf` there is nothing
this tree can change to unblock it. The only fixes are a newer procps-ng (if
upstream has fixed it since 4.0.7) or patching, which AGENTS.md forbids.

**API level notes.** None, and this is the point: the blocker is not a symbol
or an API level, it is a compiler-version issue that applies everywhere.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The recipe is a bare `./configure` with no switches** (`:6`), so it does
   not attempt to address the blocker. That is honest — there is no switch for
   it — but it also means the recipe carries no record of *why* it is expected
   to fail. A one-line comment pointing at the recorded `FLT_MIN` blocker would
   save the next reader the investigation. This is the same class of omission
   as the glog `WITH_UNWIND` false premise the reviewer caught, in milder form:
   the recipe is silent where a pointer would help.
2. **Check whether a newer procps-ng fixes it.** The blocker was recorded
   against 4.0.7; procps-ng has continued to release. **A version bump is the
   only plausible unblock**, and it is cheap to test: fetch a newer tag, look
   at `src/ps/common.h:101`, see whether the token-pasting is gone. This is the
   single most actionable suggestion in this file.
3. **`-lm` matters here in a way it does not for most packages.** `procps`'s
   `free`/`top` use floating point heavily and it is exactly the kind of package
   the Android systems' `-lm` at `aarch64-android24/generic.lua:79` exists for.
   No recipe change needed — but if this package is ever unblocked, that
   dependency should be noted.
4. **A `/proc`-reading package on Android is largely non-functional regardless.**
   Even if it compiled, `ps`, `top`, `free` and `pmap` read `/proc`, which on
   Android is restricted and mostly unreadable by an ordinary app. Same category
   as `lfs-bootscripts` and `man-pages`: staged, not usable. Worth saying
   before anyone spends effort on the unblock in risk 2.
5. `make` at `:9` is not `make -j1` — the usual rule deviation.
6. `topackage.md`'s entry is accurate and names file and line. **Not stale.**

**How to verify once built.**

- `bin/ps` and `bin/top` exist at minimum; the full set from the "Installs"
  line should be there.
- `file bin/ps` reports the target machine on a cross system.
- `$OBJDUMP -f bin/ps` shows the target machine.
- `ls $OUT/share/terminfo/` or `$OUT/etc/terminfo/` shows the `x`, `sl` and
  `skins` entries procps installs — a good check that the install ran to
  completion rather than stopping early.
- **The blocker check: the build log must contain no error at
  `src/ps/common.h` mentioning `FLT_MIN`.** If it does, the blocker is live.
  If a newer version is tried, that specific line is the thing to watch.
- **Do not run `bin/ps`** or any other procps binary here.
