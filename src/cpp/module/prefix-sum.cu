#include "prefix-sum.cuh"

#include <iostream>
#include <ostream>

constexpr size_t kWarpNum = 32;

void MakeIncrementalNums(vector<int> &Nums, int maxNum) {
  Nums.reserve(maxNum);
  for (int i = 1; i < maxNum + 1; i++) {
    Nums.push_back(i);
  }
}

void KoggeStoneScan(vector<int> &Nums) {
  // allocate vram block with device pointer and its size
  int* devPtr;
  const size_t blockSize = sizeof(int) * Nums.size();
  cudaMalloc(&devPtr, blockSize);

  // copy
  auto ret = cudaMemcpy(devPtr, Nums.data(), blockSize, cudaMemcpyHostToDevice);
  if (ret) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */

  auto gridNum = Nums.size() / kWarpNum + 1;
  KoggeStoneScan_Entry<<<gridNum, kWarpNum>>>();

  // dealloc
  cudaFree(devPtr);
}

__global__ void KoggeStoneScan_Entry() {

}

__device__ void KoggeStoneScan_SingleRound() {

}

