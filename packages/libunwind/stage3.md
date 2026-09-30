# libunwind 1.8.3 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **FAILURE**

libunwind does not build on this system. The failure is a **platform wall**,
not a recipe defect: Bionic provides none of the three types libunwind's
coredump reader needs, and libunwind 1.8.3's `configure` enables coredump by
*architecture* without ever consulting the probes it just ran.

Nothing was published and no stamp was written, which is the loader behaving
correctly:

```
$ ls nest/aarch64-android24/lib/libunwind*
NOTHING published (correct — publish is on success only)
$ ls -a nest/aarch64-android24/.retrolunar-libunwind
no stamp written (correct)
```

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libunwind
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libunwind@aarch64-android24' > /tmp/build-libunwind.sh
sh -n /tmp/build-libunwind.sh          # exit 0 — syntax gate passed
sh /tmp/build-libunwind.sh             # exit 2
```

The recipe's own configure line, as emitted, verbatim from
`/tmp/build-libunwind.sh:229`:

```
./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-tests --disable-documentation
```

with `$AUTOCONF_CONFIGURE_FLAGS` set by the system to
`--host=$HOST_TRIPLET --build=$BUILD_TRIPLET`
(`/tmp/build-libunwind.sh:165`).

## Stale-artifact cleanup

libunwind had **no** stale artifacts and no stamp:

```
$ ls -la nest/aarch64-android24/lib/libunwind* 2>/dev/null
(no output)
$ ls -a nest/aarch64-android24/.retrolunar-libunwind
ls: cannot access '.../.retrolunar-libunwind': No such file or directory
```

The stamp delete and the name-scoped `rm -f` of `lib/libunwind*.{a,so,la}`,
`lib/pkgconfig/libunwind*.pc`, `include/libunwind*.h`, `include/unwind.h` and
`include/tdep` were run unconditionally anyway, as procedure. Nothing was
deleted, so no false pass is possible here in any case: **the build produced
no artifact at all**.

## The error, quoted in full

From `/tmp/build-libunwind.log`, after 98 successful `CC` lines — the library
itself and the DWARF reader built fine:

```
  CC       dwarf/Gexpr.lo
  CC       dwarf/Gfde.lo
  CC       dwarf/Gfind_proc_info-lsb.lo
  CC       dwarf/Gfind_unwind_table.lo
  CC       dwarf/Gget_proc_info_in_range.lo
  CC       dwarf/Gparser.lo
  CC       dwarf/Gpe.lo
  CCLD     libunwind-dwarf-generic.la
  CCLD     libunwind-aarch64.la
  CC       coredump/_UCD_access_mem.lo
In file included from coredump/_UCD_access_mem.c:25:
coredump/_UCD_internal.h:89:3: error: UCD_proc_status_t undefined
   89 | # error UCD_proc_status_t undefined
      |   ^
coredump/_UCD_internal.h:94:5: error: unknown type name 'UCD_proc_status_t'
   94 |     UCD_proc_status_t  prstatus;
      |       ^
coredump/_UCD_internal.h:109:5: error: unknown type name 'UCD_proc_status_t'
  109 |     UCD_proc_status_t      *prstatus;          /* points inside note_phdr */
      |       ^
3 errors generated.
make[2]: *** [Makefile:4824: coredump/_UCD_access_mem.lo] Error 1
make[2]: Leaving directory '/home/si/ond/git/retrolunar/nest/tmp/work-vLou9V/src'
make[1]: *** [Makefile:2929: all] Error 2
make[1]: Leaving directory '/home/si/ond/git/retrolunar/nest/tmp/work-vLou9V/src'
make: *** [Makefile:620: all-recursive] Error 1
```

- **File and line of the first error:** `coredump/_UCD_internal.h:89`, i.e.
  `nest/source/libunwind/src/coredump/_UCD_internal.h:89`.
- **Failing translation unit:** `src/coredump/_UCD_access_mem.c`.
- **Make rule:** `Makefile:4824` in the generated `src/Makefile`.

## The source of the error

`nest/source/libunwind/src/coredump/_UCD_internal.h:75-90`:

```c
#if defined(HAVE_STRUCT_ELF_PRSTATUS)
typedef struct elf_prstatus UCD_proc_status_t;
#elif defined(HAVE_STRUCT_PRSTATUS)
typedef struct prstatus UCD_proc_status_t;
#elif defined(HAVE_PROCFS_STATUS)
typedef struct { ... } UCD_proc_status_t;
#else
# error UCD_proc_status_t undefined
#endif
```

All three branches are unavailable. `configure` established that itself,
twice (the log shows the probe sequence once per configure pass):

```
checking for sys/procfs.h... yes
checking for struct elf_prstatus... no
checking for struct prstatus... no
checking for procfs_status... no
...
checking if libunwind-coredump should be built... yes
```

**configure turned `coredump` on while holding the evidence that it cannot
work.** The rule is `configure.ac:118-130`:

```m4
AC_MSG_CHECKING([if libunwind-coredump should be built])
AC_ARG_ENABLE([coredump], ... [], [enable_coredump="check"])
AS_IF([test "$enable_coredump" = "check"],
      [AS_CASE([$host_arch],
               [aarch64*|arm*|mips*|sh*|x86*|riscv*|loongarch64], [enable_coredump=yes],
               [enable_coredump=no])]
)
```

The autodetect branches on **architecture alone**. It never looks at
`HAVE_STRUCT_ELF_PRSTATUS`, `HAVE_STRUCT_PRSTATUS` or `HAVE_PROCFS_STATUS`,
so on any aarch64 libc that has a `<sys/procfs.h>` but no `prstatus` layout it
promises a library it cannot compile.

## Platform fact, established with the real NDK compiler

Checked by compiling probes with the same NDK clang the build uses —
`-c` only, no link, **no target binary was executed**:

```
$ /…/bin/aarch64-linux-android24-clang -c probe_prstatus.c
probe_prstatus.c:2:38: error: variable has incomplete type 'struct procfs_status'
probe_prstatus.c:2:24: note: forward declaration of 'struct procfs_status'
1 error generated.

