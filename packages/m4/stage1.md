# m4 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.4.20 (ftp.gnu.org)
- Build system: autotools
- Installs: `bin/m4`, `bin/m4bug`, `share/man/man1/m4.1`, `share/info/m4.info`.
  A macro-language interpreter and a shell; no library, no headers, no `.pc`.
- Requires: `m4@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The interesting part of this recipe is that it **pre-builds the generated files in order, and refuses to regenerate the man page.** `generic.lua:9-12` runs `make -j1 -C lib`, `-C src`, `.version` and `-C doc version.texi` before the top-level `make`, because those are the ordered prerequisites the top-level make would otherwise re-derive — and re-deriving the info file requires running tools in an order that a cross build cannot satisfy. Then `touch doc/m4.1` at `:15` with the comment that matters: *"Keep the shipped man page; regenerating it would execute the Android m4 binary on the build host."* That is exactly the no-emulation rule applied correctly — GNU m4's doc build bootstraps itself by running the freshly built m4. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The doc-bootstrap trick is the same everywhere, so the `touch` is still what saves it. The open question is whether m4's `src/` uses anything POSIX that mingw lacks — `gnulib` provides most of it, but m4 is old enough that a POSIX-2017 assumption could bite. What would settle it: whether `make -C src` links. |
| clang-native | WILL BUILD | As above. Natively the doc build *could* run, but the recipe still `touch`es rather than regenerating, so the behaviour is uniform — which is the right call. |

**API level notes.** None. GNU m4 is a portable C program built on gnulib, and
the parts that would touch the platform (`fopen`, `getenv`, `popen`) are all
present at every Bionic level. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The `touch doc/m4.1` is the single most important line in this recipe and
   it is a genuine no-emulation guard, correctly commented.** Without it, the
   top-level `make` would rebuild `doc/m4.1` by running `src/m4` — the *target*
   binary — on the build host. On `aarch64` that is an exec-format error; worse,
   on `x86_64-android35` it would be a **native-architecture Android binary
   that would actually try to run**, and running it is forbidden outright
   (AGENTS.md:373-379). This is the same class as the groff example AGENTS.md
   names in that rule, and the recipe handles it correctly.
2. **The ordered sub-makes at `:11-15` are a workaround, not an
   optimisation.** Do not "simplify" them to a single `make -j1`. The order
   `lib` → `src` → `.version` → `version.texi` is the real dependency order the
   top-level makefile encodes, and running it explicitly is what keeps the
   top-level pass from trying to bootstrap.
3. **`make -j1 .version`** is the least obvious of the four. It is a phony
   target that stamps the version file; without it the top-level make reaches
   it later, at a point where `src/m4` may not be considered up to date. Worth
   a comment if anyone touches the sequence.
4. **The `m4bug` binary is installed and is a host program in spirit** — it is
   a script-generation tool. It is built because upstream's `make install`
   includes it and there is no switch to omit it. Unlike brotli's tools
   (which the tree's own comment acknowledges as unavoidable), this one is a
   small target binary that will never be run here. Acceptable, but a reviewer
   may reasonably ask whether `bin/m4bug` belongs in a target prefix.
5. `topackage.md:53` records this as built with no caveats. Consistent.
6. The recipe uses `make -j1` consistently — one of the recipes that gets the
   serial-build rule right.

**How to verify once built.**

- `bin/m4` and `bin/m4bug` exist; `share/man/man1/m4.1` exists.
- `file bin/m4` reports `ELF 64-bit LSB pie executable, ARM aarch64, for
  Android 24, built by NDK r28c`.
- `$OBJDUMP -f bin/m4` shows the target machine.
- `llvm-nm --defined-only bin/m4 | grep -cw m4` non-zero (the version symbol).
- **Check the build log contains no attempt to run `src/m4`.** If you see
  `./src/m4` or `src/m4` invoked as a command, the `touch` guard has been lost
  and the build is about to violate the no-emulation rule.
- `head -3 share/man/man1/m4.1` should be roff (`.TH`), not a regenerated file
  with a build timestamp — confirming the shipped page was kept.
