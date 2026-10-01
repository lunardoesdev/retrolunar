# p7zip build forecast — `p7zip`

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 16.02
- Build system: **hand-written GNU make**. No `CMakeLists.txt`, no `configure`,
  no `configure.ac`, no `Makefile.in` in the tree (all four verified ABSENT).
  The chain is `makefile` -> `makefile.common:15` -> `makefile.machine`.
- Requires: `p7zip@source` only (`generic.lua:1`)
- Installs: `bin/7za` only, copied by the recipe. There is no library and no
  header installed.

## Which source, and why

p7zip is a **different project from 7-Zip** — a GNU/Linux port, not Igor
Pavlov's program — and its canonical releases *are* ancient: the original line
stops at **9.20.1 (2009)**. The maintained line is **16.02 (2016)**, which is what
Debian and every current distro build (`p7zip_16.02+really26.01+dfsg` in sid).
This package takes 16.02: it is the only line still receiving updates and the
only one whose C++ builds with a current toolchain.

**Fetch URL.** Upstream's home is SourceForge
(`sourceforge.net/projects/p7zip/files/16.02/p7zip_16.02_src_all.tar.bz2`).
SourceForge's CDN answers **HTTP 522 to this network on every mirror tried**:
`downloads.sourceforge.net`, `master.dl`, `phoenixnap.dl`, `cfhcable.dl`,
`netix.dl`, `gigenet.dl`, the project page, and the RSS feed. All 522, all
zero-length. The recipe therefore uses Debian's `+dfsg` repack of the same
upstream 16.02 tarball, which is reachable. That is a repack, not pristine
upstream; a reviewer who can reach SourceForge should prefer the upstream URL
and note that it is a `.tar.bz2`, which is why `source.lua` does not put it
behind a `|| curl` mirror (one `tar -xJf` cannot serve both formats).

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | Layout is sound: p7zip **keeps** the `CPP/` prefix the 7-Zip 26.03 tarball drops, so `CPP/7zip/Bundles/Alone` exists and `makefile.glb:4-8`'s `-I../../../../C` resolves. Two Android-specific risks remain: the tree has **zero** `__ANDROID__` guards (`grep -rln '__ANDROID__'` over all .c/.cpp/.h → no match), so `CPP/myWindows` and `CPP/7zip/Bundles/Alone` are compiled with no Android awareness at all; and `makefile.android_arm` targets the ancient gnustl NDK r8c toolchain, not an aarch64 clang. Needs a real build to settle. |
| aarch64-android24 | UNCERTAIN | As above. No API-24 gate is implicated: the source never uses `nl_langinfo`, `mktime_z`, `getpass`, `O_BINARY` or `posix_spawn`. |
| aarch64-android35 | UNCERTAIN | As above. |
| x86_64-android35 | UNCERTAIN | As above. x86 selects a different `makefile.*` fragment (`makefile.machine` is arch-neutral but `makefile.linux_amd64` adds `-m64`); see risk 3. |
| x86_64-mingw | UNCERTAIN | The `-DENV_UNIX` define (`makefile.machine:8`) and the `ENV_UNIX` GUI paths are Unix-shaped, and `CPP/7zip/Bundles/Alone` pulls `Common/MyWindows.cpp`, which has `#ifndef _WIN32` branches in the *newer* 7-Zip but is p7zip's own copy here. Needs a build. |
| clang-native | WILL BUILD | The layout is the shape p7zip was written for, `makefile.machine:14-15` uses plain `gcc`/`g++` which is what `clang-native` provides, and target `7za` (`makefile:19`) compiles only `CPP/7zip/Bundles/Alone` plus the C library. No host program is built or run. |

`armv7a-*` and `i686` behave like their aarch64/x86_64 counterparts.

## Risks / what a reviewer should check

1. **`make CC=... CXX=...` overrides are load-bearing, and correct.**
   `makefile.machine:14-15` hardcodes `CXX=g++` / `CC=gcc`. Passing them as make
   *variables* (not `export`) takes precedence over the makefile assignment, and
   `makefile.glb:20-27` folds `$(ALLFLAGS)` — which `makefile.machine:5-11`
   builds — into both compile and link. This is a make-variable override, not
   an `export` of search flags, so it does not violate the build-body rules.
2. **`-DENV_UNIX` matters and is already set** (`makefile.machine:9`); it is what
   selects the POSIX halves of the UI/console code. Do not "clean it up".
3. **`makefile.linux_amd64:6` hardcodes `ALLFLAGS=-m64 …`.** `generic.lua` does
   not select it — it uses the stock `makefile.machine`, which has no `-m64`, so
   the arch comes from the compiler. That is why the x86 rows are UNCERTAIN
   rather than WILL BUILD: if a builder finds `makefile.linux_amd64` gets picked
   up, `-m64` would be a target fact that has to leave the recipe.
4. **`install.sh` is deliberately not used** (`makefile.common:115` -> it runs
   `strip`, `sed`, `chmod`, `find -exec` and writes shell wrappers — all outside
   the allowed build-body verbs). The recipe `cp`s `bin/7za` instead. Note this
   means the binary is **unstripped**; `$STRIP` is not applied. That is a size
   cost, not a correctness one.
5. **`7za` links `-lpthread`** (`makefile.machine:16`). A probe against the NDK
   r28 clang wrappers shows **Bionic has no `libpthread`**:
   `ld.lld: error: unable to find library -lpthread`. `-ldl`
   (`makefile.machine:17`, `LOCAL_LIBS_DLL`) *does* resolve — but `7za` uses
   `LOCAL_LIBS`, not `LOCAL_LIBS_DLL`, so only `-lpthread` is at risk. This is
   the single most likely Android failure and the reason the Android rows are
   UNCERTAIN rather than WILL NOT BUILD: it would be a one-line
   `LOCAL_LIBS=` override in an `android.lua`, but that is a builder's finding to
   make against a real link, not something to pre-empt here.

## API-level notes

**No API gate is implicated.** Grepped the whole tree for the AGENTS.md walls —
`nl_langinfo`, `mktime_z`, `getpass`, `O_BINARY`, `posix_spawn`,
`process_vm_readv`, `mblen`: no meaningful uses. p7zip is a C++ program built on
its own `CPP/myWindows` shim over POSIX, and its file I/O goes through its own
`CPP/7zip/Bundles/Alone` wrappers rather than Bionic directly. The one
confirmed Android problem is the missing `libpthread` above, which is an API
issue in neither direction.