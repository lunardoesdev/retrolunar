return recipe({
    version = "1.15",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gzip.tar.xz ]; then
          curl -fSL -C - -o dl/gzip.tar.xz "https://ftp.gnu.org/gnu/gzip/gzip-1.15.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/gzip.tar.xz -C src --strip-components=1
        mkdir -p $OUT/gzip
        cp -r src/* $OUT/gzip/
    ]]
})
