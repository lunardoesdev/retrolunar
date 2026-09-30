ACCEPT

# shadow 4.20.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/shadow/`. I did not build.

## What the recipe gets right

- **The guard is correct.** Verified against the real tree:
  `AC_CONFIG_HEADERS([config.h])` with `config.h.in` at the top level, which is
  what line 7 touches. (`sed` in this same shard gets this wrong — its template
  is `config_h.in`.)
- `./configure $AUTOCONF_CONFIGURE_FLAGS` with no switches of its own. shadow is
  blocked before flags matter, so adding any would be noise; the recipe is
  plain and system-neutral, and nothing is hardcoded to a target.
- `require("shadow@source")` names no missing package.
- `make` and `make install` are bare. **Not a defect** — bare `make` is serial
  by default, which I verified empirically (`MAKEFLAGS` empty without `-j`).
  Adder A's finding #7 is right and I am explicitly not failing it on that.

## The forecast's obligation

`topackage.md:73` records shadow as blocked: *"Android Bionic lacks shadow.h
required by configure"*. That is a **sysroot-absence** blocker, not an
API-level one — the same class as `<stdbit.h>` (diffutils) and `argp.h`
(elfutils) in the a–g shard — so no `aarch64-androidNN` directory unblocks it.
Only a shadow release that stops probing for `shadow.h` would.

`stage1.md` must therefore say WILL NOT BUILD on **every** Android row for that
reason, and must not imply that a higher API level helps. `clang-native` is the
only candidate row, since glibc has `shadow.h`. If `stage1.md` currently
qualifies the blocker by API level, that is a forecast error and the single
required change — the recipe itself needs nothing.

## One thing to verify before the recipe is ever unblocked

shadow's `configure` also probes for `getspent`/`getpwnam`-adjacent behaviour
and, historically, for `libpam`. If the blocker is cleared, the next wall is
likely PAM, which is not in this prefix. Worth a line in `stage1.md` so the
next attempt does not rediscover it — but it is a forecast nicety, not a recipe
defect, and I am not failing the forecast for its absence.

## Carried to the build

Not buildable on any Android target today. On `clang-native`, where
`/usr/include/shadow.h` exists:

- `bin/useradd`, `bin/usermod`, `bin/chage`, `bin/passwd` (or under `usr/bin` depending on the release) — `[ -x bin/useradd ]`. These are target programs; on `clang-native` they are host x86-64 ELF and still must not be run, because they would modify the build host's `/etc/passwd`.
- `etc/passwd`, `etc/shadow`, `etc/group` — `[ -f etc/passwd ]`. **These land in `$OUT/etc`**, so they merge into the prefix's `etc/` on success. That is the one genuinely dangerous artifact in this shard: a builder must not let `$OUT/etc/passwd` overwrite a real system file, and the `cp -rf "$OUT"/. "$NESTDIR/<sys>"/` merge is scoped to the nest, so it is contained. Worth stating explicitly.
- No library and no `.pc`.
- The check that settles the blocker: the configure log must not contain an `AC_CHECK_HEADERS([shadow.h])` failure, i.e. `grep -c 'shadow.h' config.log` shows the header test passed.
