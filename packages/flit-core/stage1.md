# flit-core build forecast

- Recipe: `generic.lua`, source `source.lua` (PyPI sdist)
- Version pinned: 3.12.0
- Build system: **none** — pure Python, installed by copying
- Installs: `lib/python3.14/site-packages/flit_core/` (the module) and a copy of `LICENSE` beside it; **no `.pc`, no compiled artifact, no dist-info**
- Requires: `flit-core@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD (trivially) | Nothing is compiled. `generic.lua:13-15` creates `$OUT/lib/python3.14/site-packages`, copies `flit_core/` into it, and copies `LICENSE` in beside the package. The install is byte-identical on every system. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above; topackage.md:26 records Flit-core 3.12.0 as `[x]`, "module only; no dist-info without host pip". |

## API level notes

**No architecture check applies, and no API-level check either.** This is
pure data: a directory tree of `.py` files. The `python3.14` in the path is
a *name*, not a build — there is no Python interpreter invoked anywhere in
the recipe.

The one thing a reviewer must know is that the interpreter version is
spelled into the path and must match `packages/python`. **An earlier
version of this file called this hypothetical; it was not.**
`packages/python/source.lua` already pins CPython **3.14.7**, whose
`posix_prefix` scheme is `lib/python3.14/site-packages`. The recipe installed
into `python3.13/site-packages`, a directory that interpreter never searches,
so `import flit_core` would have failed with a bare `ModuleNotFoundError`.
The build still succeeded, because it is a copy with no interpreter invoked
— which is exactly why the first version of this forecast missed it. The
recipe now spells 3.14.

## Risks / what a reviewer should check

- **The Python version is hardcoded in three places** and there is no check
  that it agrees with `packages/python`. This is the single most likely
  way this package silently breaks. Compare
  `packages/intltool/generic.lua:11`, which reads the version out of
  `$NATIVE_PREFIX` at build time:
  `export PERL5LIB="$NATIVE_PREFIX/lib/perl5/5.44/core_perl"`. The same
  technique would make this recipe self-correcting. Flagging rather than
  fixing, per the task's scope.
- **No `dist-info` metadata, deliberately** (`generic.lua:5-7`): LFS
  builds a wheel with `pip3`, which would add `flit_core-3.12.0.dist-info`,
  and that needs a *host* Python. Omitting it means the module is
  importable but not "installed" in the pip sense — no `pip list` entry, no
  uninstall. For a build-time packaging helper that is the right trade.
- **flit-core is a build-time tool for other Python packages.** Anything
  in this prefix that shells out to `flit` or imports `flit_core` needs a
  Python that can see this directory. That is `packages/python` with
  `PYTHONPATH` set to `$PREFIX/lib/python3.14/site-packages`, which is a
  consumer-side concern, not this recipe's.
- **No checksum.** The sdist is fetched from PyPI over HTTPS with `curl -fSL`
  and no digest, consistent with the project-wide "no checksums" decision
  (AGENTS.md). For a package that will be *executed* by later builds, that
  is a slightly larger risk than for a C library, but it is the project's
  policy, not a defect in this recipe.

## How to verify once built

- `lib/python3.14/site-packages/flit_core/__init__.py`
- `lib/python3.14/site-packages/flit_core/LICENSE`
- **`diff -r` the `flit_core/` tree against two different system nest dirs
  and confirm they are identical** — the strongest check available for a
  package with nothing to compile
- Confirm the directory name matches `packages/python`'s version: compare
  the `python3.NN` segment here against the same segment under
  `packages/python`'s output. If they differ this package is misinstalled,
  **even though the build succeeded**
- No `.pc`, no library, no `bin/`
