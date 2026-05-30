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
  const size_t buff_size = sizeof(int) * nums.size();

  int* dev_ptr_even;
  cudaMalloc(&dev_ptr_even, buff_size);

  int* dev_ptr_odd;
  cudaMalloc(&dev_ptr_odd, buff_size);

  // copy H2D
  if (auto ret = cudaMemcpyAsync(dev_ptr_even, nums.data(), buff_size, cudaMemcpyHostToDevice, stream)) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */
  const auto round_total = static_cast<size_t>(log2(nums.size())) + 1;

  // timer settings /////////
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  ///////////////////////////

  cudaEventRecord(start, stream);
  for (size_t round = 0; round < round_total; round++) {
    const auto empty_front_num = static_cast<size_t>(powf(2, round));
    if (0 == round % 2) {
      // even round : from even to odd
      if (auto ret = cudaMemcpyAsync(dev_ptr_odd, dev_ptr_even, sizeof(int) * empty_front_num, cudaMemcpyDeviceToDevice, stream)) {
        cout << "cuda Error return code : " << ret << endl;
        return;
      }

      KoggeStoneScan<<<(nums.size() - empty_front_num + kBlockSize - 1) / kBlockSize, kBlockSize, 0, stream>>>(dev_ptr_odd, dev_ptr_even, nums.size(), round, empty_front_num);
    } else {
      // odd round : from odd to even
      if (auto ret = cudaMemcpyAsync(dev_ptr_even, dev_ptr_odd, sizeof(int) * empty_front_num, cudaMemcpyDeviceToDevice, stream)) {
        cout << "cuda Error return code : " << ret << endl;
        return;
      }

      KoggeStoneScan<<<(nums.size() - empty_front_num + kBlockSize - 1) / kBlockSize, kBlockSize, 0, stream>>>(dev_ptr_even, dev_ptr_odd, nums.size(), round, empty_front_num);
    }
  }

  // timer settings /////////
  cudaEventRecord(stop, stream);
  cudaEventSynchronize(stop);
  float elapsed_ms = 0.0f;
  cudaEventElapsedTime(&elapsed_ms, start, stop);
  cout << "cuda timer : " << elapsed_ms << endl;
  ///////////////////////////

  // copy D2H
  auto res_ptr = round_total % 2 ? dev_ptr_odd : dev_ptr_even;
  if (auto ret = cudaMemcpyAsync(nums.data(), res_ptr, buff_size, cudaMemcpyDeviceToHost, stream)) {
    cout << "cuda Error return code : " << ret << endl;
  }

  // dealloc
  cudaDeviceSynchronize();
  cudaFree(dev_ptr_even);
  cudaFree(dev_ptr_odd);

  cudaStreamDestroy(stream);
}

__global__ void KoggeStoneScan(int* dst, int* src, size_t total_size, size_t round, size_t start_offset) {
  // if 1 dim block as this, blockDim.x is same and more flexible rather than kBlockSize.
  // my team leader said for extreme optimization, g_idx calculation can be replaced as dim value.
  const size_t g_idx = start_offset + blockIdx.x * blockDim.x + threadIdx.x;
  if (g_idx > total_size - 1) {
    return;
  }

  dst[g_idx] = src[g_idx] + src[g_idx - static_cast<size_t>(powf(2, round))];
}
