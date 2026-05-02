#include <vector>
#include <cuda_runtime.h>

using namespace std;

void MakeIncrementalNums(vector<int> &Nums, int maxNum);

void KoggeStoneScan(vector<int> &Nums);
__global__ void KoggeStoneScanEntry();
__device__ void KoggeStoneScan();
