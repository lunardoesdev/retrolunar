# If CMAKE_SYSTEM_NAME is set to Android, cmake starts doing its own NDK
# integration magic, but here it is done by hand, so keep Linux.
set(CMAKE_SYSTEM_NAME Linux)

# CPU architecture
set(CMAKE_SYSTEM_PROCESSOR "aarch64")

# C compiler from the environment if not already set
if(NOT CMAKE_C_COMPILER)
  set(CMAKE_C_COMPILER "$ENV{CC}" CACHE FILEPATH "C compiler" FORCE)
endif()
# Same for C++
if(NOT CMAKE_CXX_COMPILER)
  set(CMAKE_CXX_COMPILER "$ENV{CXX}" CACHE FILEPATH "C++ compiler" FORCE)
endif()

set(CMAKE_AR "$ENV{AR}" CACHE FILEPATH "archiver" FORCE)
set(CMAKE_RANLIB "$ENV{RANLIB}" CACHE FILEPATH "ranlib" FORCE)
set(CMAKE_STRIP "$ENV{STRIP}" CACHE FILEPATH "strip" FORCE)
set(CMAKE_READELF "$ENV{READELF}" CACHE FILEPATH "readelf" FORCE)
set(CMAKE_OBJDUMP "$ENV{OBJDUMP}" CACHE FILEPATH "objdump" FORCE)
set(CMAKE_OBJCOPY "$ENV{OBJCOPY}" CACHE FILEPATH "objcopy" FORCE)
set(CMAKE_NM "$ENV{NM}" CACHE FILEPATH "nm" FORCE)
set(CMAKE_ASM_COMPILER "$ENV{AS}" CACHE FILEPATH "assembler" FORCE)
set(CMAKE_LINKER "$ENV{LD}" CACHE FILEPATH "linker" FORCE)
set(CMAKE_SYSROOT "$ENV{SYSROOT}")
set(CMAKE_INSTALL_PREFIX "$ENV{PREFIX}" CACHE PATH "install prefix")

# For find_library/find_path look in PREFIX first, then SYSROOT
set(CMAKE_FIND_ROOT_PATH "$ENV{PREFIX};$ENV{SYSROOT}")

# Never look for runnable utilities in CMAKE_FIND_ROOT_PATH (SYSROOT/PREFIX)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

# Libraries only in SYSROOT or PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Headers only in SYSROOT or PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
# CMake packages (find_package) also only in SYSROOT or PREFIX
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
