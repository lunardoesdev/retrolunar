ACCEPT

# ccache 4.14.1 — review

The recipe is right, and the adder's uncomfortable question — is a
compiler cache even a thing a target prefix should hold? — is the most
valuable thing in this batch of seven. It did not paper over it; it flagged
it for a reviewer and marked every Android row UNCERTAIN rather than
inventing a libc reason. That is the correct handling and I am not going to
overrule it.

## Question 1 — is it using the system?

Yes. `cmake -S . -B build $CMAKE_FLAGS` carries the toolchain file,
`-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` and the policy floor from
`packages/aarch64-android24/generic.lua:118-141`. The four `-D` switches
are package policy. No `export`, no hardcoded target fact, no `--host`,
`--parallel 1` written explicitly. Nothing in the recipe names a path.

## Question 2 — is it doing what ccache needs?

Every option verified in the real `CMakeLists.txt`:

| switch | declaration | default | recipe |
|---|---|---|---|
| `ENABLE_TESTING` | `:73` | ON | OFF |
| `ENABLE_DOCUMENTATION` | `:116` | ON | OFF |
| `REDIS_STORAGE_BACKEND` | `:70` | ON | OFF |
| `HTTP_STORAGE_BACKEND` | `:71` | ON | OFF |

All four exist with the defaults stated. `ENABLE_BENCHMARKS` (`:72`, OFF)
and `ENABLE_IPO` (`:52`, OFF) are correctly noted as already off.

**`ENABLE_TESTING=OFF` is mandatory, and the adder is right about why.**
`CMakeLists.txt:136-137` is `add_subdirectory(unittest)` /
`add_subdirectory(test)` under `if(ENABLE_TESTING)`. ccache's suite
executes the freshly built `ccache` against the host compiler; on a cross
target that is an aarch64 binary on an x86_64 host, which the repo forbids
outright. This is not an optimisation.

**One host program is built regardless, and it is harmless.** With
`ENABLE_TESTING=OFF` I still saw `test-lockfile` link, because
`src/ccache/CMakeLists.txt:78` declares
`add_executable(test-lockfile test_lockfile.cpp)` **unconditionally**,
outside any `ENABLE_TESTING` guard. I checked what that costs: it has no
`add_test` and no `install()` rule, so it is built, never run, and never
installed. The recipe is unaffected. Recording it because a builder will
see "Built target test-lockfile" in the log and may read it as the testing
switch having failed — it has not.

**Builds clean and installs exactly one file.** I configured, built and
installed with the recipe's flags:

```
$ find $OUT -type f
bin/ccache
```

No man page (correct — `ENABLE_DOCUMENTATION=OFF` means `doc/` is never
added, `CMakeLists.txt:118`), no library, no `.pc`. `install(TARGETS ccache
DESTINATION ${CMAKE_INSTALL_BINDIR})` at `CMakeLists.txt:124` is the only
install rule in the whole project. stage1's artifact list is accurate,
including its honest note that the absent man page is a functional gap worth
a readme line — I agree it is, and it is the right kind of gap to name.

**Source URL and version.** Resolves (fetched
`releases/download/v4.14.1/ccache-4.14.1.tar.xz`). The releases API returns
`"tag_name": "v4.14.1"` as newest — **current**. Top directory is
`ccache-4.14.1/`, handled by `--strip-components=1`, landing at
`$NESTDIR/source/ccache/`. `cmake_minimum_required(VERSION 3.18)` is well
above the 3.5 floor, so the systems' `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is
inert here.

## One thing stage1 missed, worth knowing before a build

ccache requires **C++20** (`CMakeLists.txt:11-12`,
`CMAKE_CXX_STANDARD 20`). That is a real constraint on the host compiler,
and `clang-native` sets `CXX="clang++"` with no version pin
(`packages/clang-native/generic.lua:9`) — so whether ccache builds on
`clang-native` depends on the host's clang being C++20-capable. The one I
built with here is clang 22.1.8 and it was clean, so that row is fine on
this machine; on an older host it would not be. Not a recipe defect (the
recipe cannot fix a host compiler), and not grounds for a reject, but it is
the concrete thing that would break the `clang-native` WILL BUILD and
`stage1.md` does not name it.

