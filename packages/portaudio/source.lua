return recipe({
    version = "19.7.0",
    build = [[
        mkdir -p dl
        if [ ! -f dl/portaudio.tar.gz ]; then
          curl -fSL -C - -o dl/portaudio.tar.gz "https://codeload.github.com/PortAudio/portaudio/tar.gz/refs/tags/v19.7.0"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/portaudio.tar.gz -C src --strip-components=1
        mkdir -p $OUT/portaudio
        cp -r src/* $OUT/portaudio/
    ]]
})
