cmake_minimum_required(VERSION 3.22)
project(cuda-practice LANGUAGES CXX)

add_executable(cuda-practice src/cpp/main.cpp)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

file(GLOB CMAKE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/cmake/*.cmake")
foreach(cmake_file ${CMAKE_FILES})
    include(${cmake_file})
endforeach()
