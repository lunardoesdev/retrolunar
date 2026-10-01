# ccache build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 4.14.1 (`v4.14.1`, the current `releases/latest`)
- Build system: **cmake**
- Installs: `bin/ccache` (the compiler cache daemon), `share/man/man1/ccache.1`
  (only if `ENABLE_DOCUMENTATION=ON`; it is off here, so **no man page**).
  No library, no `.pc`.
- Requires: `ccache@source` only. ccache vendors its third-party code under
  `src/third_party` and pulls nothing from this prefix.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | ccache is the only genuinely *questionable* Android row in this assignment, and the question is not libc but whether a compiler cache belongs in a target prefix at all — see risks. On the libc side it is C++17 over `<filesystem>`, `<string>`, `<vector>`, `<optional>` and POSIX `<unistd.h>`, `<fcntl.h>`, `<sys/stat.h>`, `<dirent.h>`; I found no `nl_langinfo`, `getsubopt`, `scandir`, `argp_parse`, `fread_unlocked` or `mktime_z`. `ENABLE_TESTING=OFF` matters most: `CMakeLists.txt:136-137` adds `unittest/` and `test/`, and ccache's test suite **runs ccache on the build host** — executing it here would violate the no-execution rule outright. |
| aarch64-android24 | UNCERTAIN | Same single question as the API-21 row. |
| aarch64-android35 | UNCERTAIN | Same. |
| x86_64-android35 | UNCERTAIN | Same; ccache has no arch-conditional code that I could find. |
| x86_64-mingw | UNCERTAIN | Same, plus ccache's Windows support is real but I did not check whether it needs anything the mingw system lacks. |
| clang-native | WILL BUILD | Native glibc x86_64. **This is the row that matters.** ccache is a build-host tool by construction — it exists to be invoked as `ccache gcc`, so its natural and near-only consumer is the machine doing the compiling. A target `ccache` that wraps a *target* compiler is of limited use, which is exactly why the Linux candidates list framing matters more here than for the other six. |

## API level notes

**The API level is not the variable; the role of the tool is.** ccache's own
code reaches for nothing gated above API 21. The honest statement is that
ccache is *architecturally* a host program, so the Android rows are not
failing on libc grounds — they are of questionable value, and I have marked
them UNCERTAIN rather than inventing a libc reason.

## Risks / what a reviewer should check

- **The test suite is the real hazard, not the library.** `ENABLE_TESTING`
  defaults **ON** (`CMakeLists.txt:73`) and adds `unittest/` and `test/`
  (`:136-137`). ccache's tests execute the freshly built `ccache` binary
  against the host compiler. On a cross build that is an aarch64 binary on
  this x86_64 host, which the repo forbids outright. `ENABLE_TESTING=OFF` is
  therefore mandatory, not an optimisation. Same reasoning as
  `packages/libnl-3`'s test switch and `packages/texinfo`'s `install-info`.
- **`ENABLE_DOCUMENTATION` defaults ON** (`:116`) and adds `doc/` (`:118`),
  which wants Sphinx on the build host. Turning it off means **no man page
  is installed**, so a consumer gets the binary with no `ccache.1`. That is a
  real functional gap worth a readme line.
- **Two storage backends default ON** and pull bundled third-party code into
  the daemon: `REDIS_STORAGE_BACKEND` (`:70`) and `HTTP_STORAGE_BACKEND`
  (`:71`). Both are off here. A reviewer who *wants* remote storage should
  know that turning one back on also needs its bundled hiredis/curl to build
  for the target.
- **`ccache` as a target program is arguably the wrong artefact for an
  Android prefix.** Unlike the other six packages in this assignment, this
  one is not a library a target program links against — it is a wrapper for
  the *build* machine. Building it for aarch64-android and putting it in that
  prefix gives a binary that would wrap an aarch64 compiler, which nobody
  has. `clang-native` is the row with a real consumer. **I have not
  restructured the recipe for that**, because a target ccache is a legitimate
  thing to want if a device-side build exists — but a reviewer should decide
  whether this package belongs in a target prefix at all, or should be
  restricted to the Linux/native list.

## How to verify once built

- `bin/ccache`
- **No man page** — its absence proves `ENABLE_DOCUMENTATION=OFF` took; if
  `share/man/man1/ccache.1` exists, the flag was ignored
- **No test binaries anywhere under `$OUT`** and no `unittest`/`test` build
  output — this is the check that matters, because those tests would
  otherwise execute the target binary
- `file bin/ccache` → host x86_64 ELF on `clang-native`
- `llvm-nm --undefined-only bin/ccache | grep -c hiredis` → **0**; a
  `hiredis` reference means `REDIS_STORAGE_BACKEND=OFF` did not take
- No library and no `.pc`
- **Never run `bin/ccache`** as a check — it is the program whose execution
  the test suite would trigger, and on a cross target that is forbidden
