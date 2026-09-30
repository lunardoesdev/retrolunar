ACCEPT

# utf8proc 2.9.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- `-DBUILD_SHARED_LIBS=OFF` is the static control the prefix uses everywhere.
- **The comment earns its keep by answering the question a reviewer would
  otherwise have to ask:** "utf8proc compiles its Unicode tables into the
  library, so there is no data to install." utf8proc is the kind of project
  where a reader expects a `share/` data directory and goes looking for a
  missing artifact. Saying up front that the tables are compiled in is what
  stops that.
- Nothing is hardcoded to a target, nothing is `export`ed, no `sed`, no patch,
  no `/dev/null`, and `cmake --build build --parallel 1` is serial. Install
  goes to `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("utf8proc@source")` names no missing package. utf8proc has no
  dependencies, which is why the recipe passes no other `-D` value.

## What the forecast should be careful about

utf8proc has historically offered options beyond the library build — notably
building its two command-line tools (`utf8proc`, `utf8proc_data`) and a
benchmark. Both are **host programs**, and if either is `ON` by default in this
release the recipe would be building target binaries nothing can run, which is
the exact category AGENTS.md forbids. The recipe passes no such switch.

So the one thing `stage1.md` must actually verify against the release tree is
whether those tools default to off. If they do not, the recipe is **missing a
switch** — that would be a genuine recipe defect of the same class as expat's
`xmlwf` and flac's tools, which I flagged in earlier waves. If the release has
removed them or defaults them off, the recipe is complete as written.

This is the single open question in this package, and it is cheap to settle:
list the `add_executable` calls in the release's `CMakeLists.txt` and check
what guards them.

## Carried to the build

- `lib/libutf8proc.a` — `llvm-objdump -f lib/libutf8proc.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libutf8proc.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/utf8proc.h` — `[ -f include/utf8proc.h ]`.
- `lib/pkgconfig/libutf8proc.pc` — `pkg-config --modversion libutf8proc` → `2.9.0`. utf8proc ships a `.pc`, and `lib/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set.
- **The check that settles the open question above:** no `bin/utf8proc` and no `bin/utf8proc_data`. If either is present, the recipe built host programs it should have suppressed, and it must not be recorded as built until a switch is added. This is the check to run first.
- `lib/cmake/utf8proc/utf8procConfig.cmake` — `[ -f lib/cmake/utf8proc/utf8procConfig.cmake ]`, if the release ships one.
- `share/` should contain **no** utf8proc data — the tables are in the archive, and a data directory here means something was expected that should not be.