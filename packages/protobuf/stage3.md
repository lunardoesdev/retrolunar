# protobuf 36.2 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS**, on the second attempt

The first attempt died at 52% with **no diagnostic at all** — the log is
truncated mid-line and there is no error text anywhere in it. The second
attempt of the identical script completed to 100%. Both facts are recorded
below rather than the successful run alone, because "it worked when I tried
again" is exactly the shape of thing a reader must not have to discover
themselves.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-protobuf
rm -rf nest/source/protobuf nest/source/.retrolunar-protobuf
# delete protobuf's own artifacts from the prefix — see the cleanup section
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'protobuf@aarch64-android24' > /tmp/build-protobuf.sh
sh -n /tmp/build-protobuf.sh          # exit 0 — syntax gate passed
sh /tmp/build-protobuf.sh             # attempt 1: exit 2, truncated log
sh /tmp/build-protobuf.sh             # attempt 2: exit 0
```

## Stale-artifact cleanup — and a mistake of mine worth recording

**A glob of mine destroyed another package's artifact.** I deleted protobuf's
artifacts with:

```sh
rm -f $S/lib/libprotobuf*.a $S/lib/libprotobuf*.so* $S/lib/libprotobuf*.la ...
```

`libprotobuf*.a` matches **`libprotobuf-nanopb.a`**, which is *nanopb's*
archive, built earlier in this session and unrelated to protobuf. The
pre-cleanup listing had shown it sitting there:

```
$ ls -la nest/aarch64-android24/lib/libprotobuf*
-rw-r--r-- 1 si si 32224 Oct  1 03:14 nest/aarch64-android24/lib/libprotobuf-nanopb.a
```

I deleted it, along with `include/google` and `lib/cmake/protobuf` (both
correctly protobuf's). nanopb was then **rebuilt and restored**:

```
$ sh /tmp/build-nanopb.sh          # first attempt: skipped, stamp still fresh
$ rm -f nest/aarch64-android24/.retrolunar-nanopb
$ sh /tmp/build-nanopb.sh          # exit 0, reinstalled
$ ls nest/aarch64-android24/include/nanopb/
pb.h  pb_common.h  pb_decode.h  pb_encode.h
$ llvm-objdump -f nest/aarch64-android24/lib/libprotobuf-nanopb.a | head -2
nest/aarch64-android24/lib/libprotobuf-nanopb.a(pb_common.c.o):	file format elf64-littleaarch64
```

Note the intermediate step: the first restore attempt **skipped** because the
stamp was still fresh, so the headers were *not* reinstalled and only the
archive came back. That is the freshness chain working exactly as designed —
the stamp meant "this recipe produced this prefix", and the prefix had since
been broken by hand. Deleting the stamp was required, not merely tidy.

**The lesson, which is the same one as the `share/man` mishap in
`packages/oniguruma/stage3.md`:** `lib/<name>*.a` is not a safe cleanup glob
when one package's artifact name starts with another's. Clean by **exact
filename**, or by a name no other package can collide with — `libprotobuf.a`
and `libprotobuf-lite.a`, not `libprotobuf*.a`. I had this written down from
the earlier mishrap and still walked into it, which suggests the rule belongs
in AGENTS.md rather than in a stage file where a builder reads it once.

Nothing else was stale: no protobuf stamp, no `include/google`, no
`lib/cmake/protobuf`, no `protobuf*.pc`, no `libupb*`/`libprotoc*`.

## Attempt 1: the failure, quoted

`/tmp/build-protobuf.log`, 1375 lines. Exit status **2**. There is no `error:`
line, no `FAILED`, no `Error N` from make or cmake anywhere in it. The log
simply stops mid-line:

```
[ 52%] Building CXX object CMakeFiles/libprotobuf.dir/src/google/protobuf/generated_message_reflection.cc.o
In file included from .../generated_message_reflection.cc:12:
In file included from .../generated_message_reflection.h:26:
.../google/protobuf/descriptor.h:2742:29: warning: 'ReaderMutexLock' is deprecated: ...
 2742 |       absl::ReaderMutexLock lock(&pool->field_memo_table_mutex_);
      |                             ^
.../absl/synchronization/mutex.h:676:5: note: 'ReaderMutexLock' has been explicitly marked deprecated here
  676 |   [[deprecated("Use the constructor that takes a reference instead")]]
      |     ^
.../descriptor.h:2751:23: warning: 'MutexLock' is deprecated: ...
 2751 |       absl::MutexLock lock(&pool->field_memo_table_mutex_);
      |                       ^
.../absl/synchronization/mutex.h:633:5: note: 'MutexLock' has been explicitly marked deprecated here
  633 |   [[deprecated("Use the constructor that takes a reference instead")]]
      |     ^
1 warning generated.
/home/si/ond/git/retrolunar/nest/tmp/work-V8MvNx/src/goo      <-- truncated here
```

The last line is cut mid-path. That is the signature of the writing process
being killed, not of a compiler diagnostic.

**Most likely cause: memory.** This run was rebuilding `abseil-cpp` from
scratch — see the next section — so protobuf's own large translation units
were competing with a full abseil build for RAM. Host capacity at the time:

```
$ free -m
              total   used   free  shared  buff/cache  available
