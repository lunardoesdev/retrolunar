return recipe({
    version = "1.3.5",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libmysofa.tar.gz ]; then
          curl -fSL -C - -o dl/libmysofa.tar.gz "https://codeload.github.com/hoene/libmysofa/tar.gz/refs/tags/v1.3.5"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libmysofa.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libmysofa
        cp -r src/* $OUT/libmysofa/
    ]]
})
