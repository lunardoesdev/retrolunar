ACCEPT

# setuptools 84.0.0 — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

**Adder A's finding #2 is CORRECT, and setuptools is the half that is already
right.** `generic.lua:5-6` uses `lib/python3.14/site-packages`, which matches
`packages/python` (3.14.7, verified) and CPython 3.14's `posix_prefix` sysconfig
scheme. The sibling `wheel` uses `python3.13` and is therefore wrong; see
`packages/wheel/stage2.md`, where I rule on the whole group of six
(`wheel`, `flit-core`, `jinja2`, `markupsafe`, `meson` — plus `setuptools`,
which is already correct).

The observable symptom of the split is worth restating here because it is the
thing a builder will actually hit: **setuptools and wheel cannot find each
other.** One is under `python3.14` and one under `python3.13`, so neither
resolves the other. That is the check to make after the sibling fix lands.

## What the recipe gets right

- The build-body shape is right for a pure-Python package: no build system, no
  interpreter invoked, no target binary. There is genuinely no API-level or
  architecture exposure, so the "WILL BUILD" verdicts are correct.
- **No `python setup.py install`, no `pip`, no wheel step.** That is the
  important call: the LFS recipe builds a wheel with host `pip3`, which would
  need a host Python and would execute a *target*-oriented install. Copying the
  tree is the smallest thing that works, and it is the same reasoning `wheel`,
  `flit-core` and `flit-core`'s siblings use.
- `require("setuptools@source")` names no missing package.

## One gap worth closing, not a reject reason

`generic.lua:6` copies `$NESTDIR/source/setuptools/*` into `site-packages`, so
the installed tree is the **unpacked sdist root**, not a named package
directory. For setuptools that happens to be right — the sdist root *is* the
`setuptools` package — but it is worth a comment saying so, because the shape
is unusual and a future maintainer could "fix" it into
`site-packages/setuptools/`, which would nest it one level too deep and break
`import setuptools`.

`setuptools` also normally ships `pkg_resources/` and `_distutils_hack/` at the
sdist root, and a `*.dist-info/` when installed properly. The builder should
record which of those land, because the absence of `dist-info` is the
deliberate consequence of skipping the wheel step and should be visible in the
build record rather than discovered later.

## Carried to the build

- `lib/python3.14/site-packages/setuptools/__init__.py` — `[ -f lib/python3.14/site-packages/setuptools/__init__.py ]`. The `python3.14` directory is the expected one; a `python3.13` tree appearing means the recipe regressed.
- `lib/python3.14/site-packages/setuptools/_distutils_hack/` and `pkg_resources/` — `[ -d lib/python3.14/site-packages/pkg_resources ]`. Both are part of the package and their presence proves the copy was recursive.
- `lib/python3.14/site-packages/setuptools-*.dist-info/` must be **absent** — its presence means someone added an install step that needs a host pip. (Note: setuptools' own sdist does contain a `setuptools.egg-info/`, which is *not* the same thing and is harmless.)
- **The cross-package check that actually matters:** after `wheel` is fixed,
  both `test -d $PREFIX/lib/python3.14/site-packages/setuptools` and
  `test -d $PREFIX/lib/python3.14/site-packages/wheel` must be true. If either
  is under `python3.13`, the tree-wide bug is not fully repaired.
