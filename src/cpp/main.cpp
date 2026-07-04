#include <cstring>
#include "module/prefix-sum.cuh"

constexpr ull kMax = 1024 * 1024;

int main() {
  vector<ull> nums;

  TestBed tb;

  tb.MakeRandNums_CUDA(nums, kMax, kMax);

  vector<ull> nums_src;
  nums_src.reserve(nums.size());
  memcpy(nums_src.data(), nums.data(), nums.size() * sizeof(ull));

  tb.KoggeStoneScan_CUDA(nums);

  tb.VerifyResult_CUDA(nums_src, nums);

  return 0;
}
