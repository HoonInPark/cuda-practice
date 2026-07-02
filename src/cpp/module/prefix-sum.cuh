#include <driver_types.h>
#include <vector>

using namespace std;

typedef unsigned long long ull;

constexpr size_t kBlockSize = 256;

// TODO 1 : add verifier for result vector
// TODO 2 : make MakeIncrementalNums func output as resident gpu buffer
// TODO 3 : apply tracy client for cuda profiling
// TODO 4 : apply shared mem in Kogge-Stone Scan


class TestBed {
public:
  TestBed();
  ~TestBed();

  void MakeRandNums_Entry(vector<ull>& nums, ull max_num);
  void KoggeStoneScan_Entry(vector<ull>& nums);
  void BlellockScan_Entry(vector<ull>& nums);

  bool VerifyResult(const vector<ull>& nums_src, const vector<ull>& nums_res);

private:
  cudaStream_t stream_{};
  cudaEvent_t start_{}, stop_{};
};

