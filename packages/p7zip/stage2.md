ACCEPT

# p7zip review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, p7zip 16.02 (Debian `+dfsg`
repack; SourceForge is unreachable at 522 from this network — verified by the
adder across eight mirrors, and the recipe carries the SourceForge URL as a
documented mirror). Tarball verified with `tar tf` (1373 entries, top dir
`p7zip_16.02/`), extracted to `/home/si/.revE/src2/p7zip_16.02`.

## 1. Is it using the SYSTEM?

Yes, and the mechanism is subtle enough to be worth spelling out. The recipe
runs:

```
make CC="$CC" CXX="$CXX" 7za
```

This is a **make-variable override on the command line**, not an `export` of a
search flag — which is why it does not violate AGENTS.md's prohibition. It is
necessary because `makefile.machine:14-15` hardcodes `CC=gcc` / `CXX=g++`, and
a command-line assignment beats a makefile assignment.

**I verified the override actually reaches the compiler.** Using a distinctive
value:

```
$ make CC=/usr/bin/false CXX=/usr/bin/false 7za -n | grep -oE '^\S+' | sort | uniq -c
    218 /usr/bin/false
```

218 compile/link lines, all with the override. The recursion into
`CPP/7zip/Bundles/Alone` (`makefile:19`, `$(MAKE) -C … all`) does **not** lose
it, which is the thing that could have gone wrong. Correct.

## 2. Is it doing what the package needs?

**`7za` is the right target, and the reasons check out.** `makefile:19-20`:

```
7za: common
	$(MAKE) -C CPP/7zip/Bundles/Alone all
```

`makefile:21` `all:7za sfx` would also build the SFX self-extractor, and
`makefile:24-56` (`7z`, `Client7z`, `7zFM`) pulls in the GTK GUI. `7za` needs
only the compiler. Correct choice.

**The layout claim holds, and this is where p7zip differs from sevenzip.**
`makefile.glb:4-9` carries `-I../../../../C`, and from
`CPP/7zip/Bundles/Alone` four levels up is the tree root, where `C/` lives:

```
$ make CC=gcc CXX=g++ 7za -n | tail -1
g++ -O -s -pipe … -o ../../../../bin/7za  7zCrc.o … 
```

