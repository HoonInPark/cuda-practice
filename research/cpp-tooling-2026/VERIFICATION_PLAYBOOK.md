# ROS 2 / C++ 검증 플레이북 (2026-09) — sw_camera_driver 류 패키지용

- 대상: ROS 2 C++ 노드(카메라 드라이버, 폴리싱 제어/콜백)를 다듬는 팀. 배경·근거는 [REPORT.md](./REPORT.md) §4–§5, §7.
- 전제: Ubuntu 26.04 + Lyrical(GCC 15.2, `clang-tidy-21`, `cppcheck` 2.19). Jazzy/24.04면 도구 버전만 낮고 명령은 동일. 최신 검사는 컨테이너(LLVM 23, Cppcheck 2.21)에서.
- 아래 예시는 `PKG=sw_camera_driver`, 워크스페이스 루트(`src/`, `build/`, `install/`)에서 실행.
- 빌드 속도 도구(ccache/mold)는 범위 밖: 필요하면 `--mixin ccache mold` 한 줄.

## 0. 준비 (1회)

```bash
sudo apt install clang clang-tidy libclang-rt-21-dev cppcheck rt-tests   # clang-tidy → run-clang-tidy, clang-tidy-diff-21.py, RTSan 런타임 포함
colcon mixin add default https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && colcon mixin update default
printf 'build:\n  mixin: [compile-commands]\n' > ~/.colcon/defaults.yaml   # 모든 빌드에서 compile_commands.json 생성
```

## 1. 로컬 1인 검증 체크리스트

### 1.1 빌드 전 (커밋 전)
- [ ] 의존성 선언 누락: `rosdep install --from-paths src --ignore-src -y` 가 추가 설치 없이 끝난다.
- [ ] 포맷: `git diff --name-only origin/main -- '*.cpp' '*.hpp' | xargs -r clang-format --dry-run --Werror`
- [ ] 콜백 코드 self-review: 콜백 안에 `new`/`std::vector::resize`/`RCLCPP_*`/mutex 추가했는가 → §3 규칙 적용 대상인지 결정.

### 1.2 빌드 + 정적 분석
```bash
colcon build --packages-up-to "$PKG" --mixin compile-commands rel-with-deb-info \
  --event-handlers console_cohesion+ 2>&1 | tee /tmp/build.log
rg -c ' warning: ' /tmp/build.log || echo "0 warnings"          # 목표: 0. 기존 baseline 대비 증가 금지

run-clang-tidy -p "build/$PKG" -quiet -j"$(nproc)" -source-filter ".*/src/$PKG/.*" | tee /tmp/tidy.log
# 종료코드≠0 == .clang-tidy의 WarningsAsErrors 매치. --fix는 로컬에서만: run-clang-tidy ... -fix 후 diff 리뷰

mkdir -p /tmp/cppcheck-"$PKG"
cppcheck --project="build/$PKG/compile_commands.json" --file-filter="src/$PKG/**" \
  --enable=warning,performance,portability --inline-suppr --suppress=missingIncludeSystem \
  --cppcheck-build-dir=/tmp/cppcheck-"$PKG" -j"$(nproc)" --error-exitcode=2   # cppcheck ≤2.17은 ** 미지원 → "src/$PKG/*"

colcon test --packages-select "$PKG" --mixin linters-only && colcon test-result --verbose   # ament_lint_auto 계열
```
- [ ] 컴파일 경고 0(또는 baseline 동일) · clang-tidy exit 0 · cppcheck exit 0 · linters 통과.

### 1.3 빌드 후 (런타임)
```bash
# 유닛/통합 테스트를 ASan+UBSan으로 (별도 build/install base, 의존 패키지는 기본 install에서 source)
SAN="-fsanitize=address,undefined -fno-omit-frame-pointer"
colcon build --packages-select "$PKG" --build-base build-asan --install-base install-asan \
  --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS="$SAN" \
  -DCMAKE_EXE_LINKER_FLAGS="$SAN" -DCMAKE_SHARED_LINKER_FLAGS="$SAN"
ASAN_OPTIONS=detect_leaks=0 UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
  colcon test --packages-select "$PKG" --build-base build-asan --install-base install-asan --event-handlers console_cohesion+
colcon test-result --test-result-base build-asan --verbose
# 실기/재생(ros2 bag play) 구동 후 토픽 품질
ros2 topic hz /camera/image_raw --window 300      # 목표 fps ± 허용 jitter, std dev·max 확인
ros2 topic delay /camera/image_raw                # header.stamp 기준 파이프라인 지연
pidstat -r -p "$(pgrep -f camera_node)" 5         # 10분 관찰: RSS 단조 증가 없음 (sysstat)
```
- [ ] sanitizer 리포트 0 · fps/지연이 요구치 이내 · RSS 안정. LSan은 rmw 노이즈 정리 후 `detect_leaks=1`+suppressions로 승격.