$ /…/bin/aarch64-linux-android24-clang -c probe2.c          # <elf.h>
probe2.c:2:37: error: variable has incomplete type 'struct elf_prstatus'
probe2.c:2:24: note: forward declaration of 'struct elf_prstatus'
1 error generated.

$ /…/bin/aarch64-linux-android24-clang -c p4.c              # <linux/elfcore.h>
p4.c:1:10: fatal error: 'linux/elfcore.h' file not found
1 error generated.
```

And what Bionic's `<sys/procfs.h>` actually provides:

```
$ printf '#include <sys/procfs.h>\n' > p3.c
$ /…/bin/aarch64-linux-android24-clang -E p3.c | grep -oE 'struct (procfs|elf)_[a-z_]+' | sort -u
struct elf_siginfo
```

One struct, `struct elf_siginfo`. There is no status struct of any kind.
Bionic has no `<linux/elfcore.h>`, and its `<elf.h>` forward-declares
`struct elf_prstatus` without ever defining it.

## Classification

**Platform wall**, surfaced by an upstream default. Two distinct causes, both
real:

1. **Platform wall (the blocker).** Bionic defines none of
   `struct elf_prstatus`, `struct prstatus` or `struct procfs_status`. libnuma
   uses no such type; libunwind's coredump reader is written against the
   Linux ELF core-note / procfs status layout and Bionic does not ship it. No
   flag on any system file can conjure the type — it is a libc content
   question, not a build-flag question.
2. **Upstream defect (why it is fatal rather than skipped).**
   `configure.ac:118-130` decides coredump support from `$host_arch` and never
   consults the `AC_CHECK_STRUCT` results it has already computed. The correct
   upstream behaviour would be to key `enable_coredump` on
   `HAVE_STRUCT_ELF_PRSTATUS || HAVE_STRUCT_PRSTATUS || HAVE_PROCFS_STATUS`.
   libunwind ≥ 1.8.4 does not fix this either as far as this build knows.

**Not a recipe defect.** The recipe hardcodes no target facts, exports no
search flags, uses `$AUTOCONF_CONFIGURE_FLAGS` correctly, and its three
explicit switches (`--enable-static --disable-shared --with-pic`,
`--disable-tests`, `--disable-documentation`) all took. `stage2.md` expected
`libunwind-coredump.a` to be produced, so the recipe and the review agreed
with each other and both were wrong about Bionic.

**Not worked around.** Adding `--disable-coredump` would have made the build
go green by dropping a library the recipe and its review both expect to ship,
and it is a platform wall, not a recipe defect — precisely the case where
`AGENTS.md` says to record rather than work around. No recipe, system file or
recipe-local flag was changed to get past this.

## Forecast items that did and did not materialise

- **The `.S` assembly worry was correctly retracted.** Preflight §6.2 predicted
  `src/aarch64/setcontext.S` would fail to assemble and that
  `getcontext.S` would be fine. This build compiled 98 objects without a
  single assembler diagnostic; `libunwind-aarch64.la` and
  `libunwind-dwarf-generic.la` both linked. §6.2 was right, and the risk
  genuinely was elsewhere.
- **`AC_CHECK_LIB([z], [uncompress])` succeeded as §6.2/rank 2 predicted:**

  ```
  checking for uncompress in -lz... yes
  ```

  so `LIBZ=-lz` and `HAVE_ZLIB=1` are set. Inert for a static archive, and
  nothing here would have linked `-lz`. Recorded, not touched.
- **`libunwind-generic.a` symlink** (`stage2.md` item 2, the one thing that
  could have become a real artifact defect): **not reached** — the build died
  before `install-exec-hook` ran, so the question does not arise on this
  system until coredump is dealt with upstream or by an explicit
  `--disable-coredump`.

## Rerun

Not applicable. No stamp was written, so a rerun would rebuild rather than
print `skip`, which is the correct signal that no artifact was produced:

```
$ sh /tmp/build-libunwind.sh   # would rebuild; not run a second time
```

## What a future fix has to decide

Recorded, not chosen, because it is not the builder's call:

- **On Android, `--disable-coredump` in `packages/libunwind/android.lua`**
  (not in `generic.lua` — this is an Android-family fact, and `AGENTS.md`
  requires a family file rather than a per-target copy, so one
  `packages/libunwind/android.lua` covers all 56 Android systems). Cost:
  `libunwind-coredump.a` and `libunwind-coredump.pc` are not shipped, which is
  a real loss for a debugger, though coredump-aware unwinding is largely a
  host-side feature.
- **Or upstream first**, if the project accepts a `configure.ac` change making
  the coredump autodetect capability-based.

Either way the flag must not go into `generic.lua`, because the same
architecture-keyed default is *correct* on glibc, where the probes do pass.
