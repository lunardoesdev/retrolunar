REJECT

# vim 9.2.1143 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

**Adder A's finding #1 is CORRECT, and it is the most serious defect in this
shard.** The forecast also finds it, at `stage1.md:44-54`, and calls it "the
one real design finding in this file" — so the diagnosis is right and the
per-system verdicts that sit next to it are not.

## Required changes

### 1. `packages/vim/generic.lua:22` — a hardcoded target triplet in the system-neutral fallback

```
            --host=aarch64-linux-android \
```

Every system exports the machine identity this should come from:
`$HOST_TRIPLET` is `aarch64-linux-android` on the aarch64 Android systems,
`x86_64-linux-android` on x86_64 Android, `x86_64-w64-mingw32` on mingw, and
`$HOST_ARCH`/`$HOST_OS` are the two halves
(`packages/aarch64-android24/generic.lua:96-100`). AGENTS.md requires the
machine identities to come from the system, and requires `generic.lua` to stay
system-neutral.

The consequence is worse than "inconsistent": **the fallback builds the wrong
architecture.** On `x86_64-android35` it configures aarch64 and produces an
aarch64 ELF in an x86_64 prefix; on `x86_64-mingw` it hands
`aarch64-linux-android` to an `x86_64-w64-mingw32-gcc` and the build is
meaningless. The recipe silently works on exactly one of the six families.

**Replace line 22 with:**

```
            --host="$HOST_TRIPLET" \
```

and extend the comment at lines 12-14 to say where the value comes from:

```
        # --host is required: vim's configure runs a test program to decide
        # whether it is cross compiling, and reports "cannot run C compiled
        # programs" without it. It comes from the system's $HOST_TRIPLET, not
        # from a literal: vim's configure is a hand-written script, so it does
        # not read $AUTOCONF_CONFIGURE_FLAGS, but the machine identity is
        # still a system fact and every system exports it.
```

`--host="$HOST_TRIPLET"` expands to exactly `aarch64-linux-android` on the
aarch64 systems, so **the working configuration is unchanged** — this is a
correctness fix for the other five families, not a change to what currently
builds. Note the emitter turns recipe fields into shell variables, so `$HOST_TRIPLET`
is available because the system `setup` fragment exports it.

### 2. `packages/vim/stage1.md:20-22` — three per-system verdicts are wrong

`stage1.md` rates `x86_64-android35` **WILL BUILD** and `clang-native`
**WILL BUILD**, with a parenthetical pointing at its own risk 2. That is not
enough: a build that produces an aarch64 binary for an x86_64 target has not
built, and `clang-native` with `--host=aarch64-linux-android` is a
cross-compile masquerading as a native one. Correct the rows to:

- `x86_64-android35` → **WILL BUILD after change 1**; as written, WILL NOT BUILD (wrong architecture).
- `x86_64-mingw` → **UNCERTAIN** after change 1 (vim's PE path is the least exercised); as written, WILL NOT BUILD.
- `clang-native` → **WILL BUILD** after change 1; as written, a cross-compile with the wrong host.

The `aarch64-android*` rows are correct as they stand and must not change.

### 3. Nothing else is required

The git fetch is deliberate and correct — the release archive ships a prebuilt
`src/configure` while the tag does not, which is AGENTS.md's sanctioned
"tarball known-incomplete, use git" case, and `source.lua:6-8` guards it with
`if [ ! -d src ]`. `--with-tlibdir="$PREFIX/lib"` is right: it is a *search*
path, so `$PREFIX` not `$OUT` (`AGENTS.md:117`), and it makes vim's terminfo
lookup use the prefix's ncurses. The `SYS_VIMRC_FILE` deviation from LFS is
recorded at lines 16-19 and is the right call — LFS edits an upstream source,
which this project does not do. `stage1.md` risk 5's "preserve it" is correct
advice.

`make` and `make install` at lines 26-27 are bare. That is **not** a defect:
bare `make` is serial by default (`MAKEFLAGS` is empty), which I verified.

## Carried to the build

After change 1, all six families are candidates.

- `bin/vim` — `llvm-objdump -f bin/vim | head -3` → `elf64-littleaarch64` on aarch64, `elf64-x86-64` on x86_64 targets and native. **This is the check that catches finding #1**: before change 1 an `x86_64-android35` build yields aarch64 here, and that is the defect, not a success.
- `bin/xxd`, `bin/vimdiff`, `bin/vimtutor` — `[ -x bin/xxd ]`.
- `share/vim/vim92/syntax/syntax.vim` and `share/vim/vim92/defaults.vim` — `[ -f share/vim/vim92/defaults.vim ]`. A missing runtime tree means `make install` did not finish even though `bin/vim` exists.
- `share/man/man1/vim.1.gz` — `[ -f share/man/man1/vim.1.gz ]`.
- The version pin, statically: `strings bin/vim | grep -m1 'Included patches: 1-1143'`. **Never run `bin/vim --version`** — target binary, emulation forbidden.
- `llvm-nm -u bin/vim | grep -c X11` → **0**, proving `--with-features=normal` kept the GUI toolkits out. `stage1.md`'s check is a good one.
