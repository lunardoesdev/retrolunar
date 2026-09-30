return recipe({
    version = "25.2.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/flatbuffers.tar.gz ]; then
          curl -fSL -C - -o dl/flatbuffers.tar.gz "https://github.com/google/flatbuffers/archive/refs/tags/v25.2.10.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/flatbuffers.tar.gz -C src --strip-components=1
        mkdir -p $OUT/flatbuffers
        cp -r src/* $OUT/flatbuffers/
    ]]
})
