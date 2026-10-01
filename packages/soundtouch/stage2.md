REJECT

# soundtouch 2.3.3 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

The build system analysis is correct in every particular — CMake, no
generated `configure`, `SOUNDSTRETCH` defaulting ON, every option name
right, every line citation exact. The rejection is one thing: **the version
pin is stale by two upstream releases, and the adder knew it.**

## Required change

**Bump the pin from 2.3.3 to 2.4.1 in `packages/soundtouch/source.lua`
(`version = "2.3.3"` on line 8, and the URL on line 12).**

```diff
-    version = "2.3.3",
+    version = "2.4.1",
...
-          curl -fSL -C - -o dl/soundtouch.tar.gz "https://www.surina.net/soundtouch/soundtouch-2.3.3.tar.gz"
+          curl -fSL -C - -o dl/soundtouch.tar.gz "https://www.surina.net/soundtouch/soundtouch-2.4.1.tar.gz"
```

Then update the `2.3.3` strings in the recipe comment and in
`packages/soundtouch/stage1.md` (the `Version pinned:` line, the
forecast's prose, and the `pkg-config --modversion soundtouch` check, which
should expect 2.4.1).

**No build flag needs to change.** I verified the 2.4.1 `CMakeLists.txt`
and every option the recipe passes exists there under the same name. Only
the line numbers move (all by +3 below `:75`), and no line numbers are
load-bearing in the recipe.

### The evidence

- `2.4.1` is a real, released upstream version, not a pre-release:
  `project(SoundTouch VERSION 2.4.1 LANGUAGES CXX)` at `CMakeLists.txt:2`,
  fetched from the canonical `https://www.surina.net/soundtouch/soundtouch-2.4.1.tar.gz`
  (HTTP 200, 607 365 bytes).
- Nothing newer is published: 2.4.2, 2.4.3 and 2.5.0 all return 404 from
  the same host.
- **The adder's own `source.lua:1-3` names 2.4.1 as a version it examined**,
  and `stage1.md:14-15` says "I checked four official dist tarballs — 2.3.2,
  2.3.3, 2.4.0 and 2.4.1". So the newer release was not missed; it was
  deliberately not chosen, with no reason given.

That is the part that makes this a REJECT rather than a note. A stale pin
that came from overlooking the release is a fixable oversight. A pin
deliberately set below the newest release the author had already found, with
no stated reason, means the adder had information the recipe does not
reflect — and AGENTS.md's whole argument is that the stage files must carry
the reasoning so the next person does not "fix" a correct decision. Here
the decision is recorded nowhere. Worse, it is a downgrade with no upside:
2.4.1 needs no bootstrap either (verified below), so the reason 2.3.3 might
have been chosen — "the newest release that ships the files we need" — does
not distinguish them.

AGENTS.md is explicit that a package's "latest stable upstream release" is
the thing to check when adding it, and the brief lists "version is current"
as part of question 2. Pinning 2.3.3 over an available 2.4.1 fails that.

## The autotools question, answered by inspection — CONFIRMED

I verified the central claim myself on three of the four versions, as
asked:

```
$ for v in 2.3.3 2.4.0 2.4.1; do tar -tzf soundtouch-$v.tar.gz | grep -c '^\./configure$'; done
0
0
0
```

**No generated `configure` in any of them.** Each ships `configure.ac`,
`Makefile.am` and a first-class `CMakeLists.txt`. So the recipe's decision
to use cmake rather than bootstrap autoreconf inside a cross build is
correct, and the `packages/wolfssl/generic.lua` precedent it cites is
apport. This holds for 2.4.1 as well, so the bump above does not reopen the
question.

**The "+ds" contrast is also correct:** Debian's copies are repacks, so
`deb.debian.org` is not a substitute, and the official surina.net tarball is
the right source. `soundtouch_2.4.1+ds.orig.tar.xz` would indeed have been
inacceptable.

**The top-directory comment is correct too** — `tar -tzf … | head -1` gives
`soundtouch/` for all three, not a versioned directory, and
`--strip-components=1` is therefore correct.

## The rest of the build analysis — every citation checks out

All against the **2.3.3** tree, which is what the recipe currently builds:

| claim | file:line | verdict |
|---|---|---|
| `add_library(SoundTouch …)`, no explicit kind | `CMakeLists.txt:23` | confirmed — so `BUILD_SHARED_LIBS=OFF` is what makes it static |
| `option(NEON … ON)` | `:75` | confirmed |
| `option(OPENMP … OFF)` | `:84` | confirmed |
| **`option(SOUNDSTRETCH … ON)`** | **`:112`** | **confirmed — the citation is exact** |
| `option(SOUNDTOUCH_DLL … OFF)` | `:135` | confirmed |
| `cmake_minimum_required(VERSION 3.1)` | `:1` | confirmed |
| `soundtouch.pc` generated then installed | `:159` `configure_file`, `:160` `install(FILES …)` | confirmed |
| CMake package config installed | `:165-171` (export), `:174-186` (config) | confirmed |
| `soundstretch` install rule | `:127-129` `install(TARGETS soundstretch DESTINATION bin)` | confirmed — inside `if(SOUNDSTRETCH)` |
| `SoundTouchDLL` is `SHARED` | `:137` | confirmed |

**"SOUNDSTRETCH defaults ON at `:112`" — confirmed exactly.** And turning
it off is the **correct** call, which the brief asked me to weigh rather than
assume. `soundstretch` is a standalone `add_executable` (`:114-118`) with
its own three sources under `source/SoundStretch/`, linked against
`SoundTouch` but **not** part of the library's target, and installed
separately to `bin` at `:127-129`. It is a command-line transcoder, not a
transcoder *API* — the transcoding capability that a consumer actually wants
is `SoundTouch`'s own `soundtouch::SoundTouch` class and its
`FIFOSamplePipe`/`FIFOSampleBuffer` helpers, all of which stay in the
library. So the brief's worry that "the transcoder is arguably part of the
library" does not hold: what `SOUNDSTRETCH=OFF` removes is a demo CLI, and
keeping it would mean compiling and installing a target executable on a
prefix with no way to run it. `SOUNDTOUCH_DLL=OFF` is likewise right —
`:137` builds it `SHARED`, a Windows-only wrapper with no loader path here.

So every flag in the recipe is correct. The rejection is the version alone,
and that is worth being explicit about so the adder does not go hunting for
a second problem.

## Question 1 — is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF
-DSOUNDSTRETCH=OFF -DSOUNDTOUCH_DLL=OFF`, then `--parallel 1` and
`--install`. No hardcoded target facts, no `export` of search flags, no
per-target recipe. `require("soundtouch@source")` resolves and the tree
lands in `$OUT/soundtouch/`. Correct.

## The forecast

All six rows say WILL BUILD. The reasoning is sound where it is checkable:
`SOUNDSTRETCH=OFF` removes the only host program, `OPENMP` is OFF so no host
OpenMP runtime is pulled in, and `NEON` needs nothing switched off. The
`aarch64` NEON observation in risk 2 is right and I confirmed the mechanism
— `:76-81` only adds `-mfpu=neon` when `NOT CMAKE_SYSTEM_PROCESSOR MATCHES
"^aarch64.*$"`, so on aarch64 it just sets
`SOUNDTOUCH_USE_NEON` and adds no `-march` at all. There is no hardcoded
`-march` to worry about, which is what risk 2 half-suspected; recording that
so it is not re-checked.

Risk 1 is a good note: there is no `configure`, so no config template to
name, and adding `touch config.h.in` would be the inert guard
AGENTS.md:289-292 describes. Correct, and the recipe correctly has no guard
at all.

The forecast's defect is not in the reasoning but in what it chose to pin:
it spent its effort establishing that 2.4.1 was a usable source and then did
not use it.

## Carried to the build

- `lib/libSoundTouch.a` exists; `include/soundtouch/SoundTouch.h` exists
  (`CMakeLists.txt:89-99` installs six headers including the generated
  `include/soundtouch_config.h`).
- `pkg-config --modversion soundtouch` reports the pinned version, and
  `pkg-config --cflags --libs soundtouch` resolves. The `.pc` is generated
  into `$OUT` (`configure_file` at `:159`), so the loader's `$OUT`→`$PREFIX`
  rewrite applies and this check is real rather than formal.
- `$OBJDUMP -f lib/libSoundTouch.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm -C --defined-only lib/libSoundTouch.a | grep -cw
  'soundtouch::SoundTouch'` is non-zero, proving demangled C++ content.
- **`ls $OUT/bin/` must be empty** — `soundstretch` is off. Its install
  destination is literally `bin` (relative, `:128`), so if the switch ever
  regresses it lands in `$OUT/bin` and this catches it. Scoped to `$OUT`, so
  it cannot pass vacuously.
- `test ! -e $OUT/lib/libSoundTouchDLL*` — the DLL wrapper is off.
- A CMake package config exists under `lib/cmake/SoundTouch/`
  (`SoundTouchConfig.cmake`, `SoundTouchConfigVersion.cmake`,
  `SoundTouchTargets.cmake`; `:164-186`). Check the path cmake chose rather
  than assuming, as `stage1.md` itself says.
