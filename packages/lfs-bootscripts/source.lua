return recipe({
    version = "20250827",
    build = [[
        mkdir -p dl
        if [ ! -f dl/lfs-bootscripts.tar.xz ]; then
          curl -fSL -C - -o dl/lfs-bootscripts.tar.xz "https://www.linuxfromscratch.org/lfs/downloads/12.4/lfs-bootscripts-20250827.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/lfs-bootscripts.tar.xz -C src --strip-components=1
        mkdir -p $OUT/lfs-bootscripts
        cp -r src/* $OUT/lfs-bootscripts/
    ]]
})
