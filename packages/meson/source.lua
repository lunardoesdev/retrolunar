return recipe({
    version = "1.9.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/meson.tar.gz ]; then
          curl -fSL -C - -o dl/meson.tar.gz "https://github.com/mesonbuild/meson/releases/download/1.9.1/meson-1.9.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/meson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/meson
        cp -r src/* $OUT/meson/
    ]]
})
