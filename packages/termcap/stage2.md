ACCEPT

# termcap 1.3.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/termcap/`. I did not build.

## What the recipe gets right

- **`export CC="$CC -std=gnu89"` at line 8 is AGENTS.md's own worked example,
  verbatim.** The rule says "Old C code (termcap 1.3.1): `export CC="$CC
  -std=gnu89`". The comment gives the reason (it predates prototypes, and NDK
  clang defaults to C23 where implicit declarations are errors), and appending
  to `$CC` rather than replacing it keeps the system's compiler. This is the
  recipe the rulebook names.
- The **hand-written `termcap.pc` at lines 14-17 is load-bearing, not
  decoration**, and adder A's finding #8 is right to preserve it. GNU termcap
  ships no `.pc` at all, but `readline.pc` carries
  `Requires.private: termcap`; without a `termcap.pc` to resolve, a consumer
  linking `-lreadline` statically gets an unresolved `tinfo`/`tgetent` family.
  So the chain is:

  ```
  readline.pc --Requires.private--> termcap.pc --> $PREFIX/lib/libtermcap.a
  ```

- **Writing `$PREFIX` into the `.pc` at recipe time, rather than baking `$OUT`
  and letting the loader rewrite it, is the more robust of the two approaches.**
  `$PREFIX` is already the final merged location, so the file is correct the
  moment it is written and does not depend on the loader's rewrite loop. The
  sibling recipe `packages/elfutils/generic.lua:17-19` hand-copies a generated
  `.pc` and *does* rely on the rewrite; both work, but this one has one less
  moving part.
- `--disable-shared --enable-static` is the static control the prefix uses
  everywhere, and `$AUTOCONF_CONFIGURE_FLAGS` supplies the prefix.
- `printf` is not in AGENTS.md's literal build-body list (`cp`, `./configure`,
  `cmake`, `make`, `make install`, `touch`, `find`, `mkdir`, `cat`-heredocs).
  It is the closest available tool to a `cat`-heredoc for a generated file
  with a substituted value, and the file it writes has to be generated — so I
  read this as within the spirit of the rule. A `cat > … <<EOF` heredoc would be
  the strictly conforming form, with the same result.
- `require("termcap@source")` names no missing package.

## One cosmetic inaccuracy

`generic.lua:10` has `touch aclocal.m4 configure config.h.in`, but **termcap has
no config header**: verified against the real tree, `configure.ac` has no
`AC_CONFIG_HEADERS` and the tree ships no `config.h.in`. The `touch` creates a
stray zero-byte file and protects nothing — but there is also nothing to
protect, so this is the harmless variant of the guard bug, not the
`config_h.in`-style defect that `sed` in this same shard has. Worth tightening
when the file is next edited:

```
        touch aclocal.m4 configure
```

## Carried to the build

- `lib/libtermcap.a` — `llvm-objdump -f lib/libtermcap.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Also confirm no `libtermcap.so*` appears: `--disable-shared` did its job.
- `include/termcap.h` — `[ -f include/termcap.h ]`. That is the only public header.
- `lib/pkgconfig/termcap.pc` — `[ -f lib/pkgconfig/termcap.pc ]`, and `grep '^prefix=' lib/pkgconfig/termcap.pc` must show the **final** prefix, not a `tmp.` staging path. This is the direct check for the hand-written file.
- `bin/infocmp` and `bin/tic` — `[ -x bin/infocmp ]` if installed; both are target programs, so **never run them**.
- **The cross-package check that actually settles this package:**
  `PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig pkg-config --static --libs readline`
  must name `-ltermcap`. If it does not, this `.pc` is malformed or missing and
  `readline`'s static link is broken — a failure that would otherwise surface
  much later, in whichever consumer first links readline statically.
