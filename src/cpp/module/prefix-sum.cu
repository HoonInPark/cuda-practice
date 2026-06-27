#include "prefix-sum.cuh"

#include <cmath>
#include <iostream>
#include <ostream>

__global__ void MakeIncrementalNums_CUDA(ull* dev_ptr, size_t size) {
  const size_t g_idx = blockIdx.x * blockDim.x + threadIdx.x;

  if (g_idx >= size) {
    return;
  }

  dev_ptr[g_idx] = static_cast<ull>(g_idx);
}

__global__ void KoggeStoneScan(ull* dst, ull* src, size_t total_size, size_t round, size_t start_offset) {
  // if 1 dim block as this, blockDim.x is same and more flexible rather than kBlockSize.
  // my team leader said for extreme optimization, g_idx calculation can be replaced as dim value.
  const size_t g_idx = start_offset + blockIdx.x * blockDim.x + threadIdx.x;
  if (g_idx > total_size - 1) {
    return;
  }

  dst[g_idx] = src[g_idx] + src[g_idx - static_cast<size_t>(powf(2, round))];
}

TestBed::TestBed() {
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  cout << "shared memory size : " << prop.sharedMemPerBlock << endl;
  cout << "shared memory optin size : " << prop.sharedMemPerBlockOptin << endl;
  cout << "mem size of sm shared for multiplt blocks : " << prop.sharedMemPerMultiprocessor << endl;

  cudaStreamCreate(&stream_);

  // timer settings /////////
  cudaEventCreate(&start_);
  cudaEventCreate(&stop_);
  ///////////////////////////
}

TestBed::~TestBed() {
  cudaStreamDestroy(stream_);
}

// ull => 8 byte
// size_t => 8 byte in 64 bit os
void TestBed::MakeIncrementalNums(vector<ull>& nums, ull max_num) {
  nums.resize(max_num);
  // for (ull i = 1; i < max_num + 1; i++)
  //   nums.push_back(i);

  ull* dev_ptr;
  size_t buff_size = sizeof(ull) * max_num;
  cudaMalloc(&dev_ptr, buff_size);

  cudaEventRecord(start_, stream_);
  MakeIncrementalNums_CUDA<<<(max_num - 1) / kBlockSize + 1, kBlockSize, 0, stream_>>>(dev_ptr, max_num);
  cudaEventRecord(stop_, stream_);
  cudaEventSynchronize(stop_);

  float elapsed_ms = 0.0f;
  cudaEventElapsedTime(&elapsed_ms, start_, stop_);

  cout << "MakeIncrementalNums_CUDA : " << elapsed_ms << " ms" << endl;

  cudaMemcpyAsync(nums.data(), dev_ptr, sizeof(ull) * nums.size(), cudaMemcpyDeviceToHost, stream_);

  cudaStreamSynchronize(stream_);
  cudaFree(dev_ptr);

  cout << "last num for check : " << nums[nums.size() - 1] << endl;
}

void TestBed::KoggeStoneScan_Entry(vector<ull>& nums) {
  /**
   * u can see stream use cases in the post below :
   * https://hayunjong83.tistory.com/28
   */

  // allocate vram with device pointer and its size
  const size_t buff_size = sizeof(ull) * nums.size();

  ull* dev_ptr_even;
  cudaMalloc(&dev_ptr_even, buff_size);

  ull* dev_ptr_odd;
  cudaMalloc(&dev_ptr_odd, buff_size);

  // copy H2D
  if (auto ret = cudaMemcpyAsync(dev_ptr_even, nums.data(), buff_size, cudaMemcpyHostToDevice, stream_)) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */
  const auto round_total = static_cast<size_t>(log2(nums.size())) + 1;

  cudaEventRecord(start_, stream_);
  for (size_t round = 0; round < round_total; round++) {
    const auto empty_front_num = static_cast<size_t>(powf(2, round));
    if (0 == round % 2) {
      // even round : from even to odd
      if (auto ret = cudaMemcpyAsync(dev_ptr_odd, dev_ptr_even, sizeof(ull) * empty_front_num, cudaMemcpyDeviceToDevice, stream_)) {
        cout << "cuda Error return code : " << ret << endl;
        return;
      }

      KoggeStoneScan<<<(nums.size() - empty_front_num + kBlockSize - 1) / kBlockSize, kBlockSize, 0, stream_>>>(dev_ptr_odd, dev_ptr_even, nums.size(), round, empty_front_num);
    } else {
      // odd round : from odd to even
      if (auto ret = cudaMemcpyAsync(dev_ptr_even, dev_ptr_odd, sizeof(ull) * empty_front_num, cudaMemcpyDeviceToDevice, stream_)) {
        cout << "cuda Error return code : " << ret << endl;
        return;
      }

      KoggeStoneScan<<<(nums.size() - empty_front_num + kBlockSize - 1) / kBlockSize, kBlockSize, 0, stream_>>>(dev_ptr_even, dev_ptr_odd, nums.size(), round, empty_front_num);
    }
  }

  // timer settings /////////
  cudaEventRecord(stop_, stream_);
  cudaEventSynchronize(stop_);
  float elapsed_ms = 0.0f;
  cudaEventElapsedTime(&elapsed_ms, start_, stop_);
  cout << "KoggeStoneScan : " << elapsed_ms << " ms" << endl;
  ///////////////////////////

  // copy D2H
  auto res_ptr = round_total % 2 ? dev_ptr_odd : dev_ptr_even;
  if (auto ret = cudaMemcpyAsync(nums.data(), res_ptr, buff_size, cudaMemcpyDeviceToHost, stream_)) {
    cout << "cuda Error return code : " << ret << endl;
  }

  // dealloc
  cudaStreamSynchronize(stream_);
  cudaFree(dev_ptr_even);
  cudaFree(dev_ptr_odd);
}

void TestBed::BlellockScan_Entry(vector<ull>& nums) {

}
