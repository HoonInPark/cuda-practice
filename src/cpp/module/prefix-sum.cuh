#include <cuda_runtime.h>
#include <vector>

using namespace std;

typedef unsigned long long ull;

constexpr size_t kBlockSize = 256;

class TestBed {
public:
  TestBed();
  ~TestBed();

  void MakeIncrementalNums(vector<ull>& nums, ull max_num);
  void KoggeStoneScan_Entry(vector<ull>& nums);
  void BlellockScan_Entry(vector<ull>& nums);

private:
  cudaStream_t stream_;
  cudaEvent_t start_, stop_;
};

