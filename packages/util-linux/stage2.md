ACCEPT

# util-linux 2.42 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/util-linux/`. I did not build.

**Adder A's finding #8 is CONFIRMED intact, and the six feature switches are
the strongest part of this shard.** Each has a *reason*, not just a name, and
two of the reasons are non-obvious enough that they could not have been guessed:

- `--without-cap-ng` — the comment cites `configure.ac:1690`, which is the
  specific line where `setpriv` pulls in `cap_ng`, and notes that libcap is
  neither in the prefix nor reachable upstream. Naming the line number is what
  makes this auditable.
- `--disable-more` and `--disable-vipw` — the comment explains the real cause
  (`_PATH_VI` from glibc's `<paths.h>`, which Bionic does not have) and, more
  valuably, that **both have upstream `build-*` meson options**, so they are
  switched off rather than patched. That is AGENTS.md's rule followed exactly:
  a configure switch exists, so use it.
- `--disable-pylibmount --disable-liblastlog2 --disable-libuuid` for absent
  libraries, and `--disable-asciidoc` — the comment notes that the last is
  "what stops the man pages from being regenerated", i.e. it is what keeps the
  shipped `.1` files from being rebuilt with a tool the host may not have. That
  is the same help2man/man-page hazard `diffutils` and `texinfo` deal with, and
  it is handled by the right lever.
- `--disable-nls`, since there is no gettext dependency here.

## What else the recipe gets right

- `./configure $AUTOCONF_CONFIGURE_FLAGS` takes the prefix, `--host`, `--build`
  and every search flag from the system. Nothing is hardcoded to a target: no
  architecture, no API level, no `-I`/`-L`, no `export` of `CPPFLAGS`,
  `LDFLAGS` or `CFLAGS`.
- **The timestamp guard is correct.** Verified against the real tree:
  `AC_CONFIG_HEADERS([config.h])` with `config.h.in` at the top level, which is
  what line 28 touches. (`sed`, in this same shard, gets the equivalent wrong
  with `config_h.in`.)
- `require("ncurses")` is a real dependency and `packages/ncurses` exists;
  util-linux's terminal utilities genuinely need it.
- `make` and `make install` are bare. **Not a defect** — bare `make` is serial
  by default, which I verified empirically (`MAKEFLAGS` is empty without `-j`).
  Adder A's finding #7 is correct and I am explicitly not failing it on that.

## One thing the forecast should be careful about

util-linux is the one package here whose artifact list is genuinely hard to
bound: it installs dozens of programs into `bin/`, `sbin/`, `usr/bin/` and
`usr/sbin/`, plus `include/`, `share/man/`, `share/bash-completion/` and
`lib/`. `stage1.md` should give a *count* and the key paths rather than
enumerate, and should state explicitly that the terminal utilities
(`tty`, `stty`, `su`) are present because ncurses/termcap are in the prefix —
that is the part a reviewer would otherwise wonder about.

## Carried to the build

- `bin/mount`, `umount`, `lsblk`, `blkid`, `findmnt`, `kill`, `uptime` — `[ -x bin/lsblk ]`. The split between `bin/` and `sbin/` is upstream's; record the actual directory rather than assuming.
- **`bin/kill` and `bin/uptime` are the cross-package check that matters most**: `packages/coreutils/generic.lua` passes `--enable-no-install-program=kill,uptime` precisely so it does not collide with this package. After both build, exactly one `kill` and one `uptime` must exist in `$PREFIX/bin`, and it must be util-linux's. Two is a collision; zero means coreutils' exclusion flag is being ignored.
- `sbin/setpriv` — present or not tells you whether `--without-cap-ng` was the only thing keeping libcap out; `ldd`-equivalent inspection via `llvm-objdump -p` should show no `libcap`.
- `include/` — util-linux installs `blkid.h`, `libmount.h`, `uuid.h`; note that `--disable-libuuid` and `--disable-liblastlog2` remove the libraries, so any header still present is a leftover worth checking.
- `lib/pkgconfig/*.pc` — check which survived; the `.pc` set should not reference `libmount` or `libuuid` if those were disabled.
- **Never run any installed util-linux binary** — `su`, `passwd` and `login` would touch the build host.