Two more platform notes I checked while I was in the tree, since they bear on
the Android UNCERTAINs: ccache calls `posix_spawn*` unguarded on non-Windows
(`src/ccache/execute.cpp:293-301`, inside `#ifndef _WIN32`) with **no**
configure-time `HAVE_POSIX_SPAWN` probe, and it defines `O_BINARY` to `0`
itself on non-Windows (`src/ccache/util/wincompat.hpp:97`), so the
`O_BINARY` row is fine. `posix_spawn` reached Bionic at **API 28**
(`packages/aarch64-android28/` exists in this tree), which means
`aarch64-android21`, `-24` and `x86_64-android21` have a concrete libc
blocker that the forecast never identifies — it rests on
`src/third_party` C++20 and `<filesystem>` instead. That makes the Android
rows' UNCERTAIN status correct for a **stronger** reason than the one given,
which is the right direction to be wrong in. `aarch64-android35` and the
Android-28-and-up rows are clear of it.

## Forecast

- The five Android UNCERTAINs are **real, not hedging**, and honest in a way
  that is worth crediting: the adder explicitly refused to manufacture a
  libc reason and said so ("they are of questionable value, and I have
  marked them UNCERTAIN rather than inventing a libc reason"). Given the
  `posix_spawn` finding above, they should have been tighter, but they were
  not wrong to be uncertain.
- The `clang-native` WILL BUILD is **not optimism** — I built and installed
  it, exit 0, one artifact.
- **On the adder's open question — should ccache be in this tree at all?**
  My answer: yes, keep it, and the `clang-native` row is the whole value.
  The reasoning the adder gives is right — ccache exists to be invoked as
  `ccache <compiler>`, so its real consumer is the machine doing the
  compiling, and a target `ccache` that would wrap an aarch64 compiler has
  no user. But a target prefix is exactly where a build-on-device setup
  *would* want one, so it is not nonsense, and it is not the reviewer's call
  to delete a package. What I would change is not the recipe but the
  expectation: a builder should treat `clang-native` as the row that proves
  anything, and the Android rows as untested.

## Carried to the build

Scoped to ccache's own output so a second package in the prefix cannot
satisfy them. Each filter was checked against the real file list — there is
exactly one file to check, so these are deliberately short.

```sh
# 1. The one artifact.
[ -x bin/ccache ]

# 2. The man page must be ABSENT. Its presence means
#    ENABLE_DOCUMENTATION=OFF was ignored.
[ ! -e share/man/man1/ccache.1 ]

# 3. No library and no .pc -- ccache is a program, full stop.
ls lib 2>/dev/null | grep -c 'libccache'   # expected 0
find . -name 'ccache.pc' | grep -c .       # expected 0

# 4. The bundled remote-storage code stayed out.
llvm-nm --defined-only bin/ccache | grep -c hiredis   # expected 0

# 5. No test binaries anywhere in the prefix. test-lockfile IS built (it is
#    unconditional in src/ccache/CMakeLists.txt:78) but is never installed,
#    so this must be clean.
find . -name 'test-lockfile' -o -name 'unittest' -type d | grep -c .   # expected 0

# 6. NEVER run bin/ccache as a check, on any system. On a cross target it
#    is the forbidden case; on clang-native it is merely pointless.
```

Checks 2, 3 and 5 are all negative assertions with the expected value
stated as **0**, so a builder cannot invert them and fail the correct build.
Check 5's filter was checked against the real target names in
`src/ccache/CMakeLists.txt` and `CMakeLists.txt:136-137` — it matches names
that actually exist in the tree, not names one hopes for.