## 2. CI 게이트 추천

| Job | 트리거 | 도구 | 실패 조건 |
|---|---|---|---|
| build | PR | GCC 15 + 선별 `-Werror=` (§4 P0 스니펫) | 컴파일 에러, 지정 경고 1건 |
| clang-tidy | PR | `run-clang-tidy` + `.clang-tidy` | `WarningsAsErrors` 매치 1건 (exit≠0). 그 외 경고는 SARIF 주석만 |
| cppcheck | PR | `--enable=warning,performance,portability --error-exitcode=2` | 보고 1건. `style`은 게이트에 넣지 않음 |
| lint | PR | `colcon test --mixin linters-only` (ament_lint_auto) | 테스트 실패 |
| asan-ubsan | PR(<10분) 아니면 nightly | §1.3 명령 | 테스트 실패 또는 sanitizer 리포트 (`halt_on_error=1`) |
| tsan | nightly | `--mixin tsan` + 드라이버 스레드 테스트 | 새 race (rmw 노이즈는 `TSAN_OPTIONS=suppressions=`) |
| rtsan | nightly | §3 Clang 빌드 | 억제 파일 외 unique 위반 1건 |
| sarif-latest | nightly | LLVM 23 + Cppcheck 2.21 컨테이너 | 게이트 아님. 업로드만 → 새 검사 미리보기 |

### 2.1 `.clang-tidy` (저장소 루트, LLVM 21/23 공용)
```yaml
# hicpp-* 금지: LLVM 23에서 hicpp 모듈 삭제. glob은 아무것도 매치하지 않고 "조용히" 통과 → 커버리지 구멍.
Checks: >
  -*, bugprone-*, -bugprone-easily-swappable-parameters, -bugprone-narrowing-conversions,
  -bugprone-implicit-widening-of-multiplication-result,
  clang-analyzer-*, -clang-analyzer-optin.performance.Padding, concurrency-*, performance-*, -performance-enum-size, portability-*,
  cppcoreguidelines-pro-type-member-init, cppcoreguidelines-slicing, cppcoreguidelines-virtual-class-destructor,
  misc-*, -misc-include-cleaner, -misc-non-private-member-variables-in-classes, -misc-no-recursion, -misc-const-correctness,
  modernize-*, -modernize-use-trailing-return-type, -modernize-avoid-c-arrays, -modernize-use-nodiscard,
  readability-container-size-empty, readability-misleading-indentation, readability-redundant-*,
  readability-delete-null-pointer, readability-static-accessed-through-instance
WarningsAsErrors: >
  bugprone-use-after-move, bugprone-dangling-handle, bugprone-infinite-loop, bugprone-unhandled-self-assignment,
  bugprone-undelegated-constructor, bugprone-virtual-near-miss, bugprone-sizeof-expression,
  clang-analyzer-core.*, clang-analyzer-cplusplus.*, clang-analyzer-unix.*,
  cppcoreguidelines-pro-type-member-init, cppcoreguidelines-slicing, cppcoreguidelines-virtual-class-destructor,
  performance-move-const-arg, performance-unnecessary-value-param, performance-for-range-copy,
  modernize-use-override, modernize-use-nullptr
HeaderFilterRegex: '.*/src/.*'   # 워크스페이스 src/ 아래 헤더만. /opt/ros·시스템 헤더 제외
FormatStyle: file
```
- 마이그레이션: `rg -n 'hicpp-' -g .clang-tidy .` 로 잔존 확인 → 치환 후 `clang-tidy --verify-config --config-file=.clang-tidy` 를 21과 23 양쪽에서 실행(0 warning). 개별 이름은 버전마다 다를 수 있으니 가능하면 `bugprone-*`식 glob으로 켠다.
- `hicpp-*` → 대체 (LLVM 23 릴리스 노트 표 요약, hicpp 고유 검사 포함): `signed-bitwise`→`bugprone-signed-bitwise`, `exception-baseclass`→`bugprone-std-exception-baseclass`, `multiway-paths-covered`→`bugprone-unhandled-code-paths`+`readability-trivial-switch`, `no-assembler`→`portability-no-assembler`, `ignored-remove-result`→`bugprone-unused-return-value`, `invalid-access-moved`→`bugprone-use-after-move`, `member-init`→`cppcoreguidelines-pro-type-member-init`, `special-member-functions`→`cppcoreguidelines-special-member-functions`, `vararg`→`cppcoreguidelines-pro-type-vararg`, `no-malloc`/`avoid-goto`→`cppcoreguidelines-*`, `use-*`/`avoid-c-arrays`/`deprecated-headers`→`modernize-*`, `noexcept-move`→`performance-noexcept-move-constructor`, `new-delete-operators`→`misc-new-delete-overloads`. 전체 30개 표: REPORT [S43].
- 새 코드만 게이트(레거시 경고가 많을 때): `git diff -U0 origin/main...HEAD -- 'src/*' | clang-tidy-diff-21.py -p1 -path "build/$PKG" -j"$(nproc)"` — 전체 파일을 분석하고 보고만 변경 라인으로 제한(시간 절약 없음).

