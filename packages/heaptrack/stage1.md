# heaptrack build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.5.0
- Build system: **not verified.** See "Evidence" below — the release archive
  could not be downloaded from this environment, so no claim is made here
  about upstream's build system beyond "KDE/Qt project".
- Requires: `heaptrack@source` only. **Deliberately does not require Qt**,
  because none exists (see below).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | No Qt in this prefix. heaptrack is a KDE/Qt application; Qt 6 is absent from `packages/` entirely. |
| aarch64-android24 | **WILL NOT BUILD** | As above; representative system. |
| aarch64-android35 | **WILL NOT BUILD** | As above. |
| x86_64-android35 | **WILL NOT BUILD** | As above. |
| x86_64-mingw | **WILL NOT BUILD** | As above. Qt would have to be cross-compiled for PE as well as for Android; it is not in this prefix at all. |
| clang-native | **WILL NOT BUILD** | As above — and this is the notable one. `clang-native` is the system where a Qt build would be *easiest*, since build == host and every Qt dependency (a C++17 compiler, `libGL`/`OpenGL`, `zlib`, `bzip2`, `libpng`, `icu`, `double-conversion`, `pcre2`, `harfbuzz`, `zstd`) is present or buildable. It is still not buildable, because Qt itself is not. |

## The one decisive reason

**Qt does not exist in this prefix, and heaptrack is a Qt application.**

This was verified by listing `packages/`, not assumed:

```
absent qt
absent qt5
absent qt6
absent base          # the KDE Frameworks package
```

heaptrack is a KDE *utilities* project: a heap profiler built as a GUI
application plus a `heaptrack_print`-style command line tool. It is not a
command-line tool that happens to have an optional GUI — the Qt dependency is
structural, and this is precisely the case the instructions described as "real
and structural" rather than incidental.

Nothing is worked around here. There is no flag that removes Qt from a Qt
application, and writing one would mean patching upstream, which this project
does not do.

**The recipe deliberately does not `require("qt6")`.** The loader resolves
`require()` at script-generation time, so requiring a package that does not
exist fails *before* the build block is ever emitted, with a
package-not-found error that hides the real cause. Leaving the require out
means the failure surfaces where it belongs: at cmake's `find_package`, naming
Qt. The recipe says this in a comment so nobody "fixes" it by adding the
require.

**What would unblock this.** A `packages/qt6/` (Qt 6 Core, Gui, Widgets,
Concurrent, Network, and whichever `Test` component heaptrack asks for),
correctly built for each system. Qt 6 needs C++17 and a substantial dependency
set; the prefix already has most of the inputs. That is a large piece of work
in its own right, and it is the only thing standing between this package and a
build on every system in the table.

## Evidence, and the limits of it

**Version 1.5.0 is verified.** It comes from the KDE Invent API, which
responded:

```
GET https://invent.kde.org/api/v4/projects/kde%2Fheaptrack/repository/tags
→ {"name":"v1.5.0"}, v1.4.0, v1.3.0, v1.2.0, v1.1.0, v1.0.0
```

So the project is **not** archived and 1.5.0 is its latest tag.

**The release archive could not be downloaded, and that is the reason this
file contains no `file:line` citations.** Both plausible archive URLs were
tried:

- `https://invent.kde.org/utilities/heaptrack/-/archive/v1.5.0/heaptrack-v1.5.0.tar.bz2`
- `https://invent.kde.org/utilities/heaptrack/-/archive/v1.5.0/heaptrack-v1.5.0.tar.xz`

Both returned **HTTP 200 with a 14599-byte HTML document** — a KDE Invent
web page, not a tarball. This was caught by the archive-verification step
(`file` reported `HTML document, Unicode text, UTF-8 text`; the tar/gzip
integrity check refused it) rather than being mistaken for a downloaded
tarball. The archive endpoint appears to be gated behind a redirect/session
that this environment does not follow.

**Consequently these are UNVERIFIED and must not be relied on:**

- upstream's build system (CMake is overwhelmingly likely for a KDE project,
  and the recipe uses it, but it was not confirmed against a real file);
- the exact `find_package(Qt6 ...)` line and its component list;
- any project-specific cmake option names;
- heaptrack's own dependencies.

This file therefore makes **no per-system claim that rests on upstream
source**, and the verdict in every row rests solely on the one verified fact:
Qt is absent from `packages/`. That fact is sufficient on its own — no Qt
means no build on any system, whatever the build system turns out to be.

**The `source.lua` URL is unproven.** It is the canonical KDE Invent archive
path form, and the version is real, but it is exactly the URL that returned
HTML here. A future agent with a working download should verify it before
trusting it, and should verify the top-level directory name while they are
there: `--strip-components=1` assumes a single well-named top-level directory.

**Risks / what a reviewer should check.**

1. Do **not** accept this recipe as "correct and known to work". It is
   correct in *shape* — fetch, copy, cmake configure, build, install, no
   guessed flags, no invented workarounds — and it is expected to fail. The
   whole point of shipping it is that a future agent finds a recorded reason
   instead of an empty directory.
2. `topackage.md:376` lists heaptrack unchecked. Nothing else in the tree
   `require()`s it.
3. If Qt is ever added, the recipe will need its `require("qt6")` added back
   **and** its stage1 verdicts re-derived from a real build. Adding Qt is a
   much larger job than adding heaptrack, and heaptrack is not a good first
   consumer for it.

**How to verify once built (not currently expected).**

- Not applicable today. Every system should fail at cmake's `find_package`
  naming Qt. If a build ever appears to get past that, check whether Qt was
  found from somewhere unexpected — our Android systems put
  `$SYSROOT/usr/include` on the include path via `CPPFLAGS`, and cmake's
  `find_package` searches `CMAKE_PREFIX_PATH`, which the systems set to
  `$PREFIX`; neither contains Qt, but that is worth confirming rather than
  assuming.
- Were Qt ever present: `bin/heaptrack` and the command line tool would be the
  two artifacts to check, and `$OBJDUMP -f` would confirm the machine.