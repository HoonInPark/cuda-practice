#include "prefix-sum.cuh"

void MakeIncrementalNums(vector<int> &Nums, int maxNum) {
  Nums.resize(maxNum);
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
  cudaMemcpy(devPtr, Nums.data(), blockSize, cudaMemcpyHostToDevice);

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */



  // dealloc
  cudaFree(devPtr);
}
