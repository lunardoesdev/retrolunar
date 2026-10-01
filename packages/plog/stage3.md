# plog 1.1.11 — stage 3 build record

System: **`aarch64-android24`**, NDK from
`/home/si/.local/share/mise/installs/android-sdk/23.0`.

## Outcome: **SUCCESS**

Nothing is compiled — the `plog` target is an `INTERFACE` library, so the
build is cmake configuring and then copying headers. No recipe fix was
needed, and none was made.

**One `stage2.md` check could not match its own target**, and one of them
proves the wrong thing. Both are itemised below with the corrected check and
its real output. Neither is a build defect.

## Command sequence (exactly as run)

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-plog
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'plog@aarch64-android24' > /home/si/ond/git/rl-wave1/build-plog.sh
sh -n /home/si/ond/git/rl-wave1/build-plog.sh    # exit 0
sh /home/si/ond/git/rl-wave1/build-plog.sh       # exit 0, real 0m3.1s
```

Scratch files live under `/home/si/ond/git/rl-wave1/`, not `/tmp`: `/tmp` is
a tmpfs that hit its quota (`echo: i/o error: Disk quota exceeded (os error
122)`) partway through this wave, and it holds other agents' files, which are
not mine to delete. This changes nothing about the build; only where the
generated script and logs are written.

## Stale-artifact cleanup — nothing to delete

```
$ [ -f nest/aarch64-android24/.retrolunar-plog ] ; [ -d nest/source/plog ]
stamp=no  src=no
$ ls nest/aarch64-android24/include | grep -i plog
$ ls nest/aarch64-android24/lib/cmake | grep -i plog
$ ls nest/aarch64-android24/lib/pkgconfig | grep -i plog
(all three greps printed nothing)
```

**Deleted:** only `nest/aarch64-android24/.retrolunar-plog`, which did not
exist. `nest/source/plog` did not exist either, so the source block fetched
fresh — the log shows the real 203.3 kB transfer:

```
100 203.3k   203.3k    0     0  101.3k      0           00:02  203.3k
```

No stale file of any name could have satisfied a check.

## Real work in the log

```
$ grep -c 'Installing:' /home/si/ond/git/rl-wave1/log-plog.txt
37
```

```
-- The CXX compiler identification is Clang 19.0.1
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: .../bin/aarch64-linux-android24-clang++ - skipped
-- Configuring done (0.5s)
-- Generating done (0.0s)
-- Build files have been written to: .../nest/tmp/work-ZMQRfb/build
-- Install configuration: ""
-- Installing: .../out-B16LCN/lib/cmake/plog/plogConfig.cmake
-- Installing: .../out-B16LCN/include/plog
-- Installing: .../out-B16LCN/include/plog/Appenders
-- Installing: .../out-B16LCN/include/plog/Appenders/AndroidAppender.h
...
-- Installing: .../out-B16LCN/include/plog/Log.h
-- Installing: .../out-B16LCN/include/plog/Logger.h
-- Installing: .../out-B16LCN/share/doc/plog/README.md
-- Installing: .../out-B16LCN/share/doc/plog/LICENSE
-- Installing: .../out-B16LCN/lib/cmake/plog/plogConfigVersion.cmake
```

`-- Check for working CXX compiler … - skipped` is
`CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` from `$CMAKE_FLAGS` doing its
job: no target binary is linked and none is run. There are **zero** compile or
link lines:

```
$ grep -cE 'Building CXX|Linking' /home/si/ond/git/rl-wave1/log-plog.txt
0
```

## Artifact table — real output

`P` = `nest/aarch64-android24`.

| check (`stage2.md` "Carried to the build") | command | real output | verdict |
|---|---|---|---|
| `include/plog/Log.h` exists | `ls $P/include/plog/Log.h` | `11281 Oct  1 14:49 nest/aarch64-android24/include/plog/Log.h` | PASS |
| `Init.h` alongside | `ls $P/include/plog/Init.h` | `522 Oct  1 14:49 nest/aarch64-android24/include/plog/Init.h` | PASS |
| cmake package config installed | `ls $P/lib/cmake/plog` | `plogConfig.cmake` `plogConfigVersion.cmake` | PASS |
| version is 1.1.11 | `grep 'PACKAGE_VERSION "' $P/lib/cmake/plog/plogConfigVersion.cmake` | `10:set(PACKAGE_VERSION "1.1.11")` | PASS |
| **nothing was compiled** | `find $P/include/plog $P/lib/cmake/plog $P/share/doc/plog \( -name '*.a' -o -name '*.so' \)` | *(empty)* | PASS |
| **no `.pc` ships** (expected, recorded not assumed) | `find $P/include/plog $P/lib/cmake/plog $P/share/doc/plog -name '*.pc'` | *(empty)* | PASS |
| no plog `.pc` leaked into the shared dir | `ls $P/lib/pkgconfig \| grep -i plog` | *(empty)* | PASS |
| whole header tree installed, byte-identical to upstream | `diff -r nest/source/plog/include/plog $P/include/plog` | *(no output)* — `diff exit=0` | PASS |

`stage2.md` scoped the `.a`/`.so` and `.pc` checks to `$OUT`, the stage dir.
`$OUT` is `rm -rf`'d by the script's own `trap` on exit, so it cannot be
inspected afterwards; the table runs the same `find` over the three paths
plog owns **in the prefix** (`include/plog`, `lib/cmake/plog`, `share/doc/plog`).
Still scoped to this package — it cannot pass vacuously, and it cannot be
satisfied by another package's output.

### Full installed header listing

```
$ ls $P/include/plog
Appenders  Converters  Formatters  Helpers  Init.h  Initializers  Log.h
Logger.h  Record.h  Severity.h  Util.h  WinApi.h
```

### Two `stage2.md` checks that could not match their own target — the CHECK is wrong

**1. "`Appender.h` / `Formatters.h` alongside `Log.h`" (`stage1.md:58`, carried
into `stage2.md`) — these files do not exist and never have.**

```
$ ls $P/include/plog/Appender.h $P/include/plog/Formatters.h
ls: cannot access 'nest/aarch64-android24/include/plog/Appender.h': No such file or directory
ls: cannot access 'nest/aarch64-android24/include/plog/Formatters.h': No such file or directory
```

They are **directories**, not headers, in the upstream tree:

```
$ ls nest/source/plog/include/plog/Appenders nest/source/plog/include/plog/Formatters
nest/source/plog/include/plog/Appenders:
AndroidAppender.h  ArduinoAppender.h  ColorConsoleAppender.h  ConsoleAppender.h
DebugOutputAppender.h  DynamicAppender.h  EventLogAppender.h  IAppender.h  RollingFileAppender.h

