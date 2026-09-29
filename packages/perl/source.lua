return recipe({
    version = "5.44.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/perl.tar.gz ]; then
          curl -fSL -C - -o dl/perl.tar.gz "https://www.cpan.org/src/5.0/perl-5.44.0.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/perl.tar.gz -C src --strip-components=1
        mkdir -p $OUT/perl
        cp -r src/. $OUT/perl/
    ]]
})
