REJECT

# glad 2.0.8 — stage 2 review

Checked against the unpacked `glad-2.0.8` tree in `$HOME/dl`. I installed
Jinja2 into a throwaway venv under `$HOME/dl` and **ran the generator and the
compiles**, because this recipe's build body is short enough to execute
without building the package, and executing it is the only way to settle two
things the forecast asserts.

## Required changes

1. **`generic.lua:31` — the generation command fails immediately: `--loader`
   is in the wrong position.**

   ```
   $ python3 -m glad --out-path=glad-out --reproducible \
       --api=gl:core=3.3,gles2 --loader c
   usage: python -m glad [-h] [--version] --api API [--extensions EXTENSIONS]
                         [--merge] --out-path OUT_PATH [--quiet] [--reproducible]
                         {c,rust} ...
   python -m glad: error: unrecognized arguments: --loader
   ```

   `--loader` is a **subcommand** option (`python -m glad c --help` lists it
   under `{c,rust} ...`), not a global one. The correct order puts `c` first:

   ```
   $ python3 -m glad --out-path=glad-out --reproducible \
       --api=gl:core=3.3,gles2 c --loader
   ... generating feature set FeatureSet(name=gl, info=[gl:core=3.3], extensions=619)
   ... generating feature set FeatureSet(name=gles2, info=[gles2=3.2], extensions=320)
   RC=0
   ```

   The recipe as written dies at step one, before producing anything. stage1.md:121
   prints the same broken command in its "generation command" block, so the
   forecast carries the error too.

2. **`generic.lua:34` — with `--api=gl:core=3.3,gles2`, the generated
   `gles2.c` cannot be compiled, because `glad/egl.h` is never generated.**

   This is the second, independent failure, and it is the one that would have
   bitten immediately after fixing (1). The generated tree is:

   ```
   glad-out/include/KHR/khrplatform.h
   glad-out/include/glad/gl.h
   glad-out/include/glad/gles2.h
   glad-out/src/gl.c
   glad-out/src/gles2.c
   ```

   and `glad-out/src/gles2.c:3275` is `#include <glad/egl.h>`, inside the
   `GLAD_GLES2_USE_SYSTEM_EGL` `#elif`'s `#else` arm. That header is only
   emitted when `egl` is among the requested APIs. The recipe's own comment
   says "no OpenGL headers, no X11, no EGL headers" — but the GLES2 loader
   needs a `getProcAddress` function pointer, and glad's own answer for that
   comes from its EGL header. Compiling it:

   ```
   api 21: fatal error: 'glad/egl.h' file not found
   api 35: fatal error: 'glad/egl.h' file not found
   ```

   **Two fixes, and the recipe must pick one and say which:**

   - **(a) add `egl` to the API list** — `--api=gl:core=3.3,gles2,egl`. I ran
     it: it generates `include/glad/egl.h` and `src/egl.c` alongside the
     others, and the package then genuinely does depend on an EGL header,
     which the comment would have to be rewritten to say. Downside: a third
     source file to compile, and a third profile to reason about on mingw.

   - **(b) compile `gles2.c` with `-DGLAD_GLES2_USE_SYSTEM_EGL`** and take the
     `PFNEGLGETPROCADDRESSPROC` typedef path instead. I probed this and it
     **compiles clean** against `aarch64-linux-android24-clang` (606 KB object,
     no diagnostics), because that arm needs only a function-pointer typedef
     and never includes a header. This is the smaller change and keeps the
     "no EGL headers" claim true. Note the flag then has to be recorded as a
     compile definition a consumer must also define, or `glad/egl.h` will be
     missing from their build too — put it in the generated `glad.pc`'s
     `Cflags:`.

   Either way, the recipe's stated reason for the compile lines is false as
   written, and per AGENTS.md:505-508 that is a defect in its own right.

3. **`python@native` is not a usable dependency today: `packages/python`,
   `packages/jinja2` and `packages/markupsafe` are all REJECTed at stage 2.**

   The forecast does flag "no `stage3.md`" (stage1.md:102-108) and marks all
   six rows UNCERTAIN, which is honest. But it understates the problem: the
   three packages are not merely unproven, they have been **reviewed and
   rejected**:

   ```
   $ head -1 packages/{python,jinja2,markupsafe}/stage2.md
   REJECT   REJECT   REJECT
   ```

   `jinja2` and `markupsafe` install into `lib/python3.13/site-packages` while
   this tree's interpreter is 3.14, so `import jinja2` fails even if the build
   succeeds. glad's entire build body is `python3 -m glad`, so a green
   `python3` on `PATH` is not sufficient — `import jinja2` must also resolve,
   and today it cannot.

   Independently, I confirmed there is **no `python3` in the native prefix at
   all**: `ls nest/clang-native/bin | grep -i '^python'` returns nothing. So
   the forecast's central mechanism — "the loader puts `$NATIVE_PREFIX/bin`
   first, so a bare `python3` is the native one" — currently resolves to
   whatever `/usr/bin/python3` is, and *that* interpreter's site-packages is
   not `$NATIVE_PREFIX/lib/python3.14/site-packages` either. The comment's
   claim that jinja2/markupsafe "land in the native interpreter's own
   site-packages, which is where it looks" is therefore **not true of this
   nest**.

   This is a dependency blocker, not a recipe defect, and it is not the
   adder's to fix — but the recipe cannot be accepted while its only path to a
   working build runs through three rejected packages. Fix jinja2 and
   markupsafe (3.13 → 3.14) and python first, then re-review.

