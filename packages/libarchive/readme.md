# libarchive

libarchive is the C library behind `bsdtar` and `bsdcp`: a streaming reader
and writer for many container and compression formats behind one API. One
set of calls reads tar, zip, cpio, ar, ISO 9660, 7-Zip, xar, mtree and more,
with the compression handled by whichever backend is compiled in.

The model is a small state machine plus callbacks: you push bytes in and
pull entries out, and the format detection happens on the way.

```c
#include <archive.h>

struct archive *a = archive_read_new();
archive_read_support_format_tar(a);
archive_read_support_format_zip(a);
archive_read_support_filter_all(a);
archive_read_open_filename(a, path, 10240);

struct archive_entry *entry;
while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
    printf("%s %lld\n", archive_entry_pathname(entry),
           (long long) archive_entry_size(entry));
    /* archive_read_data into a buffer, or archive_read_data_skip */
}
archive_read_free(a);
```

Writing is `archive_write_new()` plus `archive_write_set_format_zip()` (or
`_pax_restricted`, the sane default for tar), then
`archive_write_open_filename`, `archive_write_header`, `archive_write_data`.

Compression backends are discovered at runtime through the registry that
`archive_read_support_filter_all` populates, so a program reading zip files
with deflate needs zlib linked in but does not configure anything itself.

## What retrolunar builds

A static `libarchive.a`, the `archive.h` and `archive_entry.h` headers, and
`libarchive.pc`. The backends are the ones this prefix already provides:
zlib (deflate/gzip), bzip2, xz/lzma, lz4 and zstd. `bsdtar`, `bsdcp` and
the test suite are off: host programs.

## Using it

```sh
pkg-config --cflags --libs libarchive
```

## Notes

- Two things needed handling for Android, both in the recipe:
  `archive.h` includes its private Android syscall wrappers from
  `contrib/android/include` whenever `__ANDROID__` is defined, and no
  upstream build system adds that directory unless it is an NDK build, so
  the recipe appends it to `CPPFLAGS`; and the configure options keep the
  XML2 and Expat readers out, since this prefix does not carry them.
- The build is Autotools with the system's `$AUTOCONF_CONFIGURE_FLAGS` and
  only package facts on top (static, `-fpic`, host programs off).
- libarchive is format-agnostic but not streaming-agnostic: a zip entry's
  compressed size may be unknown until you read it, so size checks belong
  after the header for some formats.
