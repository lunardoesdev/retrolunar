# markupsafe build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.0.3 (sdist from pypi.org)
- Build system: none. Pure Python, and the one optional C accelerator is
  deliberately not built.
- Installs: `lib/python3.14/site-packages/markupsafe/` and a `LICENSE.txt`
  copied inside it. No `dist-info`, no compiled `_speedups` extension, no `.pc`.
- Requires: `markupsafe@source` only.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:10-12` is a `mkdir` and two `cp` invocations. The `_speedups` C accelerator is **not** built — the recipe says why at `:6-9`: LFS uses `pip3` to compile it, and that would need a host Python; the module falls back to its pure-Python `_native.py` implementation. Nothing is executed either way. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make. This matters more here than for most
packages: MarkupSafe's whole job is escaping HTML, and the `_speedups` module
is a C accelerator for exactly that. **Not building it means every system gets
the slower pure-Python path** — identical everywhere, which is the point, and
a deliberate trade of speed for uniformity.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

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
2. **`markupsafe` is a hard runtime dependency of `jinja2`**, which is also in
   this tree. But jinja2's recipe does **not** `require("markupsafe")` — it is
   pure Python and relies on the host interpreter's own MarkupSafe. So the two
   packages are independent, and which one wins at runtime depends on
   `sys.path` order. Worth a reviewer's attention: a prefix that installs both
   has two copies of the same module.
3. **No `dist-info`,** deliberately and commented (`:9`): same reason as
   `jinja2` and `meson` — wheel metadata needs a host Python. The consequence
   is that `pip` cannot see the package.
4. **Dropping `_speedups` is a real functional choice**, not just a build
   simplification. MarkupSafe's `__init__.py` does
   `try: from ._speedups import ...; except ImportError: from ._native import ...`,
   so the fallback is well-defined and correct. Performance on a phone matters
   if this is on a rendering hot path; correctness does not. That trade should
   be a conscious decision, and the recipe's comment implies it is.
5. **`LICENSE.txt` is copied separately** (`:12`) rather than coming with the
   package directory. Worth checking it is actually present, since a missing
   licence file in a vendored module is a real (if minor) compliance problem.

**How to verify once built.**

- `lib/python3.14/site-packages/markupsafe/__init__.py` exists.
- `lib/python3.14/site-packages/markupsafe/_native.py` exists — **this is the
  fallback implementation and its presence is the check that the package will
  work** without the C accelerator.
- `lib/python3.14/site-packages/markupsafe/LICENSE.txt` exists.
- **`_speedups*.so` must NOT exist.** Its presence would mean the accelerator
  was built, contradicting the recipe.
- `ls lib/python3.14/site-packages/markupsafe/` should show `__init__.py`,
  `_native.py` and possibly `_speedups.pyi` (the type stub, which is pure text
  and legitimately ships).
- **Cross-check the Python version directory against `python`:** if that
  package installs into `python3.14/site-packages`, this one is in the wrong
  place and the version string needs changing in both this recipe and
  `jinja2`'s.
