return recipe({
    version = "3.100",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lame.tar.gz ]; then
          curl -fSL -C - -o dl/lame.tar.gz "https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lame.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lame
        cp -r src/* $OUT/lame/
    ]]
})
