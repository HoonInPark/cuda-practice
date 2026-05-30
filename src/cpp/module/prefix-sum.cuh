#include <cuda_runtime.h>
#include <vector>

using namespace std;

void MakeIncrementalNums(vector<int>& nums, int max_num);
void KoggeStoneScan_Entry(vector<int>& nums);

__global__ void KoggeStoneScan(int* dst, int* src, size_t total_size, size_t round, size_t start_offset);
