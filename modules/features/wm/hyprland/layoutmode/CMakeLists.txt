cmake_minimum_required(VERSION 3.19)
project(layoutmode VERSION "0.2.1")

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_options(
  -Wall
  -Wno-unused-parameter
  --no-gnu-unique
)

find_package(PkgConfig REQUIRED)
pkg_check_modules(HYPR_DEPS REQUIRED hyprland)

add_library(layoutmode SHARED src/main.cpp)

target_include_directories(layoutmode PRIVATE ${HYPR_DEPS_INCLUDE_DIRS})
target_link_libraries(layoutmode PRIVATE ${HYPR_DEPS_LIBRARIES})

install(TARGETS layoutmode LIBRARY DESTINATION lib)
