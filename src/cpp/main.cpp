#include "module/prefix-sum.cuh"

constexpr int kMax = 1024;

int main() {
  vector<int> nums;
  MakeIncrementalNums(nums, kMax);

  KoggeStoneScan_Entry(nums);

}
