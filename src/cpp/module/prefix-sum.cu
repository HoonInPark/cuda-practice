#include "prefix-sum.cuh"

#include <cmath>
#include <iostream>
#include <ostream>

constexpr size_t kBlockSize = 32;

void MakeIncrementalNums(vector<int>& nums, int max_num) {
  nums.reserve(max_num);
  for (int i = 1; i < max_num + 1; i++)
    nums.push_back(i);
}

void KoggeStoneScan_Entry(vector<int>& nums) {
  /**
   * u can see stream use cases in the post below :
   * https://hayunjong83.tistory.com/28
   */
  cudaStream_t stream;
  cudaStreamCreate(&stream);

  // allocate vram with device pointer and its size
  int* dev_ptr;
  const size_t dev_mem_size = sizeof(int) * nums.size();
  cudaMalloc(&dev_ptr, dev_mem_size);

  // copy H2D
  if (auto ret = cudaMemcpyAsync(dev_ptr, nums.data(), dev_mem_size, cudaMemcpyHostToDevice, stream)) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */
  const auto round_total = static_cast<size_t>(log2(nums.size())) + 1;
  for (size_t round = 0; round < round_total; round++) {
    const auto empty_front_num = static_cast<size_t>(powf(2, round));
    KoggeStoneScan<<<(nums.size() - empty_front_num + kBlockSize - 1) / kBlockSize, kBlockSize, 0, stream>>>(dev_ptr, nums.size(), round, empty_front_num);
  }

  // copy D2H
  if (auto ret = cudaMemcpyAsync(nums.data(), dev_ptr, dev_mem_size, cudaMemcpyDeviceToHost, stream)) {
    cout << "cuda Error return code : " << ret << endl;
  }

  // dealloc
  cudaDeviceSynchronize();
  cudaFree(dev_ptr);

  cudaStreamDestroy(stream);
}

__global__ void KoggeStoneScan(int* devPtr, const size_t total_size, const size_t round, const size_t start_offset) {
  size_t g_idx = start_offset + blockIdx.x * kBlockSize + threadIdx.x;
  
}
