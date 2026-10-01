return recipe({
    version = "15.2.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/armadillo.tar.xz ]; then
          curl -fSL -C - -o dl/armadillo.tar.xz "https://sourceforge.net/projects/arma/files/armadillo-15.2.1.tar.xz/download" || curl -fSL -C - -o dl/armadillo.tar.xz "https://deb.debian.org/debian/pool/main/a/armadillo/armadillo_15.2.1+dfsg.orig.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/armadillo.tar.xz -C src --strip-components=1
        mkdir -p $OUT/armadillo
        cp -r src/* $OUT/armadillo/
    ]]
})