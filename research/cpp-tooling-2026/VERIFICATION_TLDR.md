# 검증 TL;DR (2026-09) · 상세: [VERIFICATION_PLAYBOOK.md](./VERIFICATION_PLAYBOOK.md) · 배경: [REPORT.md](./REPORT.md)

- **로컬(커밋 전)**: `colcon build --mixin compile-commands rel-with-deb-info` 경고 0 → `run-clang-tidy -p build/$PKG -source-filter ".*/src/$PKG/.*"` exit 0 → `cppcheck --project=build/$PKG/compile_commands.json --file-filter="src/$PKG/**" --enable=warning,performance,portability --error-exitcode=2` → `colcon test --mixin linters-only`.
- **로컬(빌드 후)**: 별도 build base로 ASan+UBSan 테스트(`detect_leaks=0`부터), `ros2 topic hz/delay`로 fps·지연, `pidstat -r`로 RSS 안정.
- **PR CI 게이트 4종**: build(선별 `-Werror=`) · clang-tidy(`WarningsAsErrors` 매치 시 실패, 나머지는 SARIF 주석) · cppcheck(warning/performance/portability 1건 실패, `style` 제외) · ament lint.
- **nightly**: ASan/UBSan(PR에 못 넣으면) · TSan · RTSan · LLVM 23/Cppcheck 2.21 컨테이너 SARIF 미리보기.
- **`.clang-tidy`**: `hicpp-*` 제거(LLVM 23에서 모듈 삭제, glob이 조용히 무효) → `bugprone-*`/`cppcoreguidelines-*`/`modernize-*` 대체, `clang-tidy --verify-config`로 21·23 양쪽 확인.
- **SARIF**: clang-tidy는 `clang-tidy-sarif` 변환(네이티브 없음), cppcheck `--output-format=sarif 2>`, GCC `-fdiagnostics-add-output=sarif`(JSON 포맷은 GCC 16 삭제) → `upload-sarif@v4`.
- **RTSan**: Clang 빌드 `-fsanitize=realtime`, `[[clang::nonblocking]]`은 rclcpp/SDK 콜백 진입점이 아닌 내부 처리 함수에. publish/로깅/`cv::Mat` 할당/벤더 SDK 보고는 경계 이동·프리할당·`rtsan.supp`로. standalone 실행파일로 실행.
- **PREEMPT_RT**: 제어 PC만(`apt install ubuntu-realtime`, 26.04 무료) + `SCHED_FIFO`/`mlockall`/코어 격리, `cyclictest` 전/후 비교. 노트북·CI·GPU 박스는 아님.
- **P0**: CMake 경고 세트+`_GLIBCXX_ASSERTIONS`, `.clang-tidy`+`ament_cmake_clang_tidy` test_depend, PR CI 4종, `compile-commands` mixin 표준화, ASan/UBSan 테스트. **P1**: TSan/RTSan nightly, SARIF 업로드, 최신 도구 컨테이너, RT 커널 브링업.
- **하지 말 것**: ROS 패키지에 modules/`import std`, C++26 contracts/reflection 프로덕션, `hicpp-*` 잔존, `_GLIBCXX_DEBUG`, 전체 `-Werror`/`-checks=*` 게이트, 콜백 시그니처에 `nonblocking`, RTSan+ASan 동일 빌드, 필터 없는 워크스페이스 cppcheck, `-march=native`.
