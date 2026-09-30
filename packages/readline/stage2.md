ACCEPT

# readline 8.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/readline/`. I did not build.

## What the recipe gets right

- **`export CFLAGS="$CFLAGS -fPIC"` at line 8 is AGENTS.md's own worked
  example, verbatim.** The rule says the search flags come from the system,
  "Exception: recipe-local workarounds with a comment explaining why (e.g.
  readline needs `CFLAGS="$CFLAGS -fPIC"` because python links it into a shared
  module)". The comment at line 7 gives that reason, and appending to `$CFLAGS`
  rather than replacing it keeps the system's flags. This is the recipe the
  rulebook names, so it is exactly right and should not be "tidied" into a
  different shape.
- **The guard is correct.** Verified against the real tree:
  `AC_CONFIG_HEADERS(config.h)` with `config.h.in` at the top level, which is
  what line 11 touches. (`examples/rlfe/config.h.in` also exists, but that
  belongs to a bundled example, not to the top-level `config.status`.)
- `require("termcap")` is a real dependency and `packages/termcap` exists.
  `--without-curses` and the comment "Use the existing termcap dependency
  instead of adding ncurses here" is the right call: it avoids dragging a
  second terminal library into a prefix that already has one, and
  `packages/termcap` is on the same page — see `packages/termcap/stage2.md` for
  the hand-written `termcap.pc` that makes this resolve.
- `--disable-shared --enable-static` is the static control the prefix uses
  everywhere. `make -j1` is explicit and serial; `make install` is an install
  target. Nothing is hardcoded to a target.

## Adder A's finding #8 — ruled

The "readline.pc's `Requires.private: termcap`" item is **intact and load-
bearing**. `termcap` ships no upstream `.pc`, so `packages/termcap/generic.lua:14-17`
writes one by hand specifically so that readline's `Requires.private: termcap`
resolves. The dependency chain is therefore:

```
readline.pc  --Requires.private-->  termcap.pc  -->  $PREFIX/lib/libtermcap.a
```

If `termcap.pc` is missing, `pkg-config --cflags readline` still works (it
resolves `Requires.private` only for static linking via `--static`), but a
consumer linking `-lreadline` statically gets an unresolved `tinfo`/`tgetent`
family. Worth stating because the two recipes have to be fixed in step.

## Non-blocking observation

`make install` is unflagged. Not a defect — install targets are not compiles —
and `make` on line 13 is explicitly `-j1` anyway, which is the rule's exact
wording.

## Carried to the build

- `lib/libreadline.a` — `llvm-objdump -f lib/libreadline.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). `-fPIC` is what makes this usable in a shared module; `llvm-objdump -h` showing `.text` without a text relocation is the check it took.
- `lib/libreadline.so*` must be **absent** — `--disable-shared` did its job.
- `include/readline/readline.h`, `include/readline/history.h` — `[ -f include/readline/readline.h ] && [ -f include/readline/history.h ]`.
- `lib/pkgconfig/readline.pc` — `pkg-config --modversion readline` → `8.3`, and **`pkg-config --static --libs readline` must name `-ltermcap`**. That is the one check that proves the `termcap.pc` chain works end to end.
- `lib/pkgconfig/termcap.pc` must be present in the same prefix; its absence is a `packages/termcap` failure, not a readline one, but readline's static link depends on it.
- **Never run anything readline installs** — it is a library, so there is nothing to run; the point is that its `examples/` and `rlfe` trees are correctly absent.
