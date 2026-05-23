#include "module/prefix-sum.cuh"

constexpr int kMax = 1024;

int main() {
  vector<int> Nums;
  MakeIncrementalNums(Nums, kMax);

  KoggeStoneScan_Entry(Nums);

}
