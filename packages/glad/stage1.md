# glad 2.0.8 — stage 1 build forecast

**Package:** glad
**Version:** 2.0.8
**Upstream:** https://github.com/Dav1dde/glad
**Build system:** none. GLAD2 is a Python package; the C that installs is
whatever `python3 -m glad` writes.

A forecast from reading upstream source. Nothing has been generated, compiled
or configured.

## The main design decision: is there a pre-generated source tree?

**No. This package cannot be built without a host Python, and that is the
whole story of this recipe.**

I checked the v2.0.8 release through the GitHub API
(`https://api.github.com/repos/Dav1dde/glad/releases/tags/v2.0.8`). Its
`"assets"` array is **empty** — the release has no attached `.tar.gz` and no
attached `.zip`. The only downloadable artifacts are the auto-generated
`tarball_url`/`zipball_url` of the git tag, which is the generator source, not
a build of it. There is no `include/glad/*.h` and no `src/glad*.c` anywhere in
that tree: the repository root is `LICENSE MANIFEST.in README.md cmake example
glad long_description.md pyproject.toml requirements.txt test utility`, and
`glad/generator/c/templates/` holds *Jinja templates*, not C. So the release
offers exactly one way to get C, and that is to run the generator.

### Which Python, and does it work offline?

Two questions, both answered from the source:

