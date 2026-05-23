#include "prefix-sum.cuh"

#include <cmath>
#include <iostream>
#include <ostream>

constexpr size_t kBlockNum = 128;

void MakeIncrementalNums(vector<int> &Nums, int maxNum) {
  Nums.reserve(maxNum);
  for (int i = 1; i < maxNum + 1; i++) {
    Nums.push_back(i);
  }
}

void KoggeStoneScan_Entry(vector<int> &Nums) {
  // allocate vram block with device pointer and its size
  int *devPtr;
  const size_t blockSize = sizeof(int) * Nums.size();
  cudaMalloc(&devPtr, blockSize);

  // copy
  auto ret = cudaMemcpyAsync(devPtr, Nums.data(), blockSize, cudaMemcpyHostToDevice);
  if (ret) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */

  /**
   * u can see stream use cases in the post below :
   * https://hayunjong83.tistory.com/28
   *
   */
  cudaStream_t* stream;
  cudaStreamCreate(stream);

  auto gridNum = Nums.size() / kBlockNum + 1;
  auto roundNum = static_cast<size_t>(log2(Nums.size())) + 1;

  for (size_t i = 0; i < roundNum; i++) {
    KoggeStoneScan<<<gridNum, kBlockNum, stream>>>(devPtr);
  }

  // dealloc
  cudaDeviceSynchronize();
  cudaFree(devPtr);
}

__global__ void KoggeStoneScan(int *devPtr) {
  auto idx = blockIdx.x + threadIdx.x;
}