### 2.2 SARIF 수집 (PR 주석용, GitHub code scanning)
```bash
set -o pipefail; mkdir -p sarif
run-clang-tidy -p "build/$PKG" -quiet -j"$(nproc)" -source-filter ".*/src/$PKG/.*" \
  | tee tidy.log | clang-tidy-sarif > sarif/clang-tidy.sarif           # clang-tidy 23까지 네이티브 SARIF 없음(변환기 사용). exit≠0 유지
cppcheck --project="build/$PKG/compile_commands.json" --file-filter="src/$PKG/**" \
  --enable=warning,performance,portability --inline-suppr --suppress=missingIncludeSystem \
  -j"$(nproc)" --error-exitcode=2 --output-format=sarif 2> sarif/cppcheck.sarif   # SARIF는 stderr로 나옴
# GCC(선택): --cmake-args -DCMAKE_CXX_FLAGS=-fdiagnostics-add-output=sarif → build/$PKG/<TU>.sarif (TU별 파일, 동명 충돌 가능).
#   GCC 게이트는 -Werror= 로 하고 SARIF는 대시보드용. GCC 16은 JSON 포맷 삭제 → SARIF만.
```
```yaml
- uses: github/codeql-action/upload-sarif@v4
  with: { sarif_file: sarif/, category: cpp-static-analysis }   # permissions: security-events: write
```
- nightly 컨테이너에서는 `cppcheck --check-level=exhaustive`, LLVM 23 신규 검사(`bugprone-assignment-in-selection-statement`, `performance-use-std-move`, `modernize-use-std-bit`) 추가 후 노이즈 확인 → 다음 스프린트 PR 게이트로 승격.

## 3. 실시간/카메라 콜백: RTSan · PREEMPT_RT

### 3.1 RTSan을 켜는 시점
- 켠다: (a) 주기 제어 루프(폴리싱 힘/위치 제어, ros2_control update ≥ 250 Hz), (b) 프레임 드랍·지터가 품질 지표인 카메라 경로의 **우리가 소유한 처리 함수**, (c) "콜백 안 할당·락·로그 금지"를 규약으로 정한 함수.
- 안 켠다: 초기화/종료 코드, OpenCV 할당이 본질인 인식 파이프라인, 테스트 코드, GCC 전용 빌드(RTSan은 Clang 20+ 전용).
- 어노테이션 위치: rclcpp 구독 콜백·SDK 콜백 진입점이 아니라 그 안의 내부 함수. 진입점은 executor/SDK가 할당·락을 하므로 경계로 둔다.
```cpp
void CameraNode::onFrame(const Frame& f) {                       // SDK/rclcpp 소유 진입점: 경계(어노테이션 없음)
  processFrame(f, out_buf_.data()); publishPrepared();           // publish는 경계 밖(락/할당 허용)
}
void CameraNode::processFrame(const Frame& f, uint8_t* out) noexcept [[clang::nonblocking]] {
  // 사전 할당 버퍼에 변환/제어 계산만. new, vector::resize, RCLCPP_*, mutex → RTSan이 즉시 보고
}
```
```bash
RT="-fsanitize=realtime -fno-omit-frame-pointer"
colcon build --packages-select "$PKG" --build-base build-rtsan --install-base install-rtsan --mixin clang \
  --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS="$RT -Wfunction-effects" \
  -DCMAKE_EXE_LINKER_FLAGS="$RT" -DCMAKE_SHARED_LINKER_FLAGS="$RT"
RTSAN_OPTIONS=halt_on_error=false:print_stats_on_exit=true:suppressions="$PWD/src/$PKG/rtsan.supp" \
  ros2 run "$PKG" camera_node   # 컴포넌트가 아닌 standalone 실행파일로. 프레임은 실기 또는 ros2 bag play로 주입
# rtsan.supp 예(임시 억제):  call-stack-contains:Pylon::    call-stack-contains:rclcpp::Publisher
```
- `-Wfunction-effects`(컴파일타임 분석)는 미어노테이션 호출마다 경고 → RT 코어 TU에만, 절대 `-Werror` 금지. `nonblocking` 함수는 `noexcept`도 붙인다(`-Wperf-constraint-implies-noexcept`).

