#include "module/prefix-sum.cuh"

constexpr int kMax = 64;

int main() {
  vector<int> nums;
  MakeIncrementalNums(nums, kMax);

  KoggeStoneScan_Entry(nums);

}
