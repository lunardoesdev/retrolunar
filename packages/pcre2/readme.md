# PCRE2

PCRE2 is the regular expression library that Perl's regex engine grew into:
the pattern syntax is Perl-like, and the implementation is a fork of the
original PCRE with its own JIT and its own 8/16/32 bit code paths.

Each width is a separate library with a separate header: `pcre2.h` with
`-lpcre2-8` for UTF-8 and byte strings, `pcre2_16.h` for UTF-16, `pcre2_32.h`
for UTF-32. The 8 bit library is the one almost everything wants.

```c
#include <pcre2.h>

int errcode;
PCRE2_SIZE erroffset;
pcre2_code *re = pcre2_compile((PCRE2_SPTR)"(\\d+)@(\\w+)", PCRE2_ZERO_TERMINATED,
                               0, &errcode, &erroffset, NULL);
pcre2_match_data *md = pcre2_match_data_create_from_pattern(re, NULL);
pcre2_match(re, subject, len, 0, 0, md, NULL);
```

Two performance notes worth knowing: `pcre2_jit_compile` turns the pattern
into machine code, which is a large win for hot patterns, and match data
should be reused across calls rather than recreated.

## What retrolunar builds

All three widths, statically, with JIT: `libpcre2-8.a`, `libpcre2-16.a`,
`libpcre2-32.a`, the three headers, the `.pc` files and the command line
tools `pcre2grep` and `pcre2test`. C++ is disabled, so `pcre2grep` is built
as a C program.

## Using it

```sh
pkg-config --cflags --libs libpcre2-8
```

## Notes

- Autotools build, so the recipe passes `$AUTOCONF_CONFIGURE_FLAGS` and adds
  only the width and linkage choices that are package facts.
- `--with-pic` is required: the archive has to be linkable into the shared
  objects that Android apps build.
- The Autotools timestamp guard is present because the release tarball
  carries mtimes that would otherwise make make re-run `aclocal`.
