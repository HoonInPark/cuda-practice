# --- CUDA ---
find_package(CUDAToolkit REQUIRED)

if(CUDAToolkit_FOUND)
    message(STATUS "CUDA Toolkit Version: ${CUDAToolkit_VERSION}")

    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
            ${CUDA_INCLUDE_DIRS}
    )
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
            CUDA::cudart
    )
else()
    message(FATAL_ERROR "CUDA Toolkit not found")
endif()
