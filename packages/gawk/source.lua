return recipe({
    version = "5.3.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/gawk.tar.xz ]; then
          curl -fSL -C - -o dl/gawk.tar.xz "https://ftp.gnu.org/gnu/gawk/gawk-5.3.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/gawk.tar.xz -C src --strip-components=1
        mkdir -p $OUT/gawk
        cp -r src/* $OUT/gawk/
    ]]
})
