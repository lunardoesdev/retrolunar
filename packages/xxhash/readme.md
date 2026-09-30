# xxHash

xxHash is an extremely fast non-cryptographic hash algorithm by Yann Collet,
designed for hash tables, checksums and content addressing rather than for
attack resistance. It is the hashing layer of the Zstandard compressor and
is used widely in file formats and databases.

The library is a handful of functions over a streaming state:

```c
#include <xxhash.h>

XXH64_state_t *state = XXH64_createState();
XXH64_reset(state, 0);
XXH64_update(state, chunk, chunk_size);
XXH64_hash_t h = XXH64_digest(state);
XXH64_freeState(state);
```

`XXH3_64bits()` is the one-shot variant and is what most callers want.
`XXH32` and `XXH64` are the older, wider-compatibility entry points, kept
for formats that specify them.

## What retrolunar builds

`libxxhash.a`, the single `xxhash.h` header, `xxhash.pc` and `bin/xxhsum`,
the command line front end that hashes files and stdin.

## Using it

```sh
pkg-config --cflags --libs libxxhash
```

## Notes

- The recipe passes only `$CMAKE_FLAGS`; the toolchain file, install prefix
  and search prefix are the system's business, not the package's.
- `-DBUILD_SHARED_LIBS=OFF` avoids a shared object in the prefix.
- xxHash is a C library with no dependencies, so it needs none of ours and
  can be required from anywhere.
