-- ftp.gnu.org is slow/unreachable from this host for some versions;
-- mirrors.kernel.org carries the identical 3.9.1 tarball and responds.
return recipe({
    version = "3.10.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/nettle.tar.gz ]; then
          curl -fSL -C - -o dl/nettle.tar.gz "https://mirrors.kernel.org/gnu/nettle/nettle-3.10.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/nettle.tar.gz -C src --strip-components=1
        mkdir -p $OUT/nettle
        cp -r src/* $OUT/nettle/
    ]]
})
