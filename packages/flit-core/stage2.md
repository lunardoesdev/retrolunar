ACCEPT

# flit-core 3.12.0 — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

## Required changes

### 1. `packages/flit-core/generic.lua:10-12` — the install directory names a Python the prefix does not have

```
        mkdir -p $OUT/lib/python3.13/site-packages
        cp -r flit_core $OUT/lib/python3.13/site-packages/
        cp LICENSE $OUT/lib/python3.13/site-packages/flit_core/LICENSE
```

`packages/python/source.lua` pins CPython **3.14.7**, whose `posix_prefix`
sysconfig scheme is `lib/python3.14/site-packages`. The module is therefore
installed into a directory the prefix's interpreter never searches, and
`import flit_core` fails at runtime with a bare `ModuleNotFoundError`.

The build itself succeeds — this is a copy, no interpreter is invoked — which
is exactly why the forecast calls it "WILL BUILD (trivially)" and misses it.
The forecast also frames the problem hypothetically ("if `packages/python` is
ever updated to 3.14"); it already is 3.14.7.

**Replace lines 10-12 with:**

```
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r flit_core $OUT/lib/python3.14/site-packages/
        cp LICENSE $OUT/lib/python3.14/site-packages/flit_core/LICENSE
```

and add a comment above them saying why the version is spelled out — CPython
3.14's install scheme, and that a `python` version bump means updating this
path. `packages/packaging` and `packages/setuptools` already use
`python3.14`; match them.

**The same fix is owed to `jinja2`, `markupsafe`, `meson` and `wheel`**, which
repeat the `python3.13` path. That is a tree-wide cleanup, not this package's
alone, and belongs in the backlog rather than in a single recipe edit.

## What the recipe gets right

- The build-body shape is right for a pure-Python package: no build system,
  no interpreter invoked, no target binary, so there is genuinely no API-level
  or architecture exposure and the six WILL BUILD verdicts are correct.
- Skipping the wheel/`pip3` step is the right call and is explained: it would
  add `dist-info` metadata but needs a host Python. Copying the module alone
  is the smallest thing that works, and AGENTS.md's "smallest necessary set of
  flags" supports it.
- The `LICENSE` copy into the package directory is a nice touch for a package
  with no other metadata.
- No `require()` names a missing package.

## Carried to the build

- `lib/python3.14/site-packages/flit_core/__init__.py` — `[ -f lib/python3.14/site-packages/flit_core/__init__.py ]`. After change 1 the `python3.14` directory is the expected one; a `python3.13` directory appearing means the fix was not applied.
- `lib/python3.14/site-packages/flit_core/vendor/tomli/` — `[ -d lib/python3.14/site-packages/flit_core/vendor/tomli ]`; the vendored `tomli` is what makes this package useful standalone, so it must survive the copy.
- `lib/python3.14/site-packages/flit_core/LICENSE` — `[ -f lib/python3.14/site-packages/flit_core/LICENSE ]`, the direct check for the third `cp`.
- `lib/python3.14/site-packages/flit_core-*.dist-info/` must be **absent** — its presence means someone added a wheel step that needs a host pip.

## Rework verification

**Verdict: ACCEPT.** First line changed from `REJECT` to `ACCEPT`.

### Correctly fixed

- `generic.lua:13-15` now install into `$OUT/lib/python3.14/site-packages`,
  all three lines, no `3.13` left anywhere in the recipe.
- `generic.lua:10-12` carries the comment change 1 asked for: it names
  CPython 3.14's `posix_prefix` install scheme, says `packages/python` pins
  3.14.7, and warns that a python bump means updating the line. That is the
  required change, applied as specified.
- **The version string is CORRECT.** Verified against upstream, not inferred:
  `Lib/sysconfig/__init__.py` in v3.14.7 defines
  `'posix_prefix': {'purelib': '{base}/lib/{implementation_lower}{py_version_short}{abi_thread}/site-packages', ...}`,
  `implementation_lower` = `python`, `py_version_short` = `3.14`, and
  `abi_thread` is empty unless `--disable-gil` is passed — which
  `packages/python/generic.lua:7` does not. `_get_preferred_schemes()` returns
  `posix_prefix` for `key == 'prefix'` on any non-`nt` build.
  So the target path is **`$OUT/lib/python3.14/site-packages`**, and
  `python3.14` is right.
- Nothing else damaged. No `export`, no build-system flags, no `sed`, no
  patch, no `/dev/null`; nothing compiles so the serial rule is moot.
  `require("flit-core@source")` names a package that exists.
- `source.lua` is correct: version 3.12.0 matches `PKG-INFO` in the unpacked
  tree (`Name: flit_core`, `Version: 3.12.0`), the PyPI URL answers 200, and
  the tree lands in `$OUT/flit-core/`. `LICENSE` and `flit_core/` are both
  present at the top level, so both `cp` lines have a source; the glob `*` on
  `cp -r $NESTDIR/source/flit-core/* .` misses no dotfiles (`ls -a` shows
  none), and `flit_core/vendor/tomli/` survives the recursive copy.

### Still wrong, or still owed

- **The defect is TREE-WIDE, not flit-core's alone.** The same
  `lib/python3.13/site-packages` path is still in
  `packages/jinja2/generic.lua:9-11`, `packages/markupsafe/generic.lua:10-12`,
  `packages/meson/generic.lua:11-13` and `packages/wheel/generic.lua:9-11`.
  That is **five** recipes that install into a directory
  `$PREFIX/lib/python3.14/` never searches, so `import jinja2`,
  `import markupsafe`, `import mesonbuild` and `import wheel` all fail at
  runtime while the build still succeeds. `packages/meson/generic.lua:15`
  compounds it: `bin/meson` is a launcher for `mesonbuild`, so it cannot
  import its own package. `packages/setuptools/generic.lua:5-6`,
  `packages/packaging/generic.lua:7-9` and this recipe already say
  `python3.14` and are correct. Another reviewer owns those four; I am not
  editing them.
- **The nest on disk is not the confirmation `packages/python/stage2.md:29-40`
  claims it is.** `nest/aarch64-android24/lib/python3.14/` contains
  `site-packages/{setuptools,packaging}` and nothing else — no `os.py`, no
  `bin/python3`, and `find nest -name os.py` returns nothing on any system.
  Those two directories exist because `setuptools` and `packaging` created
  them; the interpreter itself has not been built in this nest. The
  conclusion (`3.14` is right) still holds — it rests on
  `packages/python/source.lua:2` plus upstream's sysconfig scheme — but it is
  inference plus two consumer directories, not a built interpreter.
- **`stage1.md:38-45` recommends a technique AGENTS.md forbids.** It points at
  `packages/intltool/generic.lua:11`, `export PERL5LIB=...`, as "the same
  technique would make this recipe self-correcting". `AGENTS.md:218-222` says
  search flags come from the system and a recipe must never `export` them;
  intltool's line is the documented "recipe-local workaround" exception, not a
  precedent to copy. A correct statement of the right technique belongs in
  this section instead (below). I cannot edit `stage1.md`; flagging it.

### Design decision: the fix should be ONE shared value, in the python package

Ruling on the question this review raised — derive from a shell variable, from
`$PREFIX`, or from a single shared value: **a single shared value, owned by
`packages/python`.** The three alternatives are each worse:

- **A shell variable exported from `packages/<sys>/generic.lua`** would have to
  be repeated in every system file (there are ~12), so it duplicates the
  string more times than the five consumer recipes do now. `AGENTS.md:205-210`
  reserves the system recipe for facts about the *target system*; the Python
  version is a package fact, identical on all of them.
- **Deriving from `$PREFIX` at build time** is wrong twice over. `$PREFIX` is
  the *search* path, not the install target (`$OUT` is), so it answers the
  wrong question; and it is only populated if `python` happens to have been
  built first, which no pure-Python recipe currently requires. A
  `for d in "$PREFIX"/lib/python3.*` probe would make the install path depend
  on queue order — a worse failure mode than the one being fixed.
- **`export` in a recipe** is explicitly banned (see the `intltool` note
  above).

So: one plain Lua file in the python package's directory, holding the
directory string, required relatively by each consumer — the loader already
supports `require("./x")` / `require("../x")` (`AGENTS.md:62`, `src/loader.lua:241-274`),
and a relative require of a module that does not call `recipe()` adds nothing
to the build queue, so it costs no CPython clone:

```lua
-- packages/python/sitepackages.lua
-- The single definition of where pure-Python packages install in this tree.
-- CPython's posix_prefix scheme puts purelib at
-- lib/python<XY>/site-packages (Lib/sysconfig/__init__.py, _INSTALL_SCHEMES).
-- <XY> is the major.minor of packages/python/source.lua's version field
-- ("3.14.7" -> 3.14); keep the two in step when CPython is bumped.
return "lib/python3.14/site-packages"
```

and each consumer, e.g. `packages/flit-core/generic.lua`:

```lua
require("flit-core@source")

local SITE = require("../python/sitepackages")

return recipe({
    sitepackages = SITE,   -- becomes $sitepackages in the build body
    build = [[
        cp -r $NESTDIR/source/flit-core/* .
        ...
        mkdir -p $OUT/$sitepackages
        cp -r flit_core $OUT/$sitepackages/
        cp LICENSE $OUT/$sitepackages/flit_core/LICENSE
    ]]
})
```

`sitepackages` is a recipe field, so `src/loader.lua:424-434` emits it as a
shell variable in this block before the build body, with no `export` and no
new loader mechanism. Do **not** have consumers `require("python@source")` to
read `version`: that runs the source recipe, which appends to the build queue
and whose body is a `git clone --depth=1` of CPython into a fresh
`mktemp -d` `$WORK` — five extra full clones of CPython per nest for a string
constant. `packages/python/source.lua` should carry a comment pointing at
`sitepackages.lua` so the pin and the directory stay visibly coupled.

Until that lands, `python3.14` spelled out in each recipe is correct and the
build is right; the residual risk is drift on the next CPython bump.
