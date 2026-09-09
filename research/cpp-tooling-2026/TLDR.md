# TL;DR — C++ Tooling 2026 for ROS 2 Robotics (2026-09-09) · 상세: [REPORT.md](./REPORT.md)

- **C++26 확정(2026-03-28), ISO 출판 대기** — contracts/reflection/std::execution/hardened stdlib 포함. | C++26 technically final; DIS ballot pending.
- **GCC 16.2 (08-07)**: C++26 reflection·contracts 실험 지원, 기본 표준이 gnu++20으로 변경, JSON 진단 제거(SARIF만). | GCC leads C++26; default is now gnu++20.
- **Clang 23.1 (08-25)**: reflection/contracts 없음, 22부터 reduced BMI 기본. Ubuntu 26.04는 LLVM 21 탑재. | Clang lags on C++26 headline features.
- **MSVC 14.50 LTS(~2028-11)/14.51**, 5월·11월 6개월 주기; 14.52에서 C++23 완성·`/std:c++23`. | MSVC now decoupled from the IDE; VS 2022 still ROS Tier 1 on Windows.
- **모듈은 아직 보류**: GCC `-fmodules` 실험, 배포판 std 모듈 없음, CMake 4.4 `import std` 게이트 유지. | Keep modules out of ROS packages.
- **ROS 2 Lyrical LTS (05-22, ~2031)**: Ubuntu 26.04 + GCC 15.2 + CMake 4.2.3, **C++20 최소**, `ament_cmake_ros_core::ament_ros_defaults`로 표준 지정. | New LTS baseline; C++20 minimum.
- **CMake 4.3 (03-17)** CPS 정식·`cmake-instrumentation`·PVS-Studio 속성; **4.4 (07-14)** `cmake_diagnostic()`·presets v12·`--presets-file`·`discover_tests()`·wild 링커 ID; 최신 4.4.3. | Fast Nov/Mar/Jul cadence.
- **CMake 4.0 이후 `cmake_minimum_required(<3.5)` 빌드 실패** — 서드파티 의존성은 `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, 자체 패키지는 3.22+로 상향. | Top breakage on Ubuntu 26.04.
- **Conan 2.32 (08-31)** CMakeConfigDeps(experimental, CPS)·Workspace 정식; **vcpkg 2026.07.29** 2,858 ports; **CPM 0.42.3**. ROS 커뮤니티 신호는 **pixi/RoboStack**. | Use Conan/vcpkg only for isolated vendor SDKs; rosdep/apt stays.
- **clang-tidy 23: `hicpp-*` 모듈 삭제** → `.clang-tidy` 마이그레이션 필수; 네이티브 SARIF 없음(PR 08-27), `clang-tidy-sarif` 변환 사용. | Audit .clang-tidy before LLVM 23.
- **Cppcheck 2.21 (06-04)** `--output-format=sarif`(stderr!), compile_commands include 수정, 저장소 cppcheck-opensource로 이전. | SARIF is the common CI format now (GCC, Cppcheck, CSA).
- **상용**: PVS-Studio 8.00(MISRA C++:2023 진행), Coverity 2026.6(C++26 시작, sccache 자동 인식), SonarQube 2026.1 SCA(Conan/vcpkg)·2026.4 CTU 베타; CodeQL은 GCC 15/Clang 21/VS 2022까지. | Commercial tools track C++26 slowly.
- **RTSan(Clang 20+)**: `-fsanitize=realtime` + `[[clang::nonblocking]]`로 제어 루프·카메라 콜백의 RT 위반 탐지; GCC 미지원. | Build RT packages with Clang nightly.
- **Ubuntu 26.04 PREEMPT_RT(Linux 7.0) 무료** — `apt install ubuntu-realtime`, Pro 불필요. | Real-time kernel no longer gated.
- **링커**: mold 2.42 (08-12) 기본, wild 0.10 (08-04) 관찰; 독립 벤치(04-12) mold 1.5–2.0x, wild 2.5–2.8x vs lld. | Re-benchmark yearly.
- **캐시**: ccache 4.13 (원격 스토리지 헬퍼·디렉터리별 conf), sccache 0.17 클라이언트 모드; colcon mixin으로 `ccache`/`mold`/`compile-commands` 적용. | Cheap wins for colcon builds.
- **향후 6개월**: MSVC 14.52(11월), Kilted EOL(11월), Ubuntu 26.10=GCC 16 기본, CMake 4.5, clang-tidy SARIF, SonarQube CTU GA, C++26 ISO 출판. | Watch list Sep 2026 → Mar 2027.
- **PLAIF형 액션**: GCC 15.2 릴리스 + Clang 21 분석기, `_GLIBCXX_ASSERTIONS` 개발 빌드, `-march=x86-64-v3`, `rosidl::Buffer`로 이미지 zero-copy, 모듈·Bazel·`-fanalyzer` C++는 보류. | See REPORT.md §7.
