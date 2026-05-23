#include <vector>
#include <cuda_runtime.h>

using namespace std;

void MakeIncrementalNums(vector<int> &Nums, int maxNum);

void KoggeStoneScan_Entry(vector<int> &Nums);

__global__ void KoggeStoneScan(int* devPtr);

