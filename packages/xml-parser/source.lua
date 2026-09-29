return recipe({
    version = "2.47",
    build = [[
        mkdir -p dl
        if [ ! -f dl/XML-Parser.tar.gz ]; then
          curl -fSL -C - -o dl/XML-Parser.tar.gz "https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-2.47.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/XML-Parser.tar.gz -C src --strip-components=1
        mkdir -p $OUT/xml-parser
        cp -r src/* $OUT/xml-parser/
    ]]
})
