-- Eigen lives on GitLab, not GitHub; eigen-mirror/eigen carries only branch
-- names as "tags", so the release tags come from libeigen/eigen.
return recipe({
    version = "5.0.1",
    build = [[
        mkdir -p dl
        if [ ! -f dl/eigen.tar.gz ]; then
          curl -fSL -C - -o dl/eigen.tar.gz "https://gitlab.com/libeigen/eigen/-/archive/5.0.1/eigen-5.0.1.tar.gz"
        fi
        rm -rf src
        mkdir -p src
        tar -xzf dl/eigen.tar.gz -C src --strip-components=1
        mkdir -p $OUT/Eigen
        cp -r src/* $OUT/Eigen/
    ]]
})
