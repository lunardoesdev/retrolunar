return recipe({
    version = "2.72",
    build = [[
        mkdir -p dl
        if [ ! -f dl/autoconf.tar.xz ]; then
          curl -fSL -C - -o dl/autoconf.tar.xz "https://ftp.gnu.org/gnu/autoconf/autoconf-2.72.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/autoconf.tar.xz -C src --strip-components=1
        mkdir -p $OUT/autoconf
        cp -r src/* $OUT/autoconf/
    ]]
})
