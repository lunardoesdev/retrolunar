# jinja2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.1.6 (sdist from pypi.org)
- Build system: none. Pure Python.
- Installs: `lib/python3.14/site-packages/jinja2/` and a `LICENSE.txt` copied
  inside it. No `dist-info`, no compiled extension, no `.pc`.
- Requires: `jinja2@source` only. No package dependencies (Jinja2's runtime
  deps — MarkupSafe — are handled by the host interpreter, not this prefix).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:9-11` is a `mkdir` and two `cp` invocations. No compiler, no target interpreter, nothing executed. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make. The recipe says so at `generic.lua:4-8`,
including the reason LFS's `pip3` wheel step is not reproduced: it needs a
*host* Python to run, and a target interpreter must never be executed here.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*` — the recipe has no step that could observe an API level.

**Risks / what a reviewer should check.**

1. **The `python3.14` in the path is correct, and verified — not a guess.**
   `packages/python/source.lua:2` pins 3.14.7, and upstream's
   `Lib/sysconfig/__init__.py` defines `posix_prefix.purelib` as
   `{base}/lib/{implementation_lower}{py_version_short}{abi_thread}/site-packages`,
   with `abi_thread` empty unless `--disable-gil` is passed — which
   `packages/python/generic.lua:7` does not. So a literal `python3.14` is the
   right value, and `packaging`, `setuptools` and `flit-core` already agree.
   This recipe was corrected from `python3.13` to `python3.14`: at 3.13 the
   module landed in a directory the target interpreter never searches, and the
   failure mode was a silent `ModuleNotFoundError` at runtime on the target,
   not a build error. **The check that would have caught it is
   `test ! -e $PREFIX/lib/python3.13`.**
2. **The value is duplicated across five consumers and should become one
   shared module.** `python3.14` now appears literally in this recipe, in
   `packaging`, in `setuptools`, in `flit-core` and in `meson`. A reviewer
   proposed a single `packages/python/sitepackages.lua` returning the string,
   required relatively by each consumer and passed as a recipe field so it
   becomes `$sitepackages` with no `export` and no loader change. That was
   deliberately NOT done in the rework pass — it changes python's recipe shape
   and depends on relative-require behaviour, so it deserves its own reviewed
   change rather than riding along. Recorded here so the literal is not
   re-derived or "cleaned up" independently by each package. **Two wrong
   approaches to avoid:** a system-file `export` would need repeating in ~12
   system files, and globbing `$PREFIX` would make the install path depend on
   queue order. And note that no consumer should `require("python@source")` to
   learn the version — that queues python's recipe and its
   `git clone --depth=1` of CPython into a fresh mktemp dir per block, a whole
   checkout to learn a directory name..
2. **No `dist-info`.** Deliberate, and commented at `generic.lua:6-8`: the
   wheel metadata needs a host Python. The consequence is that `pip` cannot
   see the package; only a direct `sys.path` entry works. That is fine for
   this prefix and matches `markupsafe` and `meson`.
3. `src/jinja2` is the sdist's own directory name, so `cp -r src/jinja2` relies
   on the sdist layout. If a future release flattens the sdist, this breaks
   with a `cp: cannot stat`.

**How to verify once built.**

- `lib/python3.14/site-packages/jinja2/__init__.py` exists.
- `lib/python3.14/site-packages/jinja2/LICENSE.txt` exists (the recipe copies
  it separately, so it is worth checking it is not missing).
- `ls lib/python3.14/site-packages/jinja2/` shows `__init__.py`, `environment.py`,
  `template.py` — the module is complete rather than a stub.
- `grep -c . lib/python3.14/site-packages/jinja2/__init__.py` is non-zero.
- Do not run any target Python. Verification is static: file presence and
  `python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())"` on the
  host if a syntax check is wanted.
