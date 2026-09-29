return recipe({
    version = "20230818",
    build = [[
        mkdir -p dl
        if [ ! -f dl/udev-lfs.tar.xz ]; then
          curl -fSL -C - -o dl/udev-lfs.tar.xz "https://anduin.linuxfromscratch.org/LFS/udev-lfs-20230818.tar.xz"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/udev-lfs.tar.xz -C src --strip-components=1
        mkdir -p $OUT/udev-lfs
        cp -r src/* $OUT/udev-lfs/
    ]]
})
