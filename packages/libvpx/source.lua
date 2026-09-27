return recipe({
    version = "1.15.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libvpx.tar.gz ]; then
          curl -fSL -C - -o dl/libvpx.tar.gz "https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libvpx.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libvpx
        cp -r src/* $OUT/libvpx/
    ]]
})
