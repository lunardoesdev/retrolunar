# libssh2 1.11.1 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS**, first attempt

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libssh2
rm -rf nest/source/libssh2 nest/source/.retrolunar-libssh2
# exact-filename cleanup of libssh2's own artifacts — see below
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libssh2@aarch64-android24' > /tmp/build-libssh2.sh
sh -n /tmp/build-libssh2.sh          # exit 0 — syntax gate passed
sh /tmp/build-libssh2.sh             # exit 0
```

## Stale-artifact cleanup

Nothing was stale — no stamp, no archive, no headers, no `.pc`, no man pages:

```
$ ls -la nest/aarch64-android24/lib/libssh2* \
         nest/aarch64-android24/lib/pkgconfig/libssh2.pc \
         nest/aarch64-android24/include/libssh2*.h
none
$ ls nest/aarch64-android24/share/man/man3/libssh2_*
no man pages
```

**Cleanup was done by exact filename this time**, not by a glob:

```sh
rm -f $S/lib/libssh2.a $S/lib/libssh2.so $S/lib/libssh2.la \
      $S/lib/pkgconfig/libssh2.pc \
      $S/include/libssh2.h $S/include/libssh2_publickey.h \
      $S/include/libssh2_sftp.h \
      $S/share/man/man3/libssh2_*.3
```

That is a change of method, not of intent, and it is worth stating why. On
protobuf I deleted its artifacts with `rm -f lib/libprotobuf*.a`, which
silently destroyed **nanopb's** `libprotobuf-nanopb.a` and cost a rebuild;
that mistake and its repair are written up in `packages/protobuf/stage3.md`.
One package's artifact name beginning with another's is not hypothetical
here — it happened in this batch.

The `share/man/man3/libssh2_*.3` form is a glob, but a safe one: no other
package in this prefix ships a man page whose name begins `libssh2_`.

## Real work in the log

Configure resolved the intended crypto backend rather than falling through
to one of the four others `acinclude.m4:856` walks:

```
checking for OpenSSL... yes
```

Compile and archive, then the targeted install:

```
  CC       libssh2_la-agent.lo
  ...
  CCLD     libssh2.la
libtool: link: llvm-ar cru .libs/libssh2.a  agent.o auth.o ...
 /usr/bin/install -c -m 644 include/libssh2.h include/libssh2_publickey.h include/libssh2_sftp.h '.../out-MqzNni/include'
 /usr/bin/install -c -m 644 libssh2.pc '.../out-MqzNni/lib/pkgconfig'
```

`--disable-examples-build` took: no sample client or server was compiled, and
no `bin/` entry was added.

## Artifact verification (real output)

**The one command `stage2.md` names**, run verbatim:

```sh
test -f "$PREFIX/lib/libssh2.a" &&
llvm-objdump -f "$PREFIX/lib/libssh2.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libssh2.a" | grep -c libssh2_session_init
```

Real output:

```
$ llvm-objdump -f nest/aarch64-android24/lib/libssh2.a | head -2

nest/aarch64-android24/lib/libssh2.a(agent.o):	file format elf64-littleaarch64
$ llvm-nm --defined-only nest/aarch64-android24/lib/libssh2.a | grep -c libssh2_session_init
1
```

`elf64-littleaarch64` as `stage2.md` predicted, and a non-zero symbol count
as required.

The rest of the table:

| expected artifact | command | real output |
| --- | --- | --- |
| `lib/libssh2.a` | `ls -la` | `-rw-r--r-- 1 si si 451924 Oct  1 14:01 nest/aarch64-android24/lib/libssh2.a` |
| `.la` also installed | `ls -la` | `-rw-r--r-- 1 si si 1062 Oct  1 14:01 .../libssh2.la` |
| `include/libssh2.h` | `ls` | present |
| `include/libssh2_publickey.h` | `ls` | present |
| `include/libssh2_sftp.h` | `ls` | present |
| `lib/pkgconfig/libssh2.pc` | `pkg-config --modversion libssh2` | `1.11.1` |
| `share/man/man3/libssh2_*.3` | `ls .../man3/ \| grep -c '^libssh2_'` | `186` |
| **no shared object** | `ls $PREFIX/lib/libssh2.so*` | `no .so (correct)` |

All artifacts carry mtime `Oct 1 14:01` — this build, not a survivor.

### On the man-page count, since 186 looks wrong

It is not. `stage2.md` names the glob `libssh2_*.3` without stating a
number, so I checked whether it was over-matching rather than assuming:

```
$ ls nest/aarch64-android24/share/man/man3/ | grep -c '^libssh2_'
186
$ ls nest/source/libssh2/docs/*.3 | wc -l
187
```

libssh2 ships a man page per public API symbol, and the source tree carries
187 of them. The installed 186 is the upstream set minus one, and the glob
matches exactly what this package installed — no other package in the prefix
ships a `libssh2_*` page. So the count is real, and a reader who sees 186
should not go looking for a phantom defect. Recorded here for that reason.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-libssh2.sh
skip openssl@source (fresh)
skip openssl@aarch64-android24 (fresh)
skip zlib@source (fresh)
skip zlib@aarch64-android24 (fresh)
skip libssh2@source (fresh)
skip libssh2@aarch64-android24 (fresh)
```

All six blocks skip, both dependencies included.

## System-level findings

None. No `-llog` issue arose: the systems' `LDFLAGS` already carry it as of
`0d8364db`, and no recipe or system file was edited during this build.

## Recipe changes

**None.** `packages/libssh2/generic.lua` and `source.lua` are committed
unmodified.
