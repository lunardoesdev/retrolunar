return recipe({
    version = "1.12.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/meson.tar.gz ]; then
          curl -fSL -C - -o dl/meson.tar.gz "https://pypi.org/packages/source/m/meson/meson-1.12.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/meson.tar.gz -C src --strip-components=1
        mkdir -p $OUT/meson
        cp -r src/* $OUT/meson/
    ]]
})
