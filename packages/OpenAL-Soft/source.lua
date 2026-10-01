return recipe({
    version = "1.21.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/openal-soft.tar.gz ]; then
          curl -fSL -C - -o dl/openal-soft.tar.gz "https://github.com/kcat/openal-soft/archive/refs/tags/openal-soft-1.21.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/openal-soft.tar.gz -C src --strip-components=1
        mkdir -p $OUT/OpenAL-Soft
        cp -r src/* $OUT/OpenAL-Soft/
    ]]
})
