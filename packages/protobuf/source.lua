return recipe({
    version = "36.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/protobuf.tar.gz ]; then
          curl -fSL -C - -o dl/protobuf.tar.gz "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protobuf-36.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The release tarball carries the third_party submodules as real
        # content: third_party/utf8_range/CMakeLists.txt is present, which the
        # git tag archive would not have. cmake/utf8_range.cmake:4 hard-fails
        # if it is missing.
        tar -xzf dl/protobuf.tar.gz -C src --strip-components=1
        mkdir -p $OUT/protobuf
        cp -r src/* $OUT/protobuf/
    ]]
})