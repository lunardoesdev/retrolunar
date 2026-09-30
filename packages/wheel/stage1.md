# wheel build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.48.0 (`pypi.org/packages/source/w/wheel/wheel-0.48.0.tar.gz`)
- Build system: **none — pure Python.** No configure, no compiler.
  `generic.lua:9-11` is one `mkdir` and two `cp`s.
- Installs: `lib/python3.13/site-packages/wheel/**` and
  `.../wheel/LICENSE.txt`. **No library, no headers, no pkg-config file, no
  `dist-info` metadata** — `generic.lua:6-8` explains that the `dist-info` LFS
  gets from `pip3 wheel` is skipped because it needs a host Python.
- Requires: `wheel@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | One `mkdir` and two `cp`s. Nothing reads a sysroot or invokes a compiler, so no Bionic API-level wall can apply. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** Not applicable, and that is the design rather than an
oversight: there is no toolchain in the build body, so there is no architecture
to be sensitive to and no way for a target fact to leak in. `$CC`, `$CXX`,
`$CFLAGS`, `$SYSROOT` and `$CMAKE_FLAGS` are untouched, and correctly so — a
pure-Python package must not pick up any target flag. The installed tree is
byte-identical on all six systems.

**Risks / what a reviewer should check.**
1. **The site-packages path is `python3.13`, and `setuptools` installs into
   `python3.14`.** `generic.lua:9-10` here uses `lib/python3.13/site-packages`,
   while `packages/setuptools/generic.lua:5-6` uses
   `lib/python3.14/site-packages`. **These two do not agree, and that is a real
   problem: an interpreter looking in one directory will not find the package
   installed in the other.** They are two of the oldest Python packages in the
   tree (`setuptools`, `wheel`, both 2 days old by directory mtime) and the
   version they were written against has moved on. This is the single most
   useful finding in this file — it affects **every** system identically, so it
   is not an Android issue and it will not show up in any cross-compilation
   check. It needs a decision from whoever owns `packages/python`: either both
   recipes adopt one version, or the path should be derived from something the
   system exports.
2. **`wheel` is a build-time tool, not a runtime one.** It is a pure-Python
   package that installs into a *target* prefix, where nothing will ever run
   `pip wheel` — the build host has its own. Installing it is defensible for
   completeness but a reviewer may reasonably ask whether this package belongs
   in a target prefix at all, or should be a `@native` dependency the way
   `perl@native` is used in `packages/xml-parser/generic.lua:2`.
3. **No `dist-info` metadata** (`generic.lua:6-8`) means `importlib.metadata`
   cannot report the version, and a `pip` in this prefix would not consider the
   package installed. The comment states this as a deliberate trade for avoiding
   a host-Python dependency, which is the right trade; recording it here so it
   is not mistaken for an oversight.
4. **0.48.0 is the current release.** No upgrade pressure.
5. The URL is the canonical PyPI sdist path (not a content hash like
   `setuptools`), so it is stable.

**How to verify once built.**
- `lib/python3.13/site-packages/wheel/__init__.py`
- `test -f lib/python3.13/site-packages/wheel/LICENSE.txt` → true, proving
  `generic.lua:11` ran
- `python3 -c "import sys; sys.path.insert(0,'lib/python3.13/site-packages');
  import wheel; print(wheel.__version__)"` → `0.48.0`. That is a **host**
  interpreter reading target-independent `.py` files, not an emulation, so it
  is allowed.
- **Check risk 1 concretely:** `ls lib/` should show exactly one
  `python3.X` directory, and `grep -l python3 packages/setuptools/generic.lua
  packages/wheel/generic.lua` should show the same version in both. Today it
  will show `python3.14` and `python3.13` — a mismatch.
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**, the
  check that no toolchain got involved.