# msgpack-c

msgpack-c is the reference C implementation of MessagePack, with a modern
C++ API layered on top. MessagePack is a binary serialisation format: like
JSON it has maps, arrays, strings and numbers, but it encodes them without
text, so it is compact and fast to parse.

The two APIs are the C `msgpack_packer`/`msgpack_unpacker` pair and the C++
`msgpack::sbuffer` / `msgpack::object` / `msgpack::packer` / `msgpack::unpacker`
types. The C++ side is what most callers want; the C side is there for
languages without a native binding.

```c
#include <msgpack.h>

msgpack_sbuffer sbuf;
msgpack_sbuffer_init(&sbuf);

msgpack_packer pk;
msgpack_packer_init(&pk, &sbuf, msgpack_sbuffer_write);
msgpack_pack_map(&pk, 2);
msgpack_pack_str(&pk, 5);
msgpack_pack_str_body(&pk, "greet", 5);
msgpack_pack_int64(&pk, 42);
msgpack_pack_str(&pk, 5);
msgpack_pack_str_body(&pk, "world", 5);

msgpack_unpacked result;
msgpack_unpacked_init(&result);
if (msgpack_unpack_next(&result, sbuf.data, sbuf.size) == MSGPACK_UNPACK_SUCCESS) {
    msgpack_object root = result.data;
    /* root.via.map.ptr[0].val.via.str.ptr is "greet" */
}
msgpack_unpacked_destroy(&result);
```

Every pack call on `msgpack_packer` reports a return code; a serious
implementation checks them, because a failed write leaves a truncated
buffer rather than aborting.

The tree types are reference-counted views over the buffer: an unpacked
`msgpack_object` points *into* the input bytes, so the buffer must outlive
the tree. `msgpack_unpack_next` does not copy unless you use
`msgpack_unpack_copy`.

## What retrolunar builds

A static `libmsgpack-c.a`, the C header (`msgpack.h`) and the C++ headers
(`msgpack.hpp`, `msgpack/`) in this configuration, plus `msgpack-c.pc` and a
CMake package config. The tests, the benchmarks and the C library variant
(`libmsgpack`) are off.

The C++ implementation is enabled and the pure-C one is not, so this
package is the `msgpack-c` library: packers, unpackers and the object tree
with both APIs available, statically linked.

## Using it

```sh
pkg-config --cflags --libs msgpack-c
```

CMake consumers use `find_package(msgpack-c)`.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and msgpack-c's own
  switches for which language binding and which extras to build.
- The library does no allocation of its own beyond the sbuffer you give it,
  which is why it suits a fixed-budget or no-exceptions environment. Pair it
  with `msgpack::zone` if you want an arena for the tree.
- To build msgpack (the multi-language package) on top of this one, point it
  at this prefix: msgpack's C++ library finds msgpack-c through
  `find_package` and links it statically here.
