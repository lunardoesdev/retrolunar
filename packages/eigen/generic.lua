require("eigen@source")

-- Header-only: no compilation. Install headers + cmake config.
-- Provides Eigen3::Eigen via EIGEN3_INCLUDE_DIR for find_package.
return recipe({
    build = [[
        cp -r $NESTDIR/source/eigen/* .
        mkdir -p $OUT/include $OUT/share/eigen3/cmake
        cp -r Eigen $OUT/include/
        cp -r unsupported $OUT/include/
        cat > $OUT/share/eigen3/cmake/eigen3-config.cmake <<EOF
        set(EIGEN3_INCLUDE_DIR "$PREFIX/include")
        if(NOT TARGET Eigen3::Eigen)
          add_library(Eigen3::Eigen INTERFACE IMPORTED)
          set_target_properties(Eigen3::Eigen PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "$PREFIX/include")
        endif()
        EOF
    ]]
})
