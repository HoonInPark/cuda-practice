#include "prefix-sum.cuh"

#include <cmath>
#include <iostream>
#include <ostream>

constexpr size_t kBlockSize = 128;

void MakeIncrementalNums(vector<int> &Nums, int maxNum) {
  Nums.reserve(maxNum);
  for (int i = 1; i < maxNum + 1; i++) {
    Nums.push_back(i);
  }
}

void KoggeStoneScan_Entry(vector<int> &Nums) {
  // allocate vram with device pointer and its size
  int *devPtr;
  const size_t devMemSize = sizeof(int) * Nums.size();
  cudaMalloc(&devPtr, devMemSize);

  /**
   * u can see stream use cases in the post below :
   * https://hayunjong83.tistory.com/28
   */
  cudaStream_t stream;
  cudaStreamCreate(&stream);

  // copy H2D
  if (auto ret = cudaMemcpyAsync(devPtr, Nums.data(), devMemSize, cudaMemcpyHostToDevice, stream)) {
    cout << "cuda Error return code : " << ret << endl;
    return;
  }

  /**
   * for example, you can call kernel like
   * kernel<<<10, 256>>>(...);
   * and there are 10 blocks and each block has 256 threads
   */
  auto roundNum = static_cast<size_t>(log2(Nums.size())) + 1;

  for (size_t i = 0; i < roundNum; i++) {

  }

  // copy D2H
  if (auto ret = cudaMemcpyAsync(Nums.data(), devPtr, devMemSize, cudaMemcpyDeviceToHost, stream)) {
    cout << "cuda Error return code : " << ret << endl;
  }

  // dealloc
  cudaDeviceSynchronize();
  cudaFree(devPtr);
}

__global__ void KoggeStoneScan(int *devPtr) {

}