### 3.2 카메라/제어 콜백에서 흔한 보고와 처리
| 보고 | 판단 | 처리 |
|---|---|---|
| `publish()`/intra-process/rmw 내부 `malloc`·`pthread_mutex_lock` | 실제 할당·락. 우리가 못 고침 | 경계를 publish 바깥으로. loaned message + `__rtsan::ScopedDisabler`는 최후 수단 |
| `RCLCPP_INFO` 등 로깅 | 진양성(RT 경로 로깅 금지) | 콜백 밖 스레드/`RCLCPP_*_THROTTLE`로 이동 |
| `cv::Mat` 생성, `cv_bridge::toCvCopy`, `vector::resize`, `std::function` 대입 | 진양성 | 프리할당, `cv::Mat(rows, cols, type, external_ptr)`, 템플릿 람다/`function_ref` |
| 벤더 SDK 내부(pylon/Spinnaker/RealSense…) | 못 고침 | `call-stack-contains:<SDK 네임스페이스>` 억제, SDK 콜백은 경계 |
| Eigen 동적 크기 행렬 | 진양성 | 고정 크기 `Eigen::Matrix<double,6,1>` (inline이라 nonblocking 추론됨) |
| 컴포넌트 컨테이너에서 `Interceptors are not working` abort | dlopen으로 늦게 로드 | RTSan 빌드는 standalone 실행파일 또는 컨테이너도 같은 빌드로 |
| 첫 호출 지연·page fault·캐시 미스 | RTSan 미탐(static local만 컴파일타임 경고) | warm-up 후 측정, `mlockall`, 3.3의 cyclictest |
| ASan/TSan과 동시 사용 | 불가 | 별도 build base (§1.3, tsan mixin) |

RTSan 클린 ≠ 마감 보장. 최종 판정은 항상 `ros2 topic hz`의 std dev/max와 3.3의 지연 측정으로.

### 3.3 Ubuntu PREEMPT_RT를 켜는 시점
- 켠다: 제어 PC(ros2_control/EtherCAT/힘 제어, 마감 미스 = 가공 품질 결함). 26.04에서 무료: `sudo apt install ubuntu-realtime && sudo reboot`, 확인 `uname -v | grep PREEMPT_RT`.
- 안 켠다: 개발 노트북, CI 러너, 30–60 fps에 1–2 프레임 버퍼면 충분한 카메라 PC, GPU 인식 노드 박스(NVIDIA 드라이버의 RT 커널 지원을 먼저 확인).
- 커널만 바꾸면 효과 없음. 같이 할 것: RT 스레드 `SCHED_FIFO`(`chrt -f 80`), `mlockall`, `/etc/security/limits.d/`에 `rtprio`/`memlock`, `isolcpus=`/`nohz_full=`/`rcu_nocbs=`로 코어 격리, NIC/USB IRQ는 비RT 코어로.
- 측정(generic 커널 전/후 비교): `sudo cyclictest -m -Sp90 -i1000 -h200 -D 10m -q` → max latency가 제어 주기의 10% 이내(1 kHz면 100 µs). 카메라 경로는 `ros2 topic hz --window 1000`의 max 간격으로 판정.

## 4. 도입 우선순위

