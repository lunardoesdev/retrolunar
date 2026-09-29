return recipe({
    version = "4.0.7",
    build = [[
        mkdir -p dl
        if [ ! -f dl/procps.tar.xz ]; then
          curl -fSL -C - -o dl/procps.tar.xz "https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-4.0.7.tar.xz/download"
        fi
        rm -rf src
        mkdir -p src
        tar -xf dl/procps.tar.xz -C src --strip-components=1
        mkdir -p $OUT/procps
        cp -r src/* $OUT/procps/
    ]]
})
