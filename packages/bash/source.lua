return recipe({
    version = "5.3",
    build = [[
        mkdir -p dl
        if [ ! -f dl/bash.tar.gz ]; then
          curl -fSL -C - -o dl/bash.tar.gz "https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/bash.tar.gz -C src --strip-components=1
        mkdir -p $OUT/bash
        cp -r src/* $OUT/bash/
    ]]
})
