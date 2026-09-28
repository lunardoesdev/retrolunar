return recipe({
    version = "9.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/coreutils.tar.xz ]; then
          curl -fSL -C - -o dl/coreutils.tar.xz "https://ftp.gnu.org/gnu/coreutils/coreutils-9.7.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/coreutils.tar.xz -C src --strip-components=1
        mkdir -p $OUT/coreutils
        cp -r src/* $OUT/coreutils/
    ]]
})