**1. It must be a host interpreter, so the recipe needs `python@native`.**
`$CC` on a cross system is an Android or mingw compiler; nothing can execute
its output, and AGENTS.md forbids emulation outright. The generated C is
target-independent (it contains only GL type definitions, function-pointer
typedefs and a `dlopen` loader), but the thing that *writes* it has to run on
the build machine. AGENTS.md defines `require("python@native")` as resolving to
the compile-time `DEFAULT_SYSTEM` — `src/main.c:10` sets it to `clang-native` —
and it is an alias, not a separate target system. The loader then prepends
`$NATIVE_PREFIX/bin` to `PATH` for every block (`AGENTS.md`, 'The generated
script'), so a bare `python3` in the build body is unambiguously the native one
and never the target's.

**2. It does work offline, and that is what `--reproducible` is for.** This is
the part that decides whether this package is buildable at all, since
AGENTS.md forbids network access at build time outside `source.lua`.

`glad/__main__.py:149-153`:

```python
if global_config['REPRODUCIBLE']:
    opener = glad.files.StaticFileOpener()
    gen_info_factory = lambda *a, **kw: GenerationInfo.create(when='-', *a, **kw)
else:
    opener = URLOpener()
```

The default `URLOpener` fetches `gl.xml` from
`raw.githubusercontent.com/KhronosGroup/OpenGL-Registry/…`
(`glad/specification.py:12,` combined with `glad/parse.py:267-269`). That is
build-time network access and is forbidden. `StaticFileOpener`
(`glad/files/__init__.py:51-58`) instead throws the URL away and opens the
basename out of the package:

```python
filename = urlparse(url).path.rsplit('/', 1)[-1]
return open_local(filename, 'rb')
```

And the release **vendors every registry that the GL specification needs**:
`glad/files/` contains `gl.xml`, `egl.xml`, `glx.xml`, `wgl.xml`, `vk.xml`,
`khrplatform.h`, `eglplatform.h` and the `vulkan_video_*` headers. The
additional Khronos headers the C generator writes out are fetched through the
same opener (`glad/generator/c/__init__.py:_read_header`), so `KHR/khrplatform.h`
also resolves offline. `--reproducible` additionally pins the generation
timestamp to `'-'`, which makes the output byte-stable across runs — worth
having for a recipe whose output is otherwise regenerated every build.

`--reproducible` is therefore load-bearing, not a nicety. Without it this
package cannot be built in this tree at all.

### Dependencies, and do they exist?

`requirements.txt` and `pyproject.toml` both list exactly one dependency:
`Jinja2>=2.7,<4.0`. `glad/generator/__init__.py:7` imports it.

- `require("jinja2@native")` — `packages/jinja2/` **exists**. Its recipe is a
  pure-Python copy into `site-packages` with a comment saying LFS would use pip
  and that only the module is used.
- `require("markupsafe@native")` — `packages/markupsafe/` **exists**, and is
  also a pure-Python copy. This matters: MarkupSafe ships an optional `_speedups`
  C accelerator, and the recipe explicitly does not build it, falling back to
  the `_native.py` implementation. So there is no target-compiled `.so` to
  worry about and the module is architecture-independent — which is exactly why
  `@native` is safe here.
- `require("python@native")` — `packages/python/` **exists**, but see the
  caveat below.

Both land in `$NATIVE_PREFIX/lib/python3.14/site-packages`, which is the
native interpreter's own site-packages, so `import jinja2` resolves.

**The caveat I want a reviewer to see:** `packages/python/` has `source.lua`,
`generic.lua`, `stage1.md` and `stage2.md` — there is **no `stage3.md`**, so
there is no build record proving CPython 3.14.7 has ever been built in this
tree. It is the only one of GLAD's four dependencies without a stage3, and it
is by far the heaviest (its recipe also requires `readline`). Every verdict in
the table below is therefore conditional on that build working. If it does not,
GLAD fails at the generation step and nothing else in this recipe is at fault.

Nothing else is required: `find_generators()` and `find_specifications()` both
fall back to hardcoded defaults when no package metadata is installed
(`glad/plugin.py:25-46` — `DEFAULT_GENERATORS = dict(c=CGenerator,
rust=RustGenerator)`, and `DEFAULT_SPECIFICATIONS` is built by inspecting
`glad.specification`), so the generator does **not** need to be pip-installed.
That is what keeps this buildable without `pip`, which `packages/python` does
not provide anyway (`--without-ensurepip`).

## The generation command

```
python3 -m glad --out-path=glad-out --reproducible --api=gl:core=3.3,gles2 --loader c
```

| Flag | Reason |
| --- | --- |
| `--reproducible` | Offline + deterministic. See above. Without it this build attempts network access at build time. |
| `--api=gl:core=3.3,gles2` | Desktop GL core for `x86_64-mingw` and `clang-native`, GLES2 for Android. Both pinned explicitly: "no version" means *latest* (`glad/__main__.py:88-96`). Neither profile is optional — `gl:core` needs its profile, `gles2` has none available (`glad/parse.py:668-682`). |
| `--loader` | Emits glad's own `dlopen`-based loader (`glad/generator/c/templates/loader/gl.c:36-52`). Without it the generated source declares the function-pointer table but leaves `gladLoadGLLoader()` for the consumer, and there is no other loader in this prefix. |
| `c` (subcommand) | The C generator. `subparsers.default = 'c'` (`glad/__main__.py:82`) so it is optional; passed explicitly for readability. |

**Output layout** is fixed by the generator, not chosen by us:
`glad/generator/c/__init__.py:397-399` writes
`include/glad/<name>.h` and `src/<name>.c`, where `<name>` is the API string
(`glad/parse.py:780`). So the run above produces:

```
glad-out/include/glad/gl.h        glad-out/src/gl.c
glad-out/include/glad/gles2.h     glad-out/src/gles2.c
```

plus whatever Khronos headers the selected API pulls in
(`glad/generator/c/__init__.py:_add_additional_headers` writes them under
`include/<header.include>`, i.e. `include/KHR/khrplatform.h`). The recipe
copies `glad-out/include/.` wholesale rather than naming files, precisely
because that set is the generator's business, not ours.

## What it installs

- `lib/libglad.a` — built from the two generated `.c` files with `$CC`/`$AR`.
- `include/glad/gl.h`, `include/glad/gles2.h` (+ `include/KHR/khrplatform.h`
  if the selected API pulls it in).
- `lib/pkgconfig/glad.pc` — hand-written by the recipe. Upstream ships **no**
  `.pc` and no CMake package config anywhere: there is nothing in the tree to
  describe, because there is no build output in the tree. This follows
  `packages/lua/generic.lua`.

## What does the generated C need from a host that does not exist here?

Essentially nothing. `glad/generator/c/templates/base_template.c:6-11` shows
the complete include set of a generated source:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glad/gl.h>        /* its own generated header */
```

and the loader adds `<dlfcn.h>` on non-Windows
(`glad/generator/c/templates/loader/library.c:9`), which Bionic has from API
21, while `GLAD_PLATFORM_WIN32` (`templates/platform.h:6-11`, keyed on
`_WIN32`/`__MINGW32__`) makes mingw use `<windows.h>`/`LoadLibraryA` instead.

**No OpenGL headers, no X11, no EGL headers, no GLX.** The generated header
*is* the OpenGL header — the same property GLEW has, and for the same reason.
`--dlfcn` resolution is a *runtime* concern anyway: the build is a static
archive with no link step.

## Dependencies summary

| Requirement | In this tree? |
| --- | --- |
| `python@native` | `packages/python/` exists; **no stage3.md**, no build record. |
| `jinja2@native` | `packages/jinja2/` exists, pure-Python copy. |
| `markupsafe@native` | `packages/markupsafe/` exists, pure-Python copy (no `_speedups`). |
| network at build time | Not needed, given `--reproducible`. |
| `pip` / package install | Not needed — `glad/plugin.py` falls back to built-in defaults. |

## Source

`https://github.com/Dav1dde/glad/archive/refs/tags/v2.0.8.tar.gz`. Verified
HTTP 200; the archive's single top-level directory is `glad-2.0.8`, 446 entries,
stripped by the recipe. v2.0.8 is the newest tag.

## API-level gating

There is no C in the release to gate on — the C does not exist until the
generator runs, and what it generates is fixed by `gl.xml` and the templates,
not by the target. The two inputs that could vary are `<stdio.h>`/`<stdlib.h>`/
`<string.h>` (present at every Bionic level) and `<dlfcn.h>` (API 21+). So the
API level is not a variable for this package on any row.

## Per-system verdict

Every row below is **conditional on the same single fact**: that
`packages/python` builds a working CPython for `clang-native`. That is stated
once, above, and not repeated per row.

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | UNCERTAIN | The generated sources are unconditional and use nothing older than `<dlfcn.h>` (API 21), so the *compile* is safe at 21. But this row cannot be green until `python@native` is proven, and that build has no stage3.md in this tree. |
| `aarch64-android24` | UNCERTAIN | As above. |
| `aarch64-android35` | UNCERTAIN | As above. |
| `x86_64-android35` | UNCERTAIN | As above; the generated C has no architecture branches — `dlopen` is the only platform call and it is chosen by preprocessor on `_WIN32`, not on architecture. |
| `x86_64-mingw` | UNCERTAIN | As above, plus `GLAD_PLATFORM_WIN32` is 1 here (`__MINGW32__`), so the generated loader uses `<windows.h>`/`LoadLibraryA` and never reaches `<dlfcn.h>`. Same single caveat. |
| `clang-native` | UNCERTAIN | As above. On this system the generator and the generated C share the same prefix, so this is the row most likely to work first — but "most likely" is not a verdict, and I have not run it. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.

**These rows are UNCERTAIN rather than WILL BUILD on purpose.** Every other
package in this wave can be judged from its own sources; this one cannot be,
because half its build is a dependency that has never been built here. Marking
it green would be exactly the "forecast that is wrong is worse than no
forecast" failure AGENTS.md describes.

## What a reviewer should scrutinise

1. **`--reproducible` must not be dropped.** It is the difference between a
   build that works offline and a build that tries to reach GitHub at build
   time. `glad/__main__.py:149-153` is the citation.
2. **`python@native` is a heavy dependency for a C library.** It drags in
   CPython 3.14.7 and `readline`. If a reviewer objects, the alternative is
   the glad web service's pre-generated zip — but that is an unversioned,
   un-checksummed HTTP endpoint with no release tag behind it, which is worse
   for a recipe whose entire point is reproducibility. The generator route is
   pinned to a tag and is offline.
3. **Jinja2's version range** is `>=2.7,<4.0` (`requirements.txt`). Our
   `jinja2` is 3.1.6, inside it. Worth noting because the recipe does not
   `pip install` anything, so nothing enforces the range at build time.
4. **`glad.pc` is ours, not upstream's.** `Libs: -L${libdir} -lglad` with no
   `-ldl`. A consumer on a platform where `dlopen` lives in a separate `libdl`
   would need to add it themselves; on Bionic and modern glibc it is in libc.
5. **The generated header set is copied wholesale.** If a future glad release
   changes `get_templates()`, the recipe still works, because it copies
   `include/.` and compiles the two `.c` files by the names the API strings
   produce. If it ever emits a *different number* of source files, the recipe's
   hardcoded `gl.c`/`gles2.c` would need updating.