### P0 — 지금, 시스템 패키지만으로 (sw_camera_driver 류: 노드 1–2개 + SDK 래퍼 + 테스트 소수)
1. 패키지 CMake에 경고 세트 + 개발 빌드 하드닝:
```cmake
target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic -Wshadow
  -Werror=return-type -Werror=uninitialized -Werror=switch -Werror=format -Werror=reorder
  -Werror=delete-non-virtual-dtor -Werror=overloaded-virtual -Werror=unused-result -Werror=array-bounds)
target_compile_definitions(${PROJECT_NAME} PRIVATE $<$<CONFIG:Debug,RelWithDebInfo>:_GLIBCXX_ASSERTIONS>)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)   # mixin 없이도 ament_clang_tidy가 compile_commands.json을 찾도록
```
2. §2.1 `.clang-tidy` 를 저장소 루트에, `package.xml`에 `<test_depend>ament_cmake_clang_tidy</test_depend>` 추가(`ament_lint_common`에 포함되지 않음) → `ament_lint_auto_find_test_dependencies()`가 `colcon test`에서 실행.
3. PR CI 4종: build(-Werror=) · clang-tidy · cppcheck(warning) · lint. 실패 기준은 §2 표.
4. `~/.colcon/defaults.yaml`의 `compile-commands` mixin 팀 표준화, §1 체크리스트를 PR 템플릿 체크박스로.
5. ASan+UBSan 테스트: 10분 이내면 PR, 아니면 nightly.

### P1 — P0 노이즈 정리 후
6. TSan nightly(드라이버 스레드 ↔ executor 공유 버퍼), LSan 억제 목록 정리 후 `detect_leaks=1`.
7. RTSan nightly: `processFrame`/제어 step 한 함수부터 `[[clang::nonblocking]]`, `rtsan.supp` 관리.
8. SARIF 업로드(clang-tidy-sarif, cppcheck) → PR 인라인 주석.
9. LLVM 23 + Cppcheck 2.21 컨테이너에서 신규 검사·`--check-level=exhaustive` 미리보기, `--verify-config` 양쪽 실행.
10. 제어 PC PREEMPT_RT 브링업 + cyclictest 전/후 기록.

### P2 — 관찰
SonarQube CTU/Coverity nightly, clang-tidy 네이티브 SARIF(LLVM 24 예정), GCC 16 컨테이너로 gnu++20 기본·새 경고 미리보기.

## 5. 하지 말 것
- ROS 패키지에 C++20 modules / `import std` — CMake 게이트 유지, 배포판 std 모듈 없음, rosidl/ament/compile_commands 도구가 헤더 전제.
- C++26 contracts(`-fcontracts`)·reflection을 프로덕션에 — GCC 16 실험 기능, Clang 미지원, ISO 출판 전 세만틱 변동 가능.
- `.clang-tidy`에 `hicpp-*` 잔존 — 23에서 조용히 무효. `-checks=*`/`--warnings-as-errors=*` 전체를 게이트로 — 노이즈로 결국 꺼짐. CI에서 `-fix`.
- GCC `-fdiagnostics-format=json`(16에서 삭제) → SARIF. GCC `-fanalyzer`를 C++ 게이트로 — 프로덕션 C++엔 아직 부적합.
- `_GLIBCXX_DEBUG`를 ROS/OpenCV 링크 바이너리에 — ABI 깨짐. `_GLIBCXX_ASSERTIONS`만.
- `[[clang::nonblocking]]`을 rclcpp 콜백 시그니처·노드 전체에 — executor/rmw 할당으로 보고 폭주. 내부 함수에만.
- 비계측 `component_container`에 RTSan 컴포넌트 로드, RTSan+ASan/TSan 동일 빌드.
- 워크스페이스 통합 `build/compile_commands.json`에 필터 없이 cppcheck — rosidl 생성 코드·서드파티까지 분석. 패키지 `build/$PKG/` + `--file-filter`.
- 워크스페이스 전체 `-Werror` — GCC 15→16(gnu++20 기본, 새 경고)에서 빌드 붕괴. 선별 `-Werror=` 목록만.
- 배포 바이너리 `-march=native` → `-march=x86-64-v3`.
- 개발 노트북/CI 러너에 PREEMPT_RT, GPU 노드의 RT 커널 전환을 드라이버 확인 없이.
- apt OpenCV/Eigen과 vcpkg/Conan 사본을 같은 프로세스에 — ODR/ABI 충돌.
