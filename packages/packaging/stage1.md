# packaging build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 26.3 (sdist from files.pythonhosted.org)
- Build system: none. Pure Python.
- Installs: `lib/python3.14/site-packages/packaging/` plus `LICENSE`,
  `LICENSE.APACHE` and `LICENSE.BSD` copied inside it. No `dist-info`, no
  compiled extension, no `.pc`.
- Requires: `packaging@source` only.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:7-9` is a `mkdir` and two `cp` invocations. Nothing is compiled, nothing executed, no target interpreter needed. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **This is the recipe that gets the Python version right, and the one the
   other three should copy.** It uses `lib/python3.14/site-packages`
   (`generic.lua:7`), matching the `python` package's 3.14.7 pin — whereas
   `jinja2`, `markupsafe` and `meson` all use `python3.13`. **That is a
   confirmed inconsistency across four recipes, and this one is almost
   certainly right**, because it agrees with the interpreter that is actually
   built. The failure mode on the others is a silent `ModuleNotFoundError` at
   runtime on the target, not a build error, which is why it would go
   unnoticed. This is the single most actionable finding in the shard.
2. **Three licence files are copied explicitly** (`:9`) rather than coming
   with the module. Worth checking all three are present, since packaging is
   dual-licensed and dropping one would be a compliance problem.
3. **No `dist-info`,** consistent with the other pure-Python packages. The
   consequence is that `pip` cannot see it; only a direct `sys.path` entry
   works.
4. **The source URL is a full files.pythonhosted.org hash path**
   (`source.lua:6`), which is the canonical PyPI artifact URL and is stable
   for a given release. Fine, though it is opaque; the plain
   `pypi.org/packages/source/p/packaging/` form used by jinja2 and markupsafe
   is more readable and equally stable.
5. `topackage.md:64` records this as built — *"LFS 25.0; latest stable; module
   only, no dist-info"*. Consistent, and it confirms the module-only choice.
6. **packaging is a dependency of pip, setuptools and wheel**, none of which
   are in this tree. So like lua, libwebp and opus, it is a standalone with no
   consumer in the prefix.

**How to verify once built.**

- `lib/python3.14/site-packages/packaging/__init__.py` exists — this is the
  file to check, since it makes the directory a package rather than a stray
  tree.
- `lib/python3.14/site-packages/packaging/version.py` and `specifiers.py`
  exist, proving a complete module rather than a stub.
- `LICENSE`, `LICENSE.APACHE` and `LICENSE.BSD` all exist inside the package
  directory.
- **Cross-check the directory against `python`, `jinja2`, `markupsafe` and
  `meson`.** If those say `python3.13`, this one is right and the other three
  need changing. That is the highest-value check in the file.
- Do not run any target Python.
