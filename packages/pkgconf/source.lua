return recipe({
    version = "3.0.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/pkgconf.tar.xz ]; then
          curl -fSL -C - -o dl/pkgconf.tar.xz "https://github.com/pkgconf/pkgconf/releases/download/pkgconf-3.0.7/pkgconf-3.0.7.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/pkgconf.tar.xz -C src --strip-components=1
        mkdir -p $OUT/pkgconf
        cp -r src/* $OUT/pkgconf/
    ]]
})
