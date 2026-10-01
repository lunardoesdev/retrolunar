return recipe({
    version = "6.2.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/universal-ctags.tar.gz ]; then
          curl -fSL -C - -o dl/universal-ctags.tar.gz "https://github.com/universal-ctags/ctags/releases/download/v6.2.1/universal-ctags-6.2.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/universal-ctags.tar.gz -C src --strip-components=1
        mkdir -p $OUT/universal-ctags
        cp -r src/* $OUT/universal-ctags/
    ]]
})