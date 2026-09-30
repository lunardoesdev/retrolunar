# meson build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.12.1 (sdist from pypi.org)
- Build system: none. Pure Python — meson has no C extension.
- Installs: `lib/python3.14/site-packages/mesonbuild/` (plus a copied
  `COPYING`), and a hand-placed `bin/meson` launcher with the executable bit
  set. No `dist-info`, no `.pc`.
- Requires: `meson@source` only. **Note the direction of the dependency:** four
  other recipes in this shard *use* meson as a host tool — harfbuzz, kmod, and
  others invoke `meson setup`/`meson compile` — but none of them
  `require("meson")`, because meson runs on the build machine, not the target.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:11-19` is a `mkdir`, two `cp`s and a `chmod +x`. Nothing is compiled and nothing is executed. Meson is a Python program that generates `ninja` build files; installing it into a target prefix is for a target-side user, and it is inert until someone runs it. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above; and this is the system where a *working* copy also exists at `$NATIVE_PREFIX`, which is what the host tools in other recipes actually use. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make. The recipe says so at `:9-13`, including why
LFS's `setup.py` step is not reproduced: it would need a **target** Python
interpreter to run, which is forbidden.

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
2. **`bin/meson` is a Python script with no shebang adjustment.** `cp meson.py
   $OUT/bin/meson` (`:17`) copies a file whose first line is `#!/usr/bin/env
   python3`. On the target that path may not exist, so the launcher may not be
   runnable even though it is present and executable. `chmod +x` is set
   (`:19`), which is right; the shebang is a separate question this recipe does
   not address. Low severity — a target-side meson is of niche value — but
   worth recording.
3. **`meson` here is not what builds this tree.** The host meson that other
   recipes shell out to comes from `$NATIVE_PREFIX`, not from `$PREFIX`. So
   installing meson into a *target* prefix does not help any recipe in the
   tree. That is fine, but it is worth stating so nobody adds `require("meson")`
   to a recipe expecting it to provide the build tool.
4. **No `dist-info`,** deliberately and commented (`:12-13`): same reason as
   jinja2 and markupsafe — wheel metadata needs a host Python.
5. `topackage.md:58` records this as built — *"pure Python, module + bin/meson
   launcher, no dist-info"*. Consistent, and the `python3.14`/`3.14` question
   is not addressed by that entry either, so it is genuinely open.

**How to verify once built.**

- `lib/python3.14/site-packages/mesonbuild/__init__.py` exists — this is the
  file to check, because it is what makes the directory a package rather than a
  stray tree.
- `lib/python3.14/site-packages/mesonbuild/coredata.py` exists (the module is
  large and complete, not truncated).
- `bin/meson` exists and `[ -x bin/meson ]` is true.
- `head -1 bin/meson` shows the shebang — record it, since that is the
  launcher-robustness question in risk 2.
- **Cross-check the directory name against `python`:** if `python` installs
  into `lib/python3.14/`, this is in the wrong place. This is the single check
  that matters most in this file.
- Do not execute `bin/meson` from a target prefix.
