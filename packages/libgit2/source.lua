return recipe({
    version = "1.9.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/libgit2-1.9.7.tar.gz ]; then
          curl -fSL -C - -o dl/libgit2-1.9.7.tar.gz "https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.7.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/libgit2-1.9.7.tar.gz -C src --strip-components=1
        mkdir -p $OUT/libgit2
        cp -r src/* $OUT/libgit2/
    ]]
})