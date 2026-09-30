# FlatBuffers

FlatBuffers is a cross-language serialization format built for reading
without parsing: a buffer is laid out so that a reader can follow offsets
straight to the fields it wants, and skip the rest. There is no schema
instantiation step, which is why it shows up in performance-sensitive code
where Protobuf's parse step is measurable.

The trade is that you generally hand out `const uint8_t*` pointers into
the buffer rather than objects, so a buffer must outlive everything that
reads it, and mutation means writing a new buffer.

```cpp
#include <flatbuffers/flatbuffers.h>

flatbuffers::FlatBufferBuilder builder;
auto name = builder.CreateString("retrolunar");
MonsterBuilder monster(builder);
monster.add_name(name);
monster.add_hp(100);
builder.Finish(monster.Finish());

auto buf = builder.GetBufferPointer();
auto monster = flatbuffers::GetRoot<Monster>(buf);
if (monster->name()) std::cout << monster->name()->str() << '\n';
```

A `.fbs` schema is compiled once by `flatc` into C++ accessors; at run time
nothing reads the schema.

## What retrolunar builds

A static `libflatbuffers.a`, the C++ and C headers, `flatbuffers.pc`, the
`flatc` schema compiler, and the `flatc` C++/C/Proto/Python code generators
installed under `bin/`. Tests and the gRPC test program are off: they are
host programs and pull in dependencies this prefix does not have.

## Using it

```sh
pkg-config --cflags --libs flatbuffers
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and flatbuffers' own
  options for what to skip.
- `flatc` is a program, and like every other program here it is built for
  the target and never run during a build. Generating code with it means
  running it on the build machine, using a host `flatc`, not this one.
- Verifier-generated accessors (`--gen-verify`) need gtest at build time in
  your project, not here.