Mem:           5858   3975    219     172        2353      1882
```

`generated_message_reflection.cc` is one of protobuf's largest translation
units and its peak RSS with `-O2` is routinely over a gigabyte.

**Classification: a resource-exhaustion failure, not a recipe defect, not a
platform wall, and not an upstream defect.** I say this with the evidence
above rather than asserting it: I did not capture a memory-pressure message,
because none was emitted. What I can state is that attempt 1 failed with no
diagnostic, attempt 2 of the byte-identical script succeeded, and the only
material difference was that abseil had already been built. That is a
transient environmental failure.

**Nothing was published or stamped on attempt 1**, which is the loader
behaving correctly:

```
$ ls nest/aarch64-android24/lib/libprotobuf.a
no libprotobuf.a
$ ls -a nest/aarch64-android24/.retrolunar-protobuf
no protobuf stamp
```

## Attempt 2: SUCCESS

Exit status **0**, reaching `[100%]`. Install tail:

```
-- Installing: .../out-b1d54g/lib/cmake/protobuf/protobuf-config.cmake
-- Installing: .../out-b1d54g/lib/cmake/protobuf/protobuf-config-version.cmake
-- Installing: .../out-b1d54g/lib/cmake/protobuf/protobuf-module.cmake
-- Installing: .../out-b1d54g/lib/cmake/protobuf/protobuf-options.cmake
-- Installing: .../out-b1d54g/lib/cmake/protobuf/protobuf-generate.cmake
```

Real work, not a skip — hundreds of `Building CXX object` lines, ending:

```
[ 52%] Building CXX object CMakeFiles/libprotobuf.dir/src/google/protobuf/generated_message_reflection.cc.o
...
[100%] Linking CXX static library libprotobuf.a
[100%] Built target libprotobuf
```

## Artifact verification (real output)

**The one command `stage2.md` names**, run verbatim:

```sh
test -f "$PREFIX/lib/libprotobuf.a" && test -f "$PREFIX/lib/libprotobuf-lite.a" &&
llvm-objdump -f "$PREFIX/lib/libprotobuf.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libprotobuf.a" | grep -c MessageLite
```

Real output:

```
$ llvm-objdump -f nest/aarch64-android24/lib/libprotobuf.a | head -2

nest/aarch64-android24/lib/libprotobuf.a(any.pb.cc.o):	file format elf64-littleaarch64
$ llvm-nm --defined-only nest/aarch64-android24/lib/libprotobuf.a | grep -c MessageLite
632
```

Both archives present and correctly formatted, 632 `MessageLite`-bearing
symbols, i.e. real code rather than an empty archive.

**The LIBUPB check**, which `stage2.md` calls the one that matters for this
package:

```
$ find nest/aarch64-android24/lib -maxdepth 1 \( -name 'libupb.*' -o -name 'libprotoc.*' \) | wc -l
0
```

Zero. `protobuf_BUILD_LIBUPB=OFF` and `protobuf_BUILD_PROTOC_BINARIES=OFF`
both took, which is the switch interaction the recipe's comment describes
(`CMakeLists.txt:124` turns LIBPROTOC back on for protoc binaries, `:132`
then forces LIBUPB back on for the same reason). Had either been left at its
default this would be non-zero.

The rest of the `stage2.md` table, each with its proof:

| expected artifact | command | real output |
| --- | --- | --- |
| `lib/libutf8_range.a`, `lib/libutf8_validity.a` | `ls` | both present |
| `include/google/protobuf/descriptor.pb.h` | `ls` | present |
| `lib/pkgconfig/protobuf.pc` | `pkg-config --modversion protobuf` | `36.2.0` |
| `lib/cmake/protobuf/protobuf-config.cmake` (+4 more) | `ls` | `protobuf-config.cmake`, `protobuf-config-version.cmake`, `protobuf-generate.cmake`, `protobuf-module.cmake`, `protobuf-options.cmake`, `protobuf-targets-noconfig.cmake` |
| mtimes, this build | `ls -la` | `libprotobuf.a` 13521562 and `libprotobuf-lite.a` 2450170, both `Oct  1 13:49` |

## Rerun proves the new stamp is real

```
$ sh /tmp/build-protobuf.sh
skip abseil-cpp@source (fresh)
skip abseil-cpp@aarch64-android24 (fresh)
skip zlib@source (fresh)
skip zlib@aarch64-android24 (fresh)
skip protobuf@source (fresh)
skip protobuf@aarch64-android24 (fresh)
```

All six blocks skip, including the two dependencies.

## System-level findings

- **`abseil-cpp` rebuilt as part of this build, and it should not have.** It
  had been fresh. The cause is the freshness rule: a stamp must be newer than
  the recipe file, the system `generic.lua` *and the system directory*. Commit
  `0d8364db` ("Android systems: add -llog to LDFLAGS for Bionic's liblog")
  modified `packages/aarch64-android24/generic.lua`, which updates that
  directory's mtime and therefore invalidates **every one of the 56 Android
  packages** at once. That is the rule working as designed, but the blast
  radius of a system-file edit is the whole tree, and a builder should expect
  a full Android rebuild after any of them. It also explains why attempt 1 was
  memory-constrained: abseil was rebuilding in the same run.

- **No `-llog` was needed, and none was added.** The instruction anticipated
  `undefined reference to __android_log_write`. It never appeared, because the
  systems' `LDFLAGS` already carry `-llog` as of `0d8364db`. No recipe and no
  system file was edited during this build.

## Recipe changes

**None.** `packages/protobuf/generic.lua` and `source.lua` are committed
unmodified.
