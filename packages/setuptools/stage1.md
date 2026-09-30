# setuptools build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 84.0.0 (`files.pythonhosted.org/.../setuptools-84.0.0-py3-none-any.whl`)
- Build system: **none** — no configure, no Makefile, no compiler. A wheel is a
  zip of pure Python; `source.lua:10` runs `python3 -m zipfile -e` on it and
  `generic.lua:5-6` does one `mkdir` and one `cp`.
- Installs: `lib/python3.14/site-packages/setuptools/**`, `.../_distutils_hack/**`,
  `.../pkg_resources/**`, `.../_vendor/**`. **No library, no headers, no
  pkg-config file.**
- Requires: `setuptools@source` only (`generic.lua:1`).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Two `cp` calls. Nothing is compiled, so no Bionic API-level wall can apply and no architecture check exists. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** Not applicable, and this is the point rather than an
oversight: there is no toolchain in the build body, so there is nothing that
could observe the API level. `$CC`, `$CXX`, `$CFLAGS`, `$SYSROOT` and
`$CMAKE_FLAGS` are all untouched, and correctly so — a pure-Python package
must not pick up any target flag.

**Risks / what a reviewer should check.**
1. **`python3.14` is hardcoded twice** — `generic.lua:5` and `generic.lua:6`.
   That is a *language runtime version*, not a target fact, so it does not
   violate the "never hardcode a target fact" rule. But it is a real coupling:
   if `packages/python` is ever bumped to 3.15, this recipe silently installs
   into `lib/python3.14/site-packages`, which no Python will look in. There is
   no shared variable for it in the system recipes to reference, so this is
   worth flagging to whoever owns `packages/python`. **Note the same hardcoded
   path appears as `python3.13` in `packages/wheel/generic.lua:9` — the two do
   not agree with each other.** That inconsistency is the single most useful
   finding in this file: a `setuptools` installed under 3.14 and a `wheel`
   installed under 3.13 will not be visible to the same interpreter.
2. **`.whl` rather than an sdist.** The recipe uses the manylinux-tagged wheel
   name `setuptools-84.0.0-py3-none-any.whl`, which is a pure-Python wheel and
   therefore target-independent. Note the URL embeds a content hash path
   (`95/9c/c510...`); that is how PyPI addresses files, and the hash is part of
   the immutable path, so it is as stable as a version tag. No checksum is
   recorded, per the project's no-checksums decision (AGENTS.md).
3. **`python3 -m zipfile -e` is a host tool**, called in `source.lua` under the
   `source` pseudo-system. That is allowed (the rule is "no network except
   `curl` in `source.lua`", and `python3` is local). It does mean the *build
   host* must have a `python3` — which it does, since `packages/python`
   depends on the same class of thing.

**How to verify once built.**
- `lib/python3.14/site-packages/setuptools/__init__.py`,
  `lib/python3.14/site-packages/pkg_resources/__init__.py`
- No `lib/*.a` and no `.pc` — correct for this package
- `python3 -c "import sys; sys.path.insert(0,'lib/python3.14/site-packages'); import setuptools; print(setuptools.__version__)"`
  → `84.0.0`. This is a **host** Python reading target-independent `.py`
  files, not an emulation of a target binary, so it is allowed.
- The freshness stamp `$NESTDIR/<sys>/.retrolunar-setuptools` should reappear
  unchanged on a rerun ("skip ... (fresh)").