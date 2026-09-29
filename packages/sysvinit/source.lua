return recipe({
    version = "3.14",
    build = [[
        mkdir -p dl
        if [ ! -f dl/sysvinit.tar.xz ]; then
          curl -fSL -C - -o dl/sysvinit.tar.xz "https://github.com/slicer69/sysvinit/releases/download/3.14/sysvinit-3.14.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/sysvinit.tar.xz -C src --strip-components=1
        mkdir -p $OUT/sysvinit
        cp -r src/* $OUT/sysvinit/
    ]]
})
