return recipe({
    version = "29.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/protobuf.tar.gz ]; then
          curl -fSL -C - -o dl/protobuf.tar.gz "https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protobuf-29.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/protobuf.tar.gz -C src --strip-components=1
        mkdir -p $OUT/protobuf
        cp -r src/* $OUT/protobuf/
    ]]
})
