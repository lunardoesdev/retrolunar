# opusfile 0.12 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS**, first attempt — but the review's proof command was wrong

The build is clean. The `stage2.md` check it names for the archive's symbols
returns **0 against this correct build**, because it greps for a symbol
prefix opusfile 0.12 does not use. That check has been corrected in
`stage2.md`; the details are below because it is the exact failure class this
round was warned about.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-opusfile
rm -rf nest/source/opusfile nest/source/.retrolunar-opusfile
rm -f $S/lib/libopusfile.a $S/lib/libopusurl.a $S/lib/libopusfile.so \
      $S/lib/libopusurl.so $S/lib/libopusfile.la $S/lib/libopusurl.la \
      $S/lib/pkgconfig/opusfile.pc $S/lib/pkgconfig/opusurl.pc \
      $S/include/opus/opusfile.h $S/include/opus/opusurl.h
rm -rf $S/share/doc/opusfile
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'opusfile@aarch64-android24' > /tmp/build-opusfile.sh
sh -n /tmp/build-opusfile.sh          # exit 0 — syntax gate passed
sh /tmp/build-opusfile.sh             # exit 0
```

## Stale-artifact cleanup

Nothing was stale — no stamp, no archives, no `.pc`, no `include/opus/opusfile.h`,
no `share/doc/opusfile`:

```
$ ls nest/aarch64-android24/lib/libopusfile.a \
         nest/aarch64-android24/lib/libopusurl.a \
         nest/aarch64-android24/lib/pkgconfig/opusfile.pc \
         nest/aarch64-android24/lib/pkgconfig/opusurl.pc \
         nest/aarch64-android24/include/opus/opusfile.h
none
$ ls -d nest/aarch64-android24/share/doc/opusfile
no doc dir
```

Cleanup was by exact filename, per the lesson recorded in
`packages/protobuf/stage3.md`: `rm -f lib/libopusfile*` would have been fine
here, but the habit of exact names is what stops a `libprotobuf*`-style
collision happening again. All artifacts below are mtime `Oct 1 14:06`.

## Real work in the log

Both unconditional libraries were compiled and archived, then the header,
docs and both `.pc` files installed:

```
libtool: install: .../bin/llvm-ranlib .../out-R25hQr/lib/libopusurl.a
 /usr/bin/install -c -m 644 COPYING AUTHORS README.md '.../out-R25hQr/share/doc/opusfile'
 /usr/bin/install -c -m 644 include/opusfile.h '.../out-R25hQr/include/opus'
 /usr/bin/install -c -m 644 opusfile.pc opusurl.pc '.../out-R25hQr/lib/pkgconfig'
