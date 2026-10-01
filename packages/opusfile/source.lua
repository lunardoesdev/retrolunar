return recipe({
    version = "0.12",
    build = [[
        mkdir -p dl
        if [ ! -f dl/opusfile.tar.gz ]; then
          curl -fSL -C - -o dl/opusfile.tar.gz "https://github.com/xiph/opusfile/releases/download/v0.12/opusfile-0.12.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/opusfile.tar.gz -C src --strip-components=1
        mkdir -p $OUT/opusfile
        cp -r src/* $OUT/opusfile/
    ]]
})