nest/source/plog/include/plog/Formatters:
CsvFormatter.h  FuncMessageFormatter.h  MessageOnlyFormatter.h  TxtFormatter.h
```

The names were dropped the wrong side of the word boundary. Corrected, both
landed in full:

```
$ ls $P/include/plog/Appenders $P/include/plog/Formatters
nest/aarch64-android24/include/plog/Appenders:
AndroidAppender.h  ArduinoAppender.h  ColorConsoleAppender.h  ConsoleAppender.h
DebugOutputAppender.h  DynamicAppender.h  EventLogAppender.h  IAppender.h  RollingFileAppender.h

nest/aarch64-android24/include/plog/Formatters:
CsvFormatter.h  FuncMessageFormatter.h  MessageOnlyFormatter.h  TxtFormatter.h
```

**2. `grep -c log lib/cmake/plog/plogConfig.cmake` should be 0 — it cannot be 0,
and it is not the property under test.**

```
$ grep -c log $P/lib/cmake/plog/plogConfig.cmake
5
```

Every one of those 5 lines is a match inside the *word* `plog`:

```
22:foreach(_cmake_expected_target IN ITEMS plog::plog)
58:# Create imported target plog::plog
59:add_library(plog::plog INTERFACE IMPORTED)
61:set_target_properties(plog::plog PROPERTIES
66:file(GLOB _cmake_config_files "${CMAKE_CURRENT_LIST_DIR}/plogConfig-*.cmake")
```

`grep log` cannot tell `plog` from a bare `-llog` linkage. So the check does
not measure what `stage1.md` risk 1 asked it to measure. What risk 1 actually
asked for — "confirm on the first build that `lib/cmake/plog/plogConfig.cmake`
has no `log` in its interface" — is a check on the exported
`INTERFACE_LINK_LIBRARIES` property, which is what `CMakeLists.txt:32-34`
would have set:

```
$ grep -n INTERFACE_LINK_LIBRARIES $P/lib/cmake/plog/plogConfig.cmake
(no output — exit 1)
```

**The property is absent, so `if(ANDROID) target_link_libraries(plog INTERFACE
log)` did not fire, which is exactly what `stage1.md` predicted from our
`CMAKE_SYSTEM_NAME Linux` toolchain files.** The one property the target does
carry is the include path:

```
$ grep -n INTERFACE_INCLUDE_DIRECTORIES $P/lib/cmake/plog/plogConfig.cmake
62:  INTERFACE_INCLUDE_DIRECTORIES "${_IMPORT_PREFIX}/include"
```

Expected value for the corrected check: `grep -c INTERFACE_LINK_LIBRARIES`
returns **0**. Risk 1 is discharged.

## mtimes, not byte counts

There is no stale predecessor to compare against, so the evidence is that
every artifact carries this run's timestamp — the build finished at `14:49:16`
and the stamp was written in the same second:

```
$ ls -l --time-style=full-iso $P/.retrolunar-plog $P/include/plog/Log.h $P/lib/cmake/plog/plogConfig.cmake
-rw-r--r-- 1 si si    0 2026-10-01 14:49:16.942708076 +1000 nest/aarch64-android24/.retrolunar-plog
-rw-r--r-- 1 si si 11281 Oct  1 14:49 nest/aarch64-android24/include/plog/Log.h
```

## Rerun proof

```
$ sh /home/si/ond/git/rl-wave1/build-plog.sh
skip plog@source (fresh)
skip plog@aarch64-android24 (fresh)
```

## Cross-system comparison

`stage2.md` asked for `diff -r` between **two systems**' `include/plog/`. Not
run: this wave builds one system only. The `diff -r` against the unpacked
upstream tree above (`diff exit=0`) is the stronger form of the same claim —
the installed headers are byte-identical to the tarball, and there is no
compiled artifact that could differ by architecture.

## Recipe changes made during this build

**None.** No fix was needed and none was made.