-- The project is "easylogging++" but the GitHub repository is
-- abumq/easyloggingpp; the old path abumq/easylogging-plusplus is a 404.
-- The README (README.md:102) points at abumq/easyloggingpp/releases itself.
return recipe({
    version = "9.97.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/easyloggingpp.tar.gz ]; then
          curl -fSL -C - -o dl/easyloggingpp.tar.gz "https://github.com/abumq/easyloggingpp/archive/refs/tags/v9.97.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/easyloggingpp.tar.gz -C src --strip-components=1
        mkdir -p $OUT/easylogging-plusplus
        cp -r src/* $OUT/easylogging-plusplus/
    ]]
})
