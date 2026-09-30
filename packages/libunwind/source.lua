return recipe({
    version = "1.8.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libunwind.tar.gz ]; then
          curl -fSL -C - -o dl/libunwind.tar.gz "https://github.com/libunwind/libunwind/releases/download/v1.8.3/libunwind-1.8.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libunwind.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libunwind
        cp -r src/* $OUT/libunwind/
    ]]
})
