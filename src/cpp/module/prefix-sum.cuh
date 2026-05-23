#include <cuda_runtime.h>
#include <vector>

using namespace std;

void MakeIncrementalNums(vector<int>& nums, int max_num);
void KoggeStoneScan_Entry(vector<int>& nums);

__global__ void KoggeStoneScan(int* dev_ptr, const size_t total_size, const size_t round, const size_t start_offset);
