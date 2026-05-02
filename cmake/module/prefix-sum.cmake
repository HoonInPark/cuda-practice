set(THIS_MODULE_NAME prefix-sum)

add_library(${THIS_MODULE_NAME}
        src/cpp/module/prefix-sum.cu
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
        ${THIS_MODULE_NAME}
)
