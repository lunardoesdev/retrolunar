ACCEPT

# xz 5.8.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/xz/`. I did not build.

## Adder A's finding #3 — ruling

**The observation is right; the framing is slightly off, and it is not a
defect.** Adder A writes that xz "contradicts what `topackage.md:87` records as
verified". Read line 87 again:

> `lib/liblzma.so` is "ELF 64-bit LSB shared object, ARM aarch64, for Android
> 24, built by NDK r28c"

The backlog does not claim xz is static — **it records the shared object as an
observed fact**, with its machine and API level. So there is no contradiction
between the recipe and the backlog, and nothing has been mis-recorded.

What is real is a **policy inconsistency worth one line of comment**: every
other package in this prefix is static, and xz is one of three exceptions
(the others are `gettext`, and `binutils`/`e2fsprogs` where shared is
deliberate and load-bearing). xz's shared `liblzma.so` needs a loader path a
target has no use for, exactly the reasoning AGENTS.md gives for requiring
`-Ddefault_library=static` from meson.

I am **not** failing xz on this, because changing it is a decision, not a
correction: `--disable-shared` would remove the `.so` that a recorded,
verified artifact currently provides. Adder A's own closing words — "needs a
deliberate decision" — are the right conclusion. Two acceptable resolutions:

- add a comment to `generic.lua:6-7` stating that the shared `liblzma.so` is
  intentional and why (a consumer that dlopen()s it, or LFS parity), **or**
- add `--disable-shared` to the `./configure` line and update `topackage.md:87`
  to record `lib/liblzma.a`.

The second is the more consistent choice for this prefix. Either way the
decision should be written down rather than left to the next reader.

## What the recipe gets right

- **The timestamp guard is correct.** Verified against the real tree:
  `AC_CONFIG_HEADERS([config.h])` with `config.h.in` at the top level, which is
  what line 16 touches. This is a minority in this tree — `sed` in this same
  shard gets it wrong, and eighteen recipes in the a–g shard do — so it is
  worth stating.
- Every flag is a real xz option and all six are the right cuts: `--disable-nls`
  (no gettext in the prefix), `--disable-unxz --disable-lzmadec
  --disable-lzmainfo --disable-lzlinks` (the optional helpers, none wanted),
  `--disable-scripts`, `--disable-doc`. Nothing host-side survives, and nothing
  is hardcoded to a target.
- `./configure $AUTOCONF_CONFIGURE_FLAGS` takes the prefix from the system, so
  install lands in `$OUT`. `make` / `make install` are bare — **not** a
  defect; bare `make` is serial by default, which I verified (`MAKEFLAGS` is
  empty without `-j`).
- `require("xz@source")` names no missing package.

## One non-blocking observation

`zstd` in this shard passes `HAVE_LZMA=0`, so nothing in the prefix currently
consumes `liblzma`. If a future consumer wants xz compression, the `.a` is
there and the `.pc` is there; the missing piece would be a `-llzma` on a link
line, which is the consumer recipe's business, not this one's.

## Carried to the build

- `bin/xz` — `llvm-objdump -f bin/xz | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw), and `llvm-objdump -p` should name Android 24 on the recorded system. `--disable-unxz` etc. mean only `xz` itself.
- `lib/liblzma.so` (or `lib/liblzma.a`, per the decision above) — `[ -e lib/liblzma.so ] || [ -f lib/liblzma.a ]`; record which, because that is the observable difference the decision turns on.
- `lib/pkgconfig/liblzma.pc` — `pkg-config --modversion liblzma` → `5.8.1`.
- `include/lzma.h`, `include/lzma/*.h` — `[ -f include/lzma.h ]`.
- `bin/lzmadec`, `bin/lzmainfo`, `bin/unxz`, `bin/lzlink` must all be **absent** — the four `--disable-*` flags did their job, and each one appearing means a flag was dropped.
- No `.mo` files anywhere under `$OUT/share/locale` — `--disable-nls` did its job.
- **Never run `bin/xz`.**
