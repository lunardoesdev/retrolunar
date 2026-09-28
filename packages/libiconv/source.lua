return recipe({
    version = "1.18",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libiconv.tar.gz ]; then
          curl -fSL -C - -o dl/libiconv.tar.gz "https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libiconv.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libiconv
        cp -r src/* $OUT/libiconv/
    ]]
})