322+ lines, **no `No rule to make target`, no error**, and the output lands at
`bin/7za` — exactly the path the recipe copies from. p7zip **keeps** the `CPP/`
prefix that the 7-Zip 26.03 release tarball also keeps; the adder's stage1
says this explicitly and it is right. (Note this is the opposite of what
`sevenzip/stage2.md` had to correct — p7zip's tree is fine.)

**The no-install-target decision is right.** `makefile.common:115` is the
`install:` target, and it shells out to `./install.sh`, which runs `strip`,
`sed`, `chmod`, `find -exec` and writes shell wrappers — every one of those
outside AGENTS.md's build-body verbs. The recipe's `mkdir -p $OUT/bin` +
`cp bin/7za $OUT/bin/7za` is the correct minimal alternative, and the
exclusion is *additive* rather than a workaround. Good.

`make` is bare, which per AGENTS.md is **not a defect** — make already defaults
to serial.

**`makefile.machine` is correctly treated as a fragment, not an entry point.**
`makefile.common:15` is `include makefile.machine`, reached from the top-level
`makefile`. The recipe does not invoke it directly. Right.

## The Android blocker — the adder found the real one, and I reproduced it

This is the substantive finding in `stage1.md` risk 5, and it holds.
`makefile.machine:16` is `LOCAL_LIBS=-lpthread`, used by `7za`. **Bionic has no
`libpthread`.** My probe against the NDK r28b wrapper:

```
$ aarch64-linux-android24-clang probe.c -lpthread -o /dev/null
ld.lld: error: unable to find library -lpthread
clang: error: linker command failed with exit code 1
rc=1

$ aarch64-linux-android24-clang probe.c -ldl -o /dev/null
rc=0
```

and `find $SYSROOT -name 'libpthread*'` → **no hits**. So `-lpthread` cannot
resolve on any Android system. `LOCAL_LIBS_DLL` (`makefile.machine:17`) adds
`-ldl`, which *does* resolve — but `7za` links `$(LIBS) = $(LOCAL_LIBS)`, not
`LOCAL_LIBS_DLL`, so only `-lpthread` is in play.

**This is a genuine WILL NOT BUILD on the four Android systems, and it is a
platform fact, not a recipe defect.** The fix belongs in the Android system
files or in a `packages/p7zip/android.lua` that drops `-lpthread` (Bionic keeps
pthreads in libc — the same fact AGENTS.md records for cmake's
`THREADS_PREFER_PTHREAD_FLAG`), never as a hardcoded guess in `generic.lua`.
The recipe does not attempt it, which is correct: it has no `android.lua`.

Note the contrast with `clang-native`, where `-lpthread` resolves normally and
the row is WILL BUILD. The adder got this asymmetry right.

## Version

16.02 is the maintained successor to the 2009 original 9.20.1, and is what
Debian and current distros build (`p7zip 16.02+really26.01` in sid). The
`+dfsg` repack is the same upstream tarball with the non-free bits stripped;
the build inputs (`CPP/`, `C/`, `Asm/`) are intact, as the dry run confirms.

## Forecast

I agree with **6 of 6**: five UNCERTAIN and one WILL BUILD (clang-native).

**The brief asks why p7zip is UNCERTAIN rather than green, and the answer is
that UNCERTAIN is correct.** The adder did not hedge to avoid work; it
identified two specific, unresolved unknowns and named them:

1. **Zero `__ANDROID__` awareness in the tree.** `grep -rln '__ANDROID__'`
   over the sources returns nothing, so `CPP/myWindows` and the console/UI code
   are compiled with no Android branch at all. p7zip's own
   `makefile.android_arm` targets the ancient gnustl NDK r8c toolchain, not a
   modern clang wrapper — so there is no evidence upstream supports this
   combination, and no way to settle it without a build.
2. **x86 arch selection.** `makefile.linux_amd64:6` hardcodes
   `ALLFLAGS=-m64 …`. The recipe uses the stock `makefile.machine`, which has
   no `-m64`, so the arch comes from the compiler — which is the *right*
   design, but the adder correctly flags that if a builder finds
   `makefile.linux_amd64` being picked up, `-m64` would be a target fact that
   must not be in a recipe.

For mingw it names the `-DENV_UNIX` define (`makefile.machine:9`) and
`Common/MyWindows.cpp`'s `_WIN32` branches as the specific unknowns.

Given the confirmed `-lpthread` wall, I would tighten the four Android rows
from UNCERTAIN to **WILL NOT BUILD** — that failure is now proven, not
uncertain, and it precedes the questions the UNCERTAIN was hedging about. But
the hedge itself is honest and well-evidenced, so I am not rejecting on it;
I am recording that the forecast is, if anything, pessimistic about Android in
the wrong direction and could state a known blocker as known.

The `clang-native` WILL BUILD row is correct: `makefile.machine:14-15` uses
plain `gcc`/`g++`, which clang-native supplies, and `7za` compiles only
`CPP/7zip/Bundles/Alone` plus the C library with no host program built or run.

## Corrections to `stage1.md` (non-blocking)

- Risk 5 says the Android rows are UNCERTAIN "and the reason the Android rows
  are [UNCERTAIN]". With `-lpthread` proven absent, those rows should be
  WILL NOT BUILD. The blocker is *stronger* than the forecast claims.
- Risk 4 notes the binary ships **unstripped** because `$STRIP` is not
  applied. That is correct and worth keeping: it is a size cost, not a
  correctness one, and adding a `strip` step would be fine under the verb list
  but is not required.

## Artifacts — what actually installs

`$OUT/bin/7za` only. No library, no `.pc`, no headers. p7zip is a program.

## Carried to the build

```sh
# 1. artifacts (expected: exactly one program, no library, no .pc)
test -x "$OUT/bin/7za" || echo "MISSING bin/7za"
find "$OUT/lib" -name '*p7zip*' -o -name '*7za*' | wc -l    # expected 0
ls "$OUT/lib/pkgconfig"/*7zip* 2>/dev/null                  # expected: no such file

# 2. THE ANDROID BLOCKER, asserted rather than assumed. On every Android system
#    this must FAIL to link — that is the known wall, and confirming it is what
#    turns the UNCERTAIN into a documented WILL NOT BUILD.
if [ "$HOST_OS" = android ]; then
  printf 'int main(void){return 0;}\n' > /tmp/pt.c
  $CC /tmp/pt.c -lpthread -o /dev/null 2>&1 | head -1
  echo "expected: unable to find library -lpthread"
fi

# 3. the compiler override must reach the compiler (the subtle check).
#    Rebuild the dry-run line count against a distinctive value.
make CC="$CC" CXX="$CXX" 7za -n 2>&1 | grep -c -- "$CC"
# expected: > 0 — if 0, the override did not propagate and host gcc was used

# 4. no GTK GUI and no SFX got built (7za is the only target)
find "$WORK" -name '7z' -o -name '7zFM' -o -name '7zS' | wc -l   # expected 0
test -x "$WORK/bin/7za" || echo "MISSING: make 7za did not produce bin/7za"

# 5. ELF machine per family
$OBJDUMP -f "$OUT/bin/7za" | head -3
file "$OUT/bin/7za"

# 6. the binary is installed but never RUN by the build (no-emulation rule)
grep -ciE '\.\/7za|7za ' "$WORK/build.log"    # expected 0

# 7. confirm no host pkg-config or GTK leaked in: 7za is a standalone binary
llvm-nm -u "$OUT/bin/7za" | grep -cwE 'gtk_|XOpenDisplay'   # expected 0
```