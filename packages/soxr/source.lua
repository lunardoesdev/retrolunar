return recipe({
    version = "0.1.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/soxr.tar.gz ]; then
          curl -fSL -C - -o dl/soxr.tar.gz "https://codeload.github.com/chirlu/soxr/tar.gz/refs/tags/0.1.3"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/soxr.tar.gz -C src --strip-components=1
        mkdir -p $OUT/soxr
        cp -r src/* $OUT/soxr/
    ]]
})
