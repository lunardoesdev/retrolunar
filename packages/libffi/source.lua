return recipe({
    version = "3.8.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libffi.tar.gz ]; then
          curl -fSL -C - -o dl/libffi.tar.gz "https://github.com/libffi/libffi/releases/download/v3.8.0/libffi-3.8.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libffi.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libffi
        cp -r src/* $OUT/libffi/
    ]]
})
