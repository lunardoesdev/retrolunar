# Draco

Draco is Google's library for compressing 3D geometry: meshes and point
clouds. It is the codec behind the `KHR_draco_mesh_compression` WebGL
extension, and it beats uncompressed buffers by a wide margin — for a
typical mesh, roughly 10x smaller at visually identical quality, because it
quantises attributes and reorders triangles to make them compressible.

The API is a small C++ interface that works on a `draco::Mesh`, which you
either load from a file or fill in yourself.

```cpp
#include <draco/compression/decode.h>
#include <draco/core/decoder_buffer.h>
#include <draco/mesh/mesh.h>

draco::DecoderBuffer buffer;
buffer.Init(data, size);

int pos = 0;
draco::Mesh mesh;
const draco::Status status =
    draco::DecodeMeshFromBuffer(&buffer, &mesh);
if (!status.ok()) { /* status.error_msg() */ }

for (draco::PointIndex i(0); i < mesh.num_points(); ++i) {
    const draco::PointAttribute *pos_attr = mesh.attribute(geometry::AttributeType::POSITION);
    /* Vector3f(pos_attr->value(i)) */
}
```

Decoding wants the whole compressed buffer in memory and produces an
uncompressed mesh in memory, so peak memory is a real consideration for
large models — the uncompressed side is several times the compressed size.

Encoding goes through `draco::Encoder`, with `SetSpeedOptions` trading
compression ratio for time and `SetAttributeQuantization` controlling the
per-attribute bit depth, which is where the size/quality decision actually
lives.

## What retrolunar builds

A static `libdraco.a` (encoder and decoder in one archive, plus a merged
symbol set), the `draco/` headers and the generated `draco_features.h`. The
gtest-based test suite is off: it is a large host program suite.

Draco does **not** install a pkg-config file, so link `-ldraco` and add
`$PREFIX/include`; CMake consumers can still `find_path`/`find_library`,
or use the exported config if a consumer happens to ship one.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and Draco's own
  `DRACO_TESTS=OFF`.
- Draco is C++, so consumers need the C++ runtime; the archive was built
  with the system's `CXXFLAGS`, which on Android carries `-DANDROID` and
  the libc++ include paths.
- Draco encodes geometry only. For textures use a texture codec, and for
  whole scenes glTF's `EXT_meshopt_compression` or `EXT_draco` both exist —
  draco is the one Draco implements.
