return recipe({
    version = "1.2.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libsndfile.tar.xz ]; then
          curl -fSL -C - -o dl/libsndfile.tar.xz "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xJf dl/libsndfile.tar.xz -C src --strip-components=1
        mkdir -p $OUT/libsndfile
        cp -r src/* $OUT/libsndfile/
    ]]
})