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
python3 -m glad --out-path=glad-out --reproducible --api=gl:core=3.3,gles2,egl c --loader
```

**The position of `c` is load-bearing.** The global options (`--out-path`,
`--api`, `--reproducible`) are registered on the top-level parser
(`glad/__main__.py:122`), but the generator's own options — `--loader` among
them — are registered on the **`c` subparser** (`glad/__main__.py:134-135`,
via `glad/config.py:288-296`, which builds each flag as
`'--' + name.lower().replace('_','-')`). `argparse` matches the subcommand
token before the subparser takes over, so `c` must precede `--loader`.
Writing `... --api=... --loader c` aborts with
`error: unrecognized arguments: --loader` before any file is produced. The
first version of this forecast got that wrong.

**`egl` is in the API list because `--loader` requires it.** This was the
second, independent failure in the first version of this recipe. The built-in
loader pulls in `loader/<api>.c` for every selected API
(`glad/generator/c/templates/base_template.c:185-191`), and
`loader/gles2.c:17` does an unconditional `#include <glad/egl.h>` to obtain
`EGLDisplay` and `PFNEGLGETPROCADDRESSPROC`. `glad/egl.h` is only generated
when `egl` is among the requested APIs, so `--api=gl:core=3.3,gles2` yields a
`src/gles2.c` that cannot compile — `fatal error: 'glad/egl.h' file not
found`. Requesting `egl` makes glad generate `include/glad/egl.h` and
`src/egl.c` from its own vendored `glad/files/egl.xml`, so nothing outside this
tree is needed for it. This is also what upstream's own generator does when
asked for GLES2.

The alternative — compiling `gles2.c` with `-DGLAD_GLES2_USE_SYSTEM_EGL` — is
**not usable here and I recommend against it**, for two reasons. First, that
arm is `#include <EGL/egl.h>` (`loader/gles2.c:13-14`) and
`__eglMustCastToProperFunctionPointerType` is declared *by that header*. The
NDK sysroot does ship `EGL/egl.h`, which is why it looks like it works, but
the mingw sysroot has no `EGL/` directory at all (verified:
`/usr/x86_64-w64-mingw32/include/EGL/` does not exist) — so it is an
Android-only fact and would break `x86_64-mingw`. Second, it is a compile
definition every consumer would have to replicate.

| Flag | Reason |
| --- | --- |
| `--reproducible` | Offline + deterministic. See above. Without it this build attempts network access at build time. |
| `--api=gl:core=3.3,gles2,egl` | Desktop GL core for `x86_64-mingw` and `clang-native`, GLES2 for Android, EGL because the loader's GLES2 path needs it. Both GL versions are pinned explicitly: "no version" means *latest* (`glad/__main__.py:88-96`). |
| `--loader` | Emits glad's own `dlopen`-based loader (`templates/loader/*.c`). Without it the generated source declares the function-pointer table but leaves `gladLoadGLLoader()` for the consumer, and there is no other loader in this prefix. |
| `c` (subcommand) | The C generator. `subparsers.default = 'c'` (`glad/__main__.py:128`) so it is optional; passed explicitly because its position is significant. |

**Output layout** is fixed by the generator, not chosen by us.
`glad/generator/c/__init__.py:397-399` writes `include/glad/<name>.h` and
`src/<name>.c` per API, where `<name>` is the API string (`glad/parse.py:780`),
so the run above produces:

```
glad-out/include/glad/gl.h        glad-out/src/gl.c
glad-out/include/glad/gles2.h     glad-out/src/gles2.c
glad-out/include/glad/egl.h       glad-out/src/egl.c
glad-out/include/KHR/khrplatform.h
glad-out/include/EGL/eglplatform.h
```

The last two are the Khronos platform headers the generated headers need
(`EGLDisplay` comes from `eglplatform.h`, the `khronos_*` types from
`khrplatform.h`); `glad/generator/c/__init__.py:_add_additional_headers`
writes them from the vendored copies in `glad/files/`, so again nothing
external is involved. The recipe copies `glad-out/include/.` wholesale rather
than naming files, because that set is the generator's business, not ours.

## What it installs

- `lib/libglad.a` — built from the three generated `.c` files with
  `$CC`/`$AR`.
- `include/glad/{gl.h,gles2.h,egl.h}`, `include/KHR/khrplatform.h`,
  `include/EGL/eglplatform.h`.
- `lib/pkgconfig/glad.pc` — hand-written by the recipe. Upstream ships **no**
  `.pc` and no CMake package config anywhere: there is nothing in the tree to
  describe, because there is no build output in the tree. This follows
  `packages/lua/generic.lua`. Consumers need no compile definition.

**One hazard worth naming.** The recipe installs glad's own
`EGL/eglplatform.h` into the shared prefix. A consumer that also links a
*system* EGL would have `$PREFIX/include` searched first (every system puts
`-I$PREFIX/include` ahead of the sysroot), so our copy could shadow theirs.
It is the genuine Khronos header, but it is a new `EGL/` directory appearing
in a shared prefix, and that is the kind of thing a reviewer should be
comfortable with.

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

