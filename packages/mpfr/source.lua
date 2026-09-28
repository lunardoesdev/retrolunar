return recipe({
    version = "4.2.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/mpfr.tar.xz ]; then
          curl -fSL -C - -o dl/mpfr.tar.xz "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/mpfr.tar.xz -C src --strip-components=1
        mkdir -p $OUT/mpfr
        cp -r src/* $OUT/mpfr/
    ]]
})
