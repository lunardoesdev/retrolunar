return recipe({
    version = "2.5.4",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libtool.tar.gz ]; then
          curl -fSL -C - -o dl/libtool.tar.gz "https://ftp.gnu.org/gnu/libtool/libtool-2.5.4.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libtool.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libtool
        cp -r src/* $OUT/libtool/
    ]]
})
