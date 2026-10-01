return recipe({
    version = "3.3.11",
    build = [[
        mkdir -p dl
        if [ ! -f dl/fftw.tar.gz ]; then
          curl -fSL -C - -o dl/fftw.tar.gz "https://www.fftw.org/fftw-3.3.11.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/fftw.tar.gz -C src --strip-components=1
        mkdir -p $OUT/fftw
        cp -r src/* $OUT/fftw/
    ]]
})