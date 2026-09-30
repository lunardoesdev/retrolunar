# libyaml forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.2.5
- Build system: autotools
- Installs: static `libyaml.a`, `yaml.h`, and `yaml-0.1.pc` (note the
  versioned `.pc` name). The `yaml` reference parser and the `hpricot` test
  tool are not installed.
- Requires: `libyaml@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--enable-static --disable-shared --with-pic --disable-python-bindings` at `:10`. The last one matters: libyaml's optional Python bindings would need a *target* Python, which must never be run here. The library itself is a self-contained C parser with no dependency beyond `stdio` and `string.h`. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. libyaml is portable C with no platform code. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. libyaml is one of the most portable libraries in
this shard — a hand-rolled recursive-descent parser over a `FILE*` or a memory
buffer, with `fgetc`/`fread` as its entire I/O surface. No API-gated symbol,
no `posix_spawn`, no `O_BINARY` (the parser does not open files itself; the
caller supplies the `FILE*`). `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The source-fetch decision is the interesting part of this recipe and it
   is still in place.** `source.lua:6-8` fetches from **pyyaml.org first**,
   with the GitHub release asset as a fallback, and the comment says why:
   *"the GitHub tag archive has no generated configure."* That is the same
   class of problem as the glog case I hit in the previous round — a
   git-host archive with no `configure` — handled correctly here by preferring
   the canonical release host. The two URLs are joined with `||` on one line,
   as AGENTS.md:145 requires. **Do not "simplify" this to the GitHub URL**;
   the build would fail at `./configure`.
2. **The `.pc` file is named `yaml-0.1.pc`, not `yaml.pc`.** That trips people
   up: the correct invocation is `pkg-config --modversion yaml-0.1`. A
   consumer that guesses `yaml` gets "package not found" and may conclude the
   package is broken. Worth knowing before the first consumer.
3. **`--disable-python-bindings` is the right switch but the recipe's comment
   attributes it to the wrong thing.** The comment at `:8-9` mentions the
   reference parser, hpricot and uchardet; the Python bindings are disabled by
   the explicit flag and are not mentioned. Minor, but the flag is the one
   that protects against executing a target interpreter, so it deserves a
   line.
4. **uchardet is worth a second look.** The comment says the optional uchardet
   encoding probe is off because "the generic build would otherwise try to
   compile it". libyaml 0.2.5 auto-detects uchardet via pkg-config; if a
   `uchardet.pc` ever appeared in this prefix, libyaml would silently start
   linking it. Nothing in the recipe prevents that. Low risk, but it is a
   hidden dependency surface.
5. `make -j1` is present at `:13` — correct.
6. `topackage.md` records this as built: *"static libyaml.a; pkg-config
   --modversion yaml-0.1 reports 0.2.5"*, which matches the `.pc` naming point
   above exactly. Consistent.

**How to verify once built.**

- `lib/libyaml.a` exists; `include/yaml.h` exists.
- `pkg-config --modversion yaml-0.1` reports 0.2.5 — **note the `-0.1`
  suffix**, and do not use `yaml` as the module name.
- `pkg-config --cflags --libs yaml-0.1` resolves.
- `$OBJDUMP -f lib/libyaml.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libyaml.a | grep -cw yaml_parser_load` non-zero
  — the canonical libyaml entry point.
- `ls $OUT/bin/` must be empty: no `yaml` reference parser, no `hpricot`.
- Confirm no uchardet crept in: `llvm-nm -u lib/libyaml.a | grep -c
  uchardet` must be **0**.
