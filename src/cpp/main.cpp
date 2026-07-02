#include "module/prefix-sum.cuh"

constexpr unsigned long long kMax = 1024 * 1024;

int main() {
  vector<unsigned long long> nums;

  TestBed tb;

  tb.MakeRandNums_Entry(nums, kMax);
  tb.KoggeStoneScan_Entry(nums);

  return 0;
}
