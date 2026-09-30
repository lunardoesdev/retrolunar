# python build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.14.7, fetched **by git tag** (`v3.14.7` from
  `github.com/python/cpython`) — the AGENTS.md:149-173 pattern, guarded by
  `if [ ! -d src ]`. A tarball would not do, because CPython's release
  tarballs need a release-time build step; the git tag is the source.
- Build system: autotools
- Installs: `bin/python3`, the stdlib under `lib/python3.14/`, the `pyconfig`
  data, and `lib/pkgconfig/python-3.14.pc`. No `pip` —
  `--without-ensurepip` deliberately omits it.
- Requires: `readline` (exists), `python@source`. Note this is the one recipe in
  the shard whose `require()` is for a *library* a Python extension links
  against, and it makes python the reason `readline` is in the tree.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **UNCERTAIN** | Two switches are deliberate and correct: `--with-build-python=python3` names the *host* interpreter that runs the build, and `--without-ensurepip` stops the build from trying to install pip (which would need a network fetch and a host pip). `--disable-test-modules` keeps the test packages out of the install. What leaves the row uncertain: CPython's `configure` probes for many optional facilities, and its own cross-compilation support is known to be imperfect. See risks 2 and 3. |
| aarch64-android24 | **UNCERTAIN** | As above; representative system. |
| aarch64-android35 | **UNCERTAIN** | As above. |
| x86_64-android35 | **UNCERTAIN** | As above. |
| x86_64-mingw | UNCERTAIN | As above, plus CPython on mingw is a well-worn path but a large surface. |
| clang-native | WILL BUILD | A native CPython build is completely ordinary. |

**API level notes.** Unresolved, and this is the honest answer: CPython's
`configure` probes for a long list of libc facilities, and I have not read them
all. The specific ones I *can* name as risk 3 are the `pthread` and
`dlopen`/`dlsym` probes, and CPython's `_ctypes` and `_tkinter` modules
respectively — but the `test_modules` are disabled here, which removes the
worst offenders. **The API level is plausibly a variable for this package and I
am not able to settle it by reading the recipe.** That is why these rows are
UNCERTAIN rather than a confident WILL BUILD or WILL NOT BUILD.

**Risks / what a reviewer should check.**

1. **`--with-build-python=python3` is the load-bearing switch and it is right.**
   A cross build needs a *host* Python to run the build, and confusing that
   with the target interpreter is the classic CPython cross-compile mistake.
   The recipe uses the name, not a path, so it resolves from `PATH` — and the
   loader puts `$NATIVE_PREFIX/bin` first, so a prefix-provided Python would
   win over `/usr/bin/python3`. That is arguably *wrong* for a build tool
   (a target-shaped Python is not a good build interpreter) and is worth a
   reviewer's check. **What would settle it: which `python3` is first on `PATH`
   at build time.**
2. **The `Makefile.pre.in` touch at `:15` is the one that is easy to miss:**
   `find . -name 'Makefile.in' -o -name 'Makefile.pre.in' | xargs touch`. The
   `-o` binds loosely enough that CPython's second template is covered — this
   is exactly the AGENTS.md:234 note, and the only recipe in the shard that
   applies it. **Preserve it.** Dropping `Makefile.pre.in` would cause make to
   look for a `python` build in a way that fails confusingly.
3. **CPython's cross-compilation needs a host `sysconfig`/`_sysconfigdata`.**
   The usual approach is to build once natively to get the target's
   `_sysconfigdata`, and this recipe does not do that. A cross-built CPython
   without it will build but will misreport its paths at runtime. **This is the
   most likely substantive gap in the recipe**, and it is a runtime problem the
   build cannot detect. Worth confirming whether 3.14 changed this — the
   `_sysconfigdata` mechanism has been reworked in recent versions.
