return recipe({
    version = "5.4.8",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lua.tar.gz ]; then
          curl -fSL -C - -o dl/lua.tar.gz "https://www.lua.org/ftp/lua-5.4.8.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/lua.tar.gz -C src --strip-components=1
        mkdir -p $OUT/lua
        cp -r src/* $OUT/lua/
    ]]
})