```

## The defective check in stage2.md — found and corrected

`stage2.md` said:

```sh
llvm-nm --defined-only "$PREFIX/lib/libopusfile.a" | grep -c opusfile_open
```
Expected: "correct object format, **non-zero count**".

Real output on a correct build:

```
$ llvm-nm --defined-only nest/aarch64-android24/lib/libopusfile.a | grep -c opusfile_open
0
```

**opusfile 0.12 has no `opusfile_` symbol prefix at all.** The library is
`libopusfile.a`, but its public API is spelled `op_*`. Verified against the
tree rather than assumed:

```
$ llvm-nm --defined-only .../lib/libopusfile.a | grep -cE ' T opusfile_'
0
$ llvm-nm --defined-only .../lib/libopusfile.a | grep -E ' T ' | grep -iE 'open|close'
000000000000055c T op_open_callbacks
0000000000001114 T op_open_file
00000000000011bc T op_open_memory
000000000000135c T op_test_open
000000000000003c T op_fdopen
0000000000000000 T op_fopen
0000000000000078 T op_freopen
```

There is no `opusfile_open` in the header either — `grep -oE '\bopusfile_[a-zA-Z_0-9]+'`
on `include/opusfile.h` returns **nothing**. A grep for `opusfile` in the nm
output matches only the object-file header line `opusfile.o:`, which is
precisely why this passes unnoticed at a glance.

Left uncorrected, the next builder would run this on a good build, get 0
where the document promises non-zero, and report a phantom defect — the same
class as the `libnl-*-3.a` glob and the shared-directory counts.

**Corrected in `stage2.md`** to `grep -c ' T op_open_file'`, with a note
recording what was wrong and why. Re-run after the fix:

```
$ llvm-nm --defined-only nest/aarch64-android24/lib/libopusfile.a | grep -c ' T op_open_file'
1
```

The ` T ` matters as much as the name: without it, `llvm-nm` also emits the
`opusfile.o:` filename header line and the count would be 2 for the wrong
reason.

## Artifact verification (real output)

| expected artifact | command | real output |
| --- | --- | --- |
| `lib/libopusfile.a` | `llvm-objdump -f` | `libopusfile.a(info.o):	file format elf64-littleaarch64` |
| `lib/libopusurl.a` | `ls -la` | `-rw-r--r-- 1 si si   8114 Oct  1 14:06 .../lib/libopusurl.a` |
| `lib/libopusfile.a` size | `ls -la` | `-rw-r--r-- 1 si si  52956 Oct  1 14:06 .../lib/libopusfile.a` |
| **both** archives present, not just one | `ls` | both — as `stage2.md` warned, `Makefile.am:10` makes both unconditional |
| real symbols | corrected check | `1` |
| `include/opus/opusfile.h` | `test -f` | present |
| `lib/pkgconfig/opusfile.pc` | `pkg-config --modversion opusfile` | `0.12` |
| `lib/pkgconfig/opusurl.pc` | `pkg-config --modversion opusurl` | `0.12` |
| `.pc` Cflags name the subdir | `grep -m1 '^Cflags:'` | `Cflags: -I${includedir}/opus` |
| deps resolved via pkg-config | `grep -m1 '^Requires'` | `Requires.private: ogg >= 1.3 opus >= 1.0.1` |
| `share/doc/opusfile/` | `ls` | `AUTHORS`, `COPYING`, `README.md` |
| **no shared objects** | `ls lib/libopusfile.so* lib/libopusurl.so*` | `none (correct)` |

The `Requires.private` line matters: `configure.ac:125` is an unconditional
`PKG_CHECK_MODULES`, so if it had not seen the prefix's `.pc` files, configure
would have errored outright. It read both dependencies.

**`--disable-http` took.** `stage2.md` names this as the check that matters:

```
$ llvm-nm -u .../libopusfile.a .../libopusurl.a | grep -cE 'SSL_|curl_|EVP_'
0
$ grep -c 'openssl' .../lib/pkgconfig/opusurl.pc
0
```

Zero for both, as predicted — no OpenSSL references in either archive and no
crypto module in `opusurl.pc`'s `Requires`.

**`include/opusurl.h` is absent**, which `stage2.md` predicted from
`Makefile.am`: the only `HEADERS` assignment is line 8, `opusfile.h`. The
installed `include/opus/` holds `opusfile.h` plus the five opus headers
(`opus.h`, `opus_defines.h`, `opus_multistream.h`, `opus_projection.h`,
`opus_types.h`) from the `opus` package. No phantom defect; the header is
simply never installed.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-opusfile.sh
skip libogg@source (fresh)
skip libogg@aarch64-android24 (fresh)
skip opus@source (fresh)
skip opus@aarch64-android24 (fresh)
skip opusfile@source (fresh)
skip opusfile@aarch64-android24 (fresh)
```

All six blocks skip, both dependencies included.

## System-level findings

None. No recipe or system file was edited during this build; the only file
changed is `stage2.md`, and only its defective verification command.

## Recipe changes

**None.** `packages/opusfile/generic.lua` and `source.lua` are committed
unmodified. The `--disable-http` reasoning in the recipe's comment held up
exactly as written, including the note that the real switch is `--disable-http`
rather than `--without-libcurl`.
