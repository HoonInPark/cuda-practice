#include <vector>
#include <cuda_runtime.h>

using namespace std;

void MakeIncrementalNums(vector<int> &Nums, int maxNum);

void KoggeStoneScan(vector<int> &Nums);
__global__ void KoggeStoneScan_Entry();
__device__ void KoggeStoneScan_SingleRound();
