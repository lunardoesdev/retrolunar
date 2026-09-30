# Snappy

Snappy is Google's fast LZ77-style compressor. It trades a little ratio for
a lot of speed: decompression runs at roughly GB/s and compression is
usually faster than copying the same buffer. It is the codec behind many
wire and container formats — Protocol Buffers, FlatBuffers, CRAM, and the
`.sz` extension.

The API is a handful of calls:

```cpp
#include <snappy.h>

std::string out;
snappy::Compress(input, &out);

size_t size;
if (snappy::GetUncompressedLength(out.data(), out.size(), &size)) {
    std::string input2(size, '\0');
    snappy::Uncompress(out.data(), out.size(), input2.data());
}
```

Compression never fails for lack of memory: the output buffer is grown as
needed. Uncompression can fail, and the two-step length query is the cheap
way to avoid a buffer sized by a hostile input.

## What retrolunar builds

A static `libsnappy.a` (C++ internally, C++ ABI at the boundary), the
`snappy.h` and `snappy-stubs-public.h` headers, and a CMake package config
under `lib/cmake/Snappy/`.

Snappy 1.2.2 does not install a pkg-config file, so `pkg-config --libs
snappy` will not work: link with `-lsnappy` and add `$PREFIX/include`, or
consume it from CMake with `find_package(Snappy)` and
`$PREFIX` in `CMAKE_PREFIX_PATH`.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS`.
- `SNAPPY_BUILD_TESTS=OFF` and `SNAPPY_BUILD_BENCHMARKS=OFF` keep host
  programs out of a target prefix.
- The C++ standard library is a link-time dependency of the archive, so
  link with `clang++` or add `-lstdc++` to a C link line.
