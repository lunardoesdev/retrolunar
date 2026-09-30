REJECT

# libiconv — stage 2 review

## Required changes

1. **`packages/libiconv/generic.lua:9` — bare `make`, violating the
   serial-build rule** (AGENTS.md:226-229). Change to `make -j1`.

2. **`packages/libiconv/generic.lua:8` — the timestamp guard touches a
   `config.h.in` whose existence I could not confirm.** libiconv is not in the
   unpacked `nest/source/` tree, so unlike the other autotools packages in this
   shard I could not read its `configure.ac` or list its archive. The recipe
   uses the standard guard text, which is right for most projects, but for
   libiconv specifically the forecast should state which template it verified
   and where. If libiconv uses `config.h.in` at the top level (as gnulib-based
   projects do), the guard is correct as written and only the serialisation
   needs fixing.

## What the forecast gets right

- `--disable-shared --enable-static` matches the prefix convention (the order
  is reversed from some neighbours but is equivalent), and `--disable-nls`
  avoids pulling in the gettext/libintl machinery this tree does not have.
- Flags come from `$AUTOCONF_CONFIGURE_FLAGS`; nothing hardcoded, no search
  flag exported. No `sed`, no patch, no `/dev/null`, no `DESTDIR`.

## A note that matters more than the two fixes

libiconv is one of the packages where the **mingw story is a real question**.
Its whole purpose is character-set conversion, and on Windows a consumer is far
more likely to want the GNU libiconv than the platform's `libiconv`/`libintl`
pair — but this recipe builds it for every system uniformly, which is the right
default. The forecast should confirm the mingw row rather than leaving it
implicit, because a mangled `--prefix` or a missing `iconv.h` on mingw is
exactly the failure this package would produce.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libiconv.a` | `ls $PREFIX/lib/libiconv.*` — static |
| `$PREFIX/include/iconv.h` | `test -f $PREFIX/include/iconv.h` |
| `$PREFIX/lib/pkgconfig/libiconv.pc` | `pkg-config --modversion libiconv` |
| the .pc is rewritten to `$PREFIX` | `grep -c $OUT $PREFIX/lib/pkgconfig/libiconv.pc` → 0, proving the loader rewrite at `src/loader.lua:454-458` ran |
