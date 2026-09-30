ACCEPT

# ninja — stage 2 review

## The reported blocker is CONFIRMED, and the "not permanently blocked" framing is CORRECT

I verified both halves rather than taking them on trust:

- `sysroot/usr/include/spawn.h:60-61` declare `posix_spawn` and `posix_spawnp`
  both `__INTRODUCED_IN(28)`.
- I compiled a probe calling `posix_spawn` with the NDK wrappers: **API 24
  fails** (`error: call to undeclared function 'posix_spawn'`), **API 28 and
  API 35 compile**.
- The call is **unconditional**. `src/subprocess-posix.cc:75-96` calls
  `posix_spawn_file_actions_init`, `posix_spawnattr_init`,
  `posix_spawnattr_setsigmask` etc. with no `#ifdef` and no configure-conditional
  fallback — unlike GNU make, which probes and falls back to `fork`/`exec`.

So the divider is **21 and 24 fail, 35 compiles**, and an `android28`-or-later
target unblocks it. The tree has `aarch64-android35` today, so **ninja is
buildable right now** — this is the one "blocked" entry in the shard that is
not actually blocked. That makes the backlog line a category (iii) finding:
stale, and worth correcting before anyone spends time on it.

## What the forecast gets right

- It correctly identifies that ninja 1.13.2 is built by **`configure.py`, not
  autotools and not cmake** — `configure.py` emits a `build.ninja` and the
  recipe runs `ninja -j1`. I confirmed the source URL is the **tag archive**
  (`archive/refs/tags/v1.13.2.tar.gz`) and that the only release *assets* are
  prebuilt binaries (`ninja-linux.zip` and friends) with no source tarball, so
  the tag archive is the correct choice under `AGENTS.md:149-150`. The archive
  contains `configure.py` and `CMakeLists.txt` and **no** `configure` and no
  `Makefile.in`, which is why the autotools guard correctly does not appear.
- `ninja -j1` at `generic.lua:8` is **correctly serialised** — one of the few
  recipes in this shard that gets it right, and the single most likely thing to
  get wrong in a ninja-based recipe.
- The `CFLAGS="$CXXFLAGS"` override at `generic.lua:7` is a **one-command
  environment prefix, not an `export`**, it carries a comment saying why
  (configure.py merges CFLAGS into C++ flags, and the C-only
  `-isystem $SYSROOT/usr/include` would break libc++ include order), and it
  draws from the system's `$CXXFLAGS` rather than hardcoding anything. That is
  the `AGENTS.md:219-222` exception used correctly.
- The mingw row is right for a different reason than Android (ninja's process
  handling is POSIX; no PE equivalent), and the forecast says so rather than
  reusing the API argument.

## One gap the forecast should close

`generic.lua:7-8` needs a **host** `python3` to run `configure.py` and a
**host** `ninja` to run `ninja -j1`, and the recipe requires neither
(`require("ninja@source")` only). The forecast's own risk #1 notes this. It
should be stated as a positive requirement in the recipe, not only as a risk,
because a builder on a host without `ninja` gets a confusing failure at
`ninja -j1`. If this tree wants ninja available in `$NATIVE_PREFIX/bin`, that
needs a self-hosting arrangement, which is out of scope here — but say so.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/ninja` | `test -x $PREFIX/bin/ninja` |
| static, single file | `file $PREFIX/bin/ninja` — a static binary, not a dynamically-linked one needing `$PREFIX/lib` |
| target arch, never executed here | `llvm-objdump -f $PREFIX/bin/ninja \| grep machine` shows the target arch — do not run it |
| the host tooling the build needed | `command -v python3` and `command -v ninja` must both succeed **before** the recipe runs |
| **the check that decides the API gate** | compile a `posix_spawn` probe against the target wrapper — API 24 fails, 28+ does not |