return recipe({
    version = "6.3.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gmp.tar.xz ]; then
          curl -fSL -C - -o dl/gmp.tar.xz "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/gmp.tar.xz -C src --strip-components=1
        mkdir -p $OUT/gmp
        cp -r src/* $OUT/gmp/
    ]]
})
