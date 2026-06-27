#include <cuda_runtime.h>
#include <vector>

using namespace std;

typedef unsigned long long ull;

constexpr size_t kBlockSize = 256;

// TODO 1 : add verifier for result vector
// TODO 2 : make MakeIncrementalNums func output as resident gpu buffer
// TODO 4 : apply tracy client for cuda profiling
// TODO 3 : apply shared mem in Kogge-Stone Scan


class TestBed {
public:
  TestBed();
  ~TestBed();

  void MakeIncrementalNums(vector<ull>& nums, ull max_num);
  void KoggeStoneScan_Entry(vector<ull>& nums);
  void BlellockScan_Entry(vector<ull>& nums);

  bool VerifyResult();

private:
  cudaStream_t stream_{};
  cudaEvent_t start_{}, stop_{};
};

