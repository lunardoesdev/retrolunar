return recipe({
    version = "4.10",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sed.tar.xz ]; then
          curl -fSL -C - -o dl/sed.tar.xz "https://ftp.gnu.org/gnu/sed/sed-4.10.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/sed.tar.xz -C src --strip-components=1
        mkdir -p $OUT/sed
        cp -r src/* $OUT/sed/
    ]]
})