## What the recipe gets right

- **`--reproducible` is genuinely load-bearing and the reasoning is exact.**
  `glad/__main__.py:149-153` (verified by running it — the log line
  `[DEBUG][glad.files]: intercepted attempt to retrieve resource:
  'https://raw.githubusercontent.com/...'` is the `StaticFileOpener` firing)
  selects `glad.files.StaticFileOpener`, whose `urlopen` discards the URL and
  opens the basename out of the package (`glad/files/__init__.py:51-58`).
  Without it the CLI installs `URLOpener` and fetches `gl.xml` from
  `raw.githubusercontent.com` at build time, which AGENTS.md forbids. The
  vendored registries are all present: `gl.xml egl.xml glx.xml wgl.xml vk.xml
  khrplatform.h eglplatform.h`. **Correct, and important.**
- **A host interpreter is genuinely required**, and `@native` is the right
  spelling. Nothing in the generated C is target-specific; the thing that
  *writes* it must run here.
- **Jinja2 and MarkupSafe are the only Python dependencies** —
  `requirements.txt` is exactly `Jinja2>=2.7,<4.0`, and
  `glad/generator/__init__.py:7` imports it. Markupsafe comes in via Jinja2.
  No missing transitive requirement.
- **The generated sources need almost nothing from a host.** `gl.c` compiles
  clean at both API 21 and API 35 against
  `aarch64-linux-android24-clang` (I compiled it: no diagnostics), as does
  `gles2.c` once change (2) is applied. Its include set is `<stdio.h>
  <stdlib.h> <string.h> <stddef.h> <dlfcn.h>` plus its own header; the loader
  selects `<windows.h>`/`LoadLibraryA` under `GLAD_PLATFORM_WIN32` for mingw.
- **`$CC`/`$CFLAGS`/`$AR`/`$RANLIB` all from the system**, and the hand-written
  `.pc` follows the `packages/lua/generic.lua` precedent. `mkdir`/`cp`/`cat`
  are all on the allowed build-body list. No `sed`, no patches.
- **No target binary is executed** — `python3 -m glad` is a host interpreter
  writing text files, and `$CC` only compiles.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL NOT BUILD | UNCERTAIN | **no** |
| aarch64-android24 | WILL NOT BUILD | UNCERTAIN | **no** |
| aarch64-android35 | WILL NOT BUILD | UNCERTAIN | **no** |
| x86_64-android35 | WILL NOT BUILD | UNCERTAIN | **no** |
| x86_64-mingw | WILL NOT BUILD | UNCERTAIN | **no** |
| clang-native | WILL NOT BUILD | UNCERTAIN | **no** |

I move every row from UNCERTAIN to **WILL NOT BUILD**, and not because the
dependency is unproven — because **the recipe as written fails on every
system for reasons internal to itself**, independent of whether python ever
builds:

- `generic.lua:31` aborts with `error: unrecognized arguments: --loader` on
  every system, today, with a working jinja2 installed. I ran it.
- Even with that fixed, `generic.lua:34` fails with
  `fatal error: 'glad/egl.h' file not found` on every system.

UNCERTAIN is the right answer for *"I don't know whether the dependency will
build"*. It is the wrong answer when the recipe's own two commands are known
to fail — that is a determinate WILL NOT BUILD, and calling it UNCERTAIN would
send a builder to look for a toolchain problem that is not there.

## Verdict

REJECT. Two independent, reproducible failures in the build body, both
settled by running the generator rather than by reading it: the CLI flag order
(`--loader` is a subcommand option) and the missing `glad/egl.h` that
`gles2.c` includes. The `--reproducible` analysis and the host-interpreter
reasoning are excellent and should be preserved verbatim. Separately, the
package cannot build until `python`, `jinja2` and `markupsafe` — all three
currently REJECTed — are fixed, and the recipe's claim that `@native` puts a
usable interpreter on `PATH` does not hold in the current nest.
