#include <vector>
#include <driver_types.h>

using namespace std;

typedef unsigned long long ull;
typedef struct curandStatePhilox4_32_10 curandStatePhilox4_32_10_t;

__global__ void InitCurand(curandStatePhilox4_32_10_t* states, ull seed);
__global__ void GenerateRandNums(curandStatePhilox4_32_10_t* states, ull* out, ull cnt, ull max_num);
__global__ void KoggeStoneScan(ull* dst, ull* src, size_t total_size, size_t round, size_t start_offset);
__global__ void CheckAdjacentDiff(ull* src, ull* res);

class TestBed {
  public:
  TestBed();
  ~TestBed();

  void MakeRandNums_CUDA(vector<ull>& nums, ull cnt, ull max_num);
  void KoggeStoneScan_CUDA(vector<ull>& nums);
  void BlellockScan_CUDA(vector<ull>& nums);

  bool VerifyResult_CUDA(const vector<ull>& nums_src, const vector<ull>& nums_res);

  private:
  cudaStream_t stream_{};
  cudaEvent_t start_{}, stop_{};
};

// TODO 1 : add verifier for result vector
// TODO 2 : make MakeIncrementalNums func output as resident gpu buffer
// TODO 3 : apply tracy client for cuda profiling
// TODO 4 : apply shared mem in Kogge-Stone Scan

