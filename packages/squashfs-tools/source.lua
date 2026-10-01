return recipe({
    version = "4.7.2",
    build = [[
        mkdir -p dl
        if [ ! -f dl/squashfs-tools.tar.gz ]; then
          curl -fSL -C - -o dl/squashfs-tools.tar.gz "https://github.com/plougher/squashfs-tools/archive/refs/tags/4.7.2.tar.gz" || \
          curl -fSL -C - -o dl/squashfs-tools.tar.gz "https://distfiles.macports.org/squashfs-tools/squashfs-tools-4.7.2.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        # The GitHub archive unpacks to squashfs-tools-4.7.2/ and the Makefile
        # that matters is in the squashfs-tools/ SUBDIRECTORY of that root, so
        # only the outer wrapper directory is stripped. The wrapper keeps
        # generate-manpages/ and Documentation/manpages/, which the install
        # target invokes as "generate-manpages/install-manpages.sh $(pwd)/..".
        tar -xzf dl/squashfs-tools.tar.gz -C src --strip-components=1
        mkdir -p $OUT/squashfs-tools
        cp -r src/* $OUT/squashfs-tools/
    ]]
})