4. **`readline` is required, and the `python3.14` literal is now correct in
   every consumer.** This recipe (3.14.7) is the tie-breaker: `jinja2`,
   `markupsafe` and `meson` were corrected from `python3.13` to
   `python3.14`, joining `packaging`, `setuptools` and `flit-core`. At 3.13
   the module landed in a directory this interpreter never searches, and the
   failure was a silent `ModuleNotFoundError` at runtime on the target rather
   than a build error.

   **The value is duplicated across five consumers and should become one
   shared module.** A reviewer proposed a single
   `packages/python/sitepackages.lua` returning the string, required
   relatively by each consumer and passed as a recipe field so it becomes
   `$sitepackages` with no `export` and no loader change. That was
   deliberately **not** done in the rework pass: it changes this recipe's
   shape and depends on relative-require behaviour, so it deserves its own
   reviewed change rather than riding along. Recorded here so the literal is
   not independently re-derived or "cleaned up" by each package. Two wrong
   approaches to avoid: a system-file `export` would need repeating in ~12
   system files, and globbing `$PREFIX` would make the install path depend on
   queue order.

   **Do not have a consumer `require("python@source")` to learn the version.**
   That queues this recipe and its `git clone --depth=1` of CPython into a
   fresh `mktemp -d` per block — a whole CPython checkout to learn a directory
   name. Checked across the tree: no recipe does this today.
5. **`--without-ensurepip` is correct and important.** Without it, `make install`
   runs `ensurepip`, which bootstraps pip from bundled wheels — a host
   operation that would either fail or install a *target* pip that cannot run.
6. **No `dist-info` anywhere in the pure-Python recipes**, which is consistent.
7. `make` at `:16` is not `make -j1` — and for CPython that is a genuinely
   painful build to parallelise, so serial is the right outcome by accident.
8. **`topackage.md` has no entry for python.** That is a significant gap: it
   is the interpreter four other packages in this shard install *into*, so its
   absence is the root of risk 4 going unnoticed.

**How to verify once built.**

- `bin/python3` exists; `file bin/python3` reports the target machine.
- `lib/python3.14/os.py` exists — the presence of the stdlib under the
  *versioned* directory is the check that ties risk 4 together.
- `lib/pkgconfig/python-3.14.pc` exists.
- **Compare the installed path with the pure-Python packages:** if
  `jinja2`/`markupsafe`/`meson` say `python3.13` and this says `python3.14`,
  they are in the wrong place. That comparison is the single most valuable
  check across this whole shard.
- `llvm-nm --undefined-only bin/python3 | grep -cw readline` should be
  non-zero, proving `readline` from this prefix is what got linked (risk 1 of
  the header block: it is the only declared dependency).
- `_sysconfigdata`: `find lib/python3.14 -name '_sysconfigdata*'` — if empty,
  risk 3 is live and the interpreter will misreport its paths.
- `$OBJDUMP -f bin/python3` shows the target machine, which catches an
  accidental host build.
- **Do not run the target `python3`.** Static inspection only.

**Recommendation for a future change (not done here): the `python3.14`
literal is duplicated across consumers and should become one shared module.**
The `posix_prefix` scheme puts purelib at
`{base}/lib/{implementation}{py_version_short}{abi_thread}/site-packages`,
with `abi_thread` empty unless CPython is configured `--disable-gil` — which
`packages/python/generic.lua` does not pass — so the literal
`lib/python3.14/site-packages` is correct and is what flit-core, jinja2,
markupsafe, meson, setuptools and wheel each spell out independently. A
single `packages/python/sitepackages.lua` returning that directory string,
required relatively by each consumer and passed as a recipe field so it
becomes `$sitepackages`, would remove the duplication with no `export` and no
loader change. It is deliberately **not** created in the current pass: it
changes python's recipe shape and depends on relative-require behaviour, which
is a riskier change than the duplication it removes and deserves its own
reviewed change.

Two things a consumer must **not** do: read the version via
`require("python@source")` — that queues python's recipe and its
`git clone --depth=1` of CPython into a fresh `mktemp -d` per block, so a
whole CPython checkout to learn a directory name — and export a `$PREFIX`
glob to find the directory, since `$PREFIX` is the *search* path rather than
the install target, which would make the install path depend on queue order.
