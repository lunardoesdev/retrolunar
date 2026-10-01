return recipe({
    version = "3.6.12",
    build = [[
        mkdir -p dl
        if [ ! -f dl/astyle.tar.bz2 ]; then
          curl -fSL -C - -o dl/astyle.tar.bz2 "https://sourceforge.net/projects/astyle/files/astyle/astyle_3.6.12.tar.bz2/download" || curl -fSL -C - -o dl/astyle.tar.bz2 "https://deb.debian.org/debian/pool/main/a/astyle/astyle_3.6.12.orig.tar.bz2"
        fi
        rm -rf src
        mkdir -p src
        tar -xjf dl/astyle.tar.bz2 -C src --strip-components=1
        mkdir -p $OUT/astyle
        cp -r src/* $OUT/astyle/
    ]]
})