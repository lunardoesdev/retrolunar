REJECT

# sysklogd 2.7.2 — stage 2 review

Reviewed against AGENTS.md, the NDK r28b sysroot, and the unpacked tree at
`nest/source/sysklogd/`. I did not build.

**Adder A's finding #4 is CORRECT.** Verified directly against the sysroot:

```
$ grep -n getsubopt $NDK/.../sysroot/usr/include/stdlib.h
177:int getsubopt(char* _Nonnull * _Nonnull __option, char* _Nonnull const* _Nonnull _tokens, char* _Nullable * _Nullable _value_ptr) __INTRODUCED_IN(26);
```

`getsubopt` is a GNU extension gated at API 26, so it is absent at API 21,
23 **and** 24.

## Required changes

### 1. `topackage.md:74` — the blocker line undercounts

It currently reads:

```
- [ ] Sysklogd 2.7.2 (blocked: Bionic exposes getsubopt starting API 26; API24 logger compile fails)
```

The first clause states the level correctly; the second then names only
API 24, which is arbitrary and undercounts. In a backlog where a reader is
looking for the lowest system directory that works, this sends them to
`android25` (which does not exist) instead of straight to `android26`. It
should read:

```
- [ ] Sysklogd 2.7.2 (blocked below Android API 26: the logger calls getsubopt, which
  Bionic declares only from API 26 (stdlib.h:177 __INTRODUCED_IN(26)). android21,
  android23 and android24 all fail to compile it; android26 and above are the
  candidates. Not fixable by a patch, which this project does not apply)
```

### 2. `packages/sysklogd/stage1.md` — the per-system rows must say the same thing

`stage1.md` is the document the builder reads first, so if it agrees with the
backlog's undercount it propagates the error. The rows for `aarch64-android21`
and `aarch64-android24` should both be WILL NOT BUILD with the
`__INTRODUCED_IN(26)` reason, and `aarch64-android35` / `x86_64-android35` /
`clang-native` WILL BUILD. If `stage1.md` already says this, change 1 is the
only edit needed.

### 3. Nothing else is required

- **The timestamp guard is correct.** Verified against the real tree:
  `AC_CONFIG_HEADER([config.h])` with `config.h.in` at the top level, which is
  what `generic.lua:7` touches. Unlike `sed` in this same shard, sysklogd gets
  it right.
- `./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system —
  the recipe passes none of its own, which is correct for a package with no
  dependencies and no feature choices. Nothing is hardcoded to a target.
- `make` and `make install` at lines 9-10 are bare. **Not a defect** — bare
  `make` is serial by default, which I verified empirically (`MAKEFLAGS` is
  empty without `-j`). Adder A's finding #7 is right about this and I am
  explicitly declining to fail the package on it.
- `require("sysklogd@source")` names no missing package.

## The blocker is a clean API-level case

Unlike `<stdbit.h>` (diffutils) or `argp.h` (elfutils) in the a–g shard, where
no API level helps because the header is simply absent, this one **is** a real
`__INTRODUCED_IN` gate. `aarch64-android26` and `aarch64-android35` both exist
in this tree, so sysklogd is recoverable by building on one of them. That is
worth saying in the backlog, because it separates sysklogd from the
unrecoverable class.

## Carried to the build

Buildable on `aarch64-android26`+, `x86_64-android26`+ and `clang-native` only.

- `sbin/syslogd` and `sbin/klogd` — `[ -x sbin/syslogd ] && [ -x sbin/klogd ]`. sysklogd installs into `sbin`, not `bin`; that placement is a legacy convention and worth confirming rather than assuming.
- `llvm-objdump -f sbin/syslogd | head -3` → `elf64-littleaarch64`, and `llvm-objdump -p` should name **Android 26 or higher** — that is the check that the `getsubopt` gate was cleared.
- `include/` — sysklogd is two programs and installs no headers.
- No `.pc` and no library.
- **Never run `sbin/syslogd`** — it would try to open `/dev/log`.
