REJECT

# less — stage 2 review

## What the forecast gets right

**The `nl_langinfo` blocker is CONFIRMED, and the framing that it is an
API-26 gate rather than a permanent wall is CORRECT.** I verified both halves
independently:

- `sysroot/usr/include/langinfo.h:97` declares
  `char* _Nonnull nl_langinfo(nl_item __item) __INTRODUCED_IN(26);`
- I compiled a probe calling `nl_langinfo(CODESET)` with the NDK wrappers:
  **API 24 fails** (`error: call to undeclared function 'nl_langinfo'; ISO C99
  and later do not support implicit function declarations`), **API 26 and
  API 35 compile**.

So the divider is genuinely **21 and 24 fail, 35 compiles**, and an
`android26`-or-later target would fix this package. The tree has none below
35 today, which is why it is currently blocked. This is a category (iii)
finding: the backlog framing ("blocked") is accurate as a statement about the
targets that exist, but it reads as permanent and is not.

The same root cause applies to `pkgconf` and `gawk` (both in the backlog), so
one `aarch64-android26` target would unblock three packages at once. That is a
tree-level observation worth surfacing.

## Required changes

1. **`packages/less/generic.lua:8` — the timestamp guard touches a
   `config.h.in` that does not exist.** I listed the unpacked tree: less 685
   ships **no config header template at all** — there is no `config.h.in` at
   any depth. `touch config.h.in` therefore **creates a bogus empty file**.

   Replace line 8 with:

   ```sh
           touch aclocal.m4 configure
   ```

   and append a comment so the omission reads as deliberate:

   ```sh
           # less 685 ships no config header template, so there is no
           # config.h.in to touch.
   ```

2. **`packages/less/generic.lua:10` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

3. **`packages/less/stage1.md` — mark the backlog entry as deferred, not
   blocked.** Say explicitly that `android26`-or-later fixes it, and that the
   only thing keeping it out is the absence of such a target in this tree. That
   turns a dead entry into a queued one.

## A second thing to check that the forecast does not mention

`generic.lua:7` is `cp -r $NESTDIR/source/less/* .` and line 8's guard is fine
once fixed, but **`require("ncurses")` at `generic.lua:2`** means this package
pulls in ncurses — which `packages/ncurses/generic.lua` builds **shared**
(`--with-shared`). Given `nl_langinfo` is the only reported Android wall,
confirm the forecast covers the ncurses interaction too; if less compiles at
API 35 but ncurses does not (or vice versa), that changes which of the two is
the real blocker.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/less` | `test -x $PREFIX/bin/less` |
| `$PREFIX/share/man/man1/less.1` | `test -s $PREFIX/share/man/man1/less.1` |
| terminal capability linked | `llvm-nm --undefined-only $PREFIX/bin/less \| grep -cE 'tigetstr\|setupterm'` → non-zero |
| **the check that decides the API gate** | compile `nl_langinfo(CODESET)` against the target wrapper — API 24 fails, 26+ does not; that one probe settles every row |

Build on `aarch64-android35` first: it is the only Android target in the tree
where `nl_langinfo` resolves, so it is the one that can actually produce
artifacts.