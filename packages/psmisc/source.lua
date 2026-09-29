return recipe({
    version = "23.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/psmisc.tar.xz ]; then
          curl -fSL -C - -o dl/psmisc.tar.xz "https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.7.tar.xz/download"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/psmisc.tar.xz -C src --strip-components=1
        mkdir -p $OUT/psmisc
        cp -r src/* $OUT/psmisc/
    ]]
})
