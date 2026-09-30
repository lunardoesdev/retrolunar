# minizip-ng

minizip-ng is a modern ZIP implementation built on zlib-ng: it reads and
writes ZIP archives with the deflate, bzip2, LZMA and Zstandard methods,
supports ZipCrypto and AES-256 encryption and writing, and keeps the API
shape of the original minizip while fixing its known weaknesses (no data
descriptor handling, no Zip64, no streaming writes).

```c
#include <mz.h>
#include <mz_strm.h>

mz_zip_file file;
mz_zip_reader reader;
mz_zip_reader_init_file(&reader, &file);

mz_zip_archive_file_stat stat;
if (mz_zip_reader_locate_file(&reader, "data.txt", NULL, 0, &stat)) {
    void *buf = malloc(stat.m_uncomp_size);
    mz_zip_reader_extract_to_mem(&reader, "data.txt", buf, stat.m_uncomp_size, 0);
    free(buf);
}
mz_zip_reader_end(&reader);
```

The API separates *what* (a file or a memory buffer, or a stream you
provide) from *how* (the reader and writer). That split is what lets the same
code read an entry from memory, from a file descriptor, or from a
`mz_stream` callback pair — which is how minizip-ng is used inside
frameworks that hand out streams rather than paths.

The pkg-config name is `minizip-ng` and the library `libminizip-ng.a`;
`MZ_COMPAT` would rename it to the old `libminizip`, which is off here so the
name cannot be confused with the other minizip.

## What retrolunar builds

A static `libminizip-ng.a`, the `mz*.h` headers and `minizip-ng.pc`.
Linked against the compression libraries and OpenSSL from this prefix:
zlib-ng (plus plain zlib for the compatibility path), bzip2, xz and zstd,
with ZipCrypto, PKWARE and WinZip AES encryption compiled in. The
`minizip-ng` and `minizip-crypt` command line tools, the tests and the
fuzz targets are off: host programs.

## Using it

```sh
pkg-config --cflags --libs minizip-ng
```

`mz.h`, `mz_strm.h`, `mz_strm_os.h` and `mz_strm_mem.h` are the headers a
consumer normally includes; the crypto extra needs `mz_strm_crypt.h` and
OpenSSL.

## Notes

- CMake build; the recipe passes `$CMAKE_FLAGS` plus minizip-ng's own
  switches. There is no "prefer external zlib" option: what there are are
  `MZ_FETCH_LIBS` and `MZ_FORCE_FETCH_LIBS`, and switching **those** off is
  what makes the build use the libraries already in the prefix instead of
  downloading its own.
- `MZ_FETCH_LIBS=OFF` matters here for more than tidiness: with fetching on,
  the build pulls its own zlib-ng and installs it into the same prefix,
  quietly duplicating a library the prefix already has.
- Zip64 is always on in this build, so large archives and >4 GB entries
  work without a separate flag.
