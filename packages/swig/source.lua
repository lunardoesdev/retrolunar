return recipe({
    version = "4.5.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/swig.tar.gz ]; then
          curl -fSL -C - -o dl/swig.tar.gz "https://sourceforge.net/projects/swig/files/swig/swig-4.5.1/swig-4.5.1.tar.gz/download" || curl -fSL -C - -o dl/swig.tar.gz "https://deb.debian.org/debian/pool/main/s/swig/swig_4.5.1.orig.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/swig.tar.gz -C src --strip-components=1
        mkdir -p $OUT/swig
        cp -r src/* $OUT/swig/
    ]]
})