**No OpenGL headers, no X11, no GLX — and no *system* EGL headers either.**
The generated header *is* the OpenGL and EGL header; that is what asking for
`egl` buys. `dlopen` resolution is a *runtime* concern in any case: the build
is a static archive with no link step.

## Dependencies summary — and the blocker

| Requirement | In this tree? |
| --- | --- |
| `python@native` | `packages/python/` **exists but is REJECTed at stage 2**, and `nest/clang-native/bin` contains no `python3` at all. |
| `jinja2@native` | `packages/jinja2/` exists, pure-Python copy into `lib/python3.14/site-packages` — but **REJECTed at stage 2**. |
| `markupsafe@native` | `packages/markupsafe/` exists, pure-Python copy, no `_speedups` — but **REJECTed at stage 2**. |
| network at build time | Not needed, given `--reproducible`. |
| `pip` / package install | Not needed — `glad/plugin.py` falls back to built-in defaults. |

**This package cannot build today, and that is a determinate fact rather than
an open question.** All three Python dependencies are reviewed and rejected:

```
$ head -1 packages/{python,jinja2,markupsafe}/stage2.md
REJECT   REJECT   REJECT
```

and there is no `python3` in the native prefix at all:

```
$ ls nest/clang-native/bin | grep -i '^python'
(nothing)
```

So the mechanism this recipe relies on — "the loader puts `$NATIVE_PREFIX/bin`
first, so a bare `python3` is the native one" — currently resolves to whatever
`/usr/bin/python3` happens to be on the build host, and *that* interpreter's
`site-packages` is not `$NATIVE_PREFIX/lib/python3.14/site-packages` either. The
recipe's comment about jinja2 and markupsafe landing "in the native
interpreter's own site-packages" is therefore **not true of this nest** until
`python@native` actually builds.

One correction to the stage 2 review, for the record: it states that jinja2 and
markupsafe install into `lib/python3.13/site-packages` while the interpreter is
3.14. That is not what the recipes say — all three use
`lib/python3.14/site-packages`, matching the pinned CPython 3.14.7. The only
`python3.13` string in `packages/` is a comment in `wheel/generic.lua:12`.
That mismatch is therefore **not** an additional blocker, and should not be
carried forward as one. The blocker is the three rejections and the absent
interpreter, nothing else.

None of this is the adder's to fix, and it is not worked around here. Fix
`python`, `jinja2` and `markupsafe`, then re-review glad.

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

Every row below is **WILL NOT BUILD for the same single, determinate reason**:
the generator's host interpreter does not exist. `python`, `jinja2` and
`markupsafe` are all REJECTed at stage 2 and `nest/clang-native/bin` has no
`python3`, so `python3 -m glad` cannot run and no C is ever produced. That is
stated once, in 'Dependencies summary — and the blocker', and not repeated per
row.

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL NOT BUILD | The blocker: no host Python, so generation never starts. Note that the *compile* half would have been safe at 21 — the generated sources use nothing older than `<dlfcn.h>` — so this row is about the generator, not the API level. |
| `aarch64-android24` | WILL NOT BUILD | Same blocker. |
| `aarch64-android35` | WILL NOT BUILD | Same blocker. |
| `x86_64-android35` | WILL NOT BUILD | Same blocker. |
| `x86_64-mingw` | WILL NOT BUILD | Same blocker. Worth recording for the re-review: because `egl` is now in the API list, glad generates its own `glad/egl.h` from vendored `egl.xml`, so this row needs **no** system EGL header — which the `-DGLAD_GLES2_USE_SYSTEM_EGL` alternative would have required and the mingw sysroot does not have. |
| `clang-native` | WILL NOT BUILD | Same blocker, and it is the sharpest form of it: on this system the generator's output *is* the system artifact, so with no `python3` in `nest/clang-native/bin` there is nothing at all. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.

**These rows changed from UNCERTAIN to WILL NOT BUILD, and the reason matters.**
The first version of this forecast called them UNCERTAIN, which was right when
the only problem was an unproven dependency — "I don't know whether this will
build" is what UNCERTAIN means. It is the wrong answer once it is *known* that
the build cannot start. The two defects in the first version of the recipe —
the `--loader` position and the missing `glad/egl.h` — were internal to this
package and are now fixed; what remains is a dependency blocker that is not the
adder's to fix. Re-review once `python`, `jinja2` and `markupsafe` land.

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
   `include/.` rather than naming files. If it ever emits a *different number*
   of source files, the recipe's hardcoded `gl.c`/`gles2.c`/`egl.c` would need
   updating.
6. **`EGL/eglplatform.h` lands in the shared prefix.** A new `EGL/` directory,
   from a package named glad. It is the genuine Khronos header and glad's
   generated `egl.h` needs it, but `$PREFIX/include` is searched ahead of
   every sysroot, so it could shadow a real system one for a consumer that
   also uses EGL. Recorded rather than worked around.
7. **The `--loader` argument position.** `--loader` *before* the `c`
   subcommand aborts generation; after it, the spelling is right and
   accepted. The spelling comes from `glad/config.py:291`
   (`'--' + name.lower().replace('_','-')` applied to `CConfig.LOADER`).