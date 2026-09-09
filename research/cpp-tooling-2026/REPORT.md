# C++ Tooling Trends 2026 — Briefing for a ROS 2 / Robotics C++ Shop

- **Prepared:** 2026-09-09 (research agent, web + primary sources)
- **Window:** ~Mar 2025 → Sep 2026. Items older than ~18 months are tagged **[older context]**.
- **Scope bias:** what matters for a robotics shop running ROS 2 C++ nodes (polishing pipelines, camera drivers), real-time-ish Linux, CMake/ament packages.
- **Confidence tags:** **[High]** = primary source (release notes, official docs, announcement); **[Med]** = reputable secondary or partially verified; **[Low]** = single/opinion source, treat as signal only.
- Bracketed `[S#]` markers point to the numbered **Sources** list at the end.

---

## 0. Executive summary (10 bullets)

1. **C++26 is technically done.** WG21 finished C++26 on 2026-03-28 (London/Croydon); the DIS ballot is in progress; ISO publication is pending. Contracts (P2900), reflection (P2996), `std::execution` (P2300) and the hardened standard library (P3471) are in. [High] [S17][S18]
2. **GCC leads C++26 implementation.** GCC 16.1 (2026-04-30) ships experimental reflection (`-freflection`), contracts, expansion statements, erroneous behaviour, `std::simd`, `std::inplace_vector`; GCC 16.2 is the current bug-fix release (2026-08-07). GCC 16 also flips the default dialect to **gnu++20**. Clang 23.1 (2026-08-25) still has **no** reflection or contracts. [High] [S1][S4][S8][S10]
3. **Modules: syntax ready, ecosystem not.** GCC 16 modules are still `-fmodules` experimental with no distro-shipped `std` module artifacts; CMake's `import std` support **remains gated as experimental in 4.4** (the gate was removed for 4.3.0-rc1 and restored after regressions). Do not adopt modules in ROS 2 packages yet. [High] [S1][S25]
4. **ROS 2 Lyrical Luth (LTS, 2026-05-22 → May 2031) sets the baseline:** Ubuntu 26.04 Tier 1 (GCC 15.2, glibc 2.43, CMake 4.2.3, LLVM 21), **C++20 minimum**, Windows Tier 1 is still **VS 2022**. New `ament_cmake_ros_core::ament_ros_defaults` target sets the C/C++ standard for you. [High] [S28][S30][S33]
5. **CMake 4.x cadence is fast (Nov/Mar/Jul):** 4.2 (2025-11-20), 4.3 (2026-03-17: CPS packages non-experimental, `cmake-instrumentation`, `<LANG>_PVS_STUDIO`), 4.4 (2026-07-14: `cmake_diagnostic()`, presets v12 + `--presets-file`, `discover_tests()`, `test_prep/<test>` Ninja targets, wild linker ID). Latest patch 4.4.3 (2026-09-02). [High] [S22][S23][S24]
6. **MSVC decoupled from the IDE:** MSVC Build Tools 14.50 (VS 2026 18.0, 2025-11-11) is an LTS release supported to 2028-11-14; new MSVC ships every May/Nov with 9 months support. C++23 completes in 14.52 (preview), which adds `/std:c++23`. [High] [S13][S14][S15]
7. **Real-time Linux got cheaper:** Ubuntu 26.04's PREEMPT_RT kernel (Linux 7.0) is free in the main archive (`apt install ubuntu-realtime`), no Ubuntu Pro. Pair with Clang's **RealtimeSanitizer** (`-fsanitize=realtime`, `[[clang::nonblocking]]`, Clang 20+) for control loops and camera callbacks. GCC has no RTSan. [High] [S51][S57]
8. **Static analysis is converging on SARIF, except clang-tidy.** GCC 16 removed its JSON diagnostics format (SARIF is the machine-readable path); Cppcheck 2.21 (2026-06-04) has `--output-format=sarif`; clang-tidy still needs a converter (`clang-tidy-sarif`) — a native `-export-sarif` PR was opened 2026-08-27. clang-tidy 23 **removed the `hicpp-*` module**; audit `.clang-tidy` files before upgrading. [High] [S1][S43][S44][S46]
9. **Package managers are mature but orthogonal to ROS:** Conan 2.32.0 (2026-08-31, monthly; `CMakeConfigDeps` experimental, Workspaces graduated 2026-07), vcpkg 2026.07.29 (2,858 ports), CPM.cmake 0.42.3. In ROS 2 the community signal is toward **pixi/RoboStack** as a "co-official" install path (proposal 2026-01-12), not Conan/vcpkg. Use Conan/vcpkg only for isolated non-ROS SDKs. [High/Med] [S39][S40][S41][S42]
10. **Build-speed stack for 2026:** ccache 4.13 (2026-03-05: remote storage helpers, per-directory `ccache.conf`) or sccache 0.17 (2026-07-29: client-side mode), mold 2.42 (2026-08-12) or the Rust-based wild 0.10 (2026-08-04) as linker, colcon mixins for both. Independent April 2026 benchmarks put mold at 1.5–2.0x and wild at 2.5–2.8x lld's speed. [High] [S52][S53][S54][S55][S56]

---

## 1. Compilers

### 1.1 Release status (as of 2026-09-09)

| Toolchain | Current releases | Default `-std` | Notes |
|---|---|---|---|
| **GCC** | 16.2 (2026-08-07), 16.1 (2026-04-30); 15.2 is the Ubuntu 26.04 system compiler; 15.1 released 2025-04-25 [older context] | `gnu++20` (GCC 16), `gnu++17` (GCC 15) | GCC 16: reflection, contracts, expansion statements, EB for uninitialized reads, `-march=znver6`, HTML diagnostics (experimental), JSON diagnostics removed. [High] [S1][S2][S4][S5] |
| **Clang/LLVM** | 23.1.0 (2026-08-25; 23.1.1 scheduled 2026-09-08, biweekly point releases to Dec), 22.1.0 (2026-02-24), 21.1.0 (2025-08-26; Ubuntu 26.04 ships LLVM 21) | `gnu++17` | 22: reduced BMI default for modules, `-gkey-instructions` default at -O>0, UBSan trap reasons in DWARF, `-fsanitize=alloc-token`; 23: partial C++26 (`-std=c++2c`), Zen 6, DTLTO work. [High] [S7][S8][S9][S33] |
| **MSVC** | Build Tools 14.51 (VS 2026 18.6, ~May 2026 per the May/Nov cadence [Med]), 14.50 (VS 2026 18.0, 2025-11-11, **LTS to 2028-11-14**), 14.44 (VS 2022 17.14, 2025-05-13) | `/std:c++14`; use `/std:c++20`, `/std:c++23preview`, `/std:c++latest` | Cadence: new MSVC every May/Nov, 9-month support; LTS every second November. 14.52 preview completes C++23 and adds `/std:c++23` (deprecating `c++23preview`). [High] [S12][S13][S14][S15][S16] |

### 1.2 C++20 / C++23 / C++26 support

- **C++20:** complete in all three for language + library, **except modules**, which remain experimental in GCC (`-fmodules`) and lack an ecosystem (see 1.3). Clang and MSVC named-module support is production-usable for leaf code. [High] [S1][S10]
- **C++23:** GCC labels C++23 "experimental" but the feature table is essentially complete; Clang is "Partial" (a handful of DR/edge items); MSVC has **two remaining features** landing in 14.52 preview, after which `/std:c++23` appears. [High] [S6][S10][S14]
- **C++26 (finalized 2026-03-28, DIS ballot ongoing):** [High] [S17][S18]
  - GCC 16: P2996R13 reflection (`-std=c++26 -freflection`), P2900R14 contracts, P1306R5 expansion statements, P2795R5 erroneous behaviour, `#embed` (GCC 15), library: `std::simd`, `std::inplace_vector`, `std::optional<T&>`, `std::function_ref`/`copyable_function`, `std::indirect`/`polymorphic`, `std::mdspan` extensions, hardened-precondition feature-test macros. [High] [S1][S3][S21]
  - Clang 23: pack indexing, structured-binding packs, expansion statements (partial), `constexpr` structured bindings started in 22; **reflection = No, contracts = No, EB = No** per `cxx_status`. [High] [S7][S10]
  - MSVC: C++26 limited to selected library papers implemented as de-facto DRs; no `/std:c++26preview` switch. [High] [S14]
  - Coverity 2026.6 began incremental C++26 support; CodeQL has no C++26 claim yet. [High] [S49][S50]

### 1.3 Modules readiness

- GCC 16: `-fmodules` (experimental), new `--compile-std-module` builds `std`/`std.compat`; when a `<bits/std.cc>` header unit exists, `#include` of importable std headers is translated to `import`. **No distro ships prebuilt std module artifacts**, so `import std;` fails out of the box on Ubuntu/Fedora today. [High] [S1]; practitioner write-up estimates 12–18 months to real payoff [Low] [S20]
- Clang 22 made **reduced BMI** the default — a behaviour change for build systems that support two-phase compilation. [High] [S7]
- CMake: named modules are supported (3.28+ [older context]); `import std` is still behind `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` (gate UUID `f35a9ac6-…` for 4.4). The 4.3.0-rc1 attempt to drop the gate was reverted "due to broken stdlib distributions and regressions". CMake 4.4 added modules support for `clang-cl` and per-file-set `CXX_SCAN_FOR_MODULES`. [High] [S24][S25]
- clangd 23: caches built module files across invocations, validates module inputs, respects `CompileFlags` edits — but community reports still cite clangd needing a full rebuild to see module edits. [High/Low] [S43]
- Meson 1.12 (2026-08-10) still treats C++ modules as experimental; xmake claims module-scanner rework (weak evidence). [Med/Low] [S38]
- **Verdict for ROS 2:** rosidl-generated headers, `ament_cmake` export/`find_package` flows, and compile_commands-based tooling all assume headers. Keep modules out of ROS packages until CMake drops the `import std` gate and Ubuntu ships std modules.

### 1.4 Flags and performance relevant to ROS 2 nodes

- **Hardened standard library (C++26 P3471 lineage).** libstdc++: `-D_GLIBCXX_ASSERTIONS` (non-ABI-breaking, constant-time checks; GCC 16.1 enables it by default at `-O0`) or GCC's umbrella `-fhardened` (GCC 14+ [older context]: `_FORTIFY_SOURCE=3`, `_GLIBCXX_ASSERTIONS`, `-ftrivial-auto-var-init=zero`, PIE, RELRO, stack protector/clash, CET). libc++: `-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST` (production default). MSVC STL: `_MSVC_STL_HARDENING=1`. Secondary-source overhead estimates: `_GLIBCXX_ASSERTIONS` ~0–6%, `-fhardened` ~1–2%, `_GLIBCXX_DEBUG` 30–50% and ABI-breaking. **Measure on your hot loops** (image pipelines) before enabling in release. [High for mechanisms; Med/Low for overhead numbers] [S21]
- **Debugging optimized builds:** Clang 22 turns on `-gkey-instructions` by default for optimized C/C++ (better stepping), and trapping UBSan (`-fsanitize-trap=undefined`) now records the trap reason in debug info. [High] [S7]
- **Devirtualization:** Clang 22 adds opt-in `-fdevirtualize-speculatively` (relevant for `rclcpp` callback-heavy code, verify gains). [High] [S7]
- **Target ISA:** GCC 16 / LLVM 23 add Zen 6 (`-march=znver6`); for fleets of x86 controllers prefer `-march=x86-64-v3` over `native` for reproducible binaries. [High for compiler support; recommendation is ours] [S1][S8]
- **Diagnostics for CI:** GCC 16 SARIF output now respects the dump directory and captures logical-location nesting; JSON format is gone. Clang: `-fdiagnostics-format=sarif` (crash fixes in 22). [High] [S1][S7]
- **GCC `-fanalyzer` on C++:** GCC 16 makes it "usable on simple C++ examples" but "not likely to be usable on production C++ code in this release". Don't budget for it. [High] [S1]

---

## 2. Build systems

### 2.1 CMake 4.x

| Version | Date | Highlights relevant to us |
|---|---|---|
| 4.0 [older context] | Mar 2025 | Removed compatibility with `cmake_minimum_required(VERSION < 3.5)`; escape hatch `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`. Still the #1 breakage when building old third-party/ROS deps on Ubuntu 26.04 (CMake 4.2.3). [High] [S26] |
| 4.2 | 2025-11-20 | `Visual Studio 18 2026` generator, FASTBuild generator, Emscripten cross-compile, `set/unset(CACHE{})`, `cmake_language(TRACE)`. Latest patch 4.2.7 (2026-06-23). [High] [S22] |
| 4.3 | 2026-03-17 | **CPS import/export no longer experimental** (`find_package()` reads CPS; `install/export(PACKAGE_INFO)`); `cmake-instrumentation(7)` (timing/trace data, Google Trace Event export, CDash); presets schema 11; `cmake --build <dir> --preset`; `<LANG>_PVS_STUDIO` target property (runs `pvs-studio-analyzer` in Makefile/Ninja builds); `CMAKE_VERIFY_PRIVATE_HEADER_SETS`. [High] [S23] |
| 4.4 | 2026-07-14 (4.4.3 on 2026-09-02) | `cmake_diagnostic()` + `cmake-diagnostics(7)` (old `-Wdev` spelling deprecated → `-Wauthor`); presets schema 12, `--presets-file` for cmake/ctest/cpack, `testPassthroughArguments`; `discover_tests()`; Ninja `test_prep/<test>` targets (`CMAKE_TEST_BUILD_DEPENDS`); `SOURCES` file sets with `CXX_SCAN_FOR_MODULES`, `SKIP_LINTING`, `JOB_POOL_COMPILE`; instrumentation `compileTrace` (collects `-ftime-trace` files); `clang-cl` modules; wild linker ID; `execute_process(ENVIRONMENT…)`. [High] [S24] |

- Cadence to plan around: minor every ~4 months (Nov/Mar/Jul), patches weekly-to-monthly. Kitware's apt repo tracks latest; Ubuntu 26.04 pins 4.2.x. [High] [S24][S30]
- **CPS** (Common Package Specification, spec v0.14.x, "pre-release") is Kitware's bet for cross-build-system package descriptions; Conan's `CMakeConfigDeps` already round-trips CPS. Worth emitting CPS alongside `*Config.cmake` from your in-house libraries once you are on CMake ≥4.3 everywhere. [High] [S23][S39]

### 2.2 Ninja

- 1.13.2 (2025-11-20) is current; 1.13.0 (2025-06-18) / 1.13.1 (2025-07-10). No functional churn since; still the default generator to pair with colcon (`--cmake-args -G Ninja` or the `ninja` mixin). CMake 4.4's `test_prep/` targets are Ninja-only. [High] [S27][S24]

### 2.3 ament / colcon interplay (ROS 2 Lyrical)

- **Lyrical Luth**, twelfth ROS 2 release, **LTS until May 2031**, released 2026-05-22. Tier 1: Ubuntu 26.04 amd64/arm64, Windows 11 (**VS 2022**); Tier 2: RHEL 10; Tier 3: Ubuntu 24.04, Debian 13, macOS, OpenEmbedded. Default RMW remains `rmw_fastrtps_cpp` (Fast DDS 3.6.x); `rmw_zenoh_cpp` is Tier 1 (Zenoh 1.8.0). [High] [S28][S30]
- **Minimum language:** C++20 (PMC decision 2026-02-17→27; `rclcpp` switched in Apr 2026), C17, Python 3.12–3.14. Toolchain on Ubuntu 26.04: GCC 15.2, glibc 2.43, CMake 4.2.3, Python 3.14.3, OpenCV 4.10.0, PCL 1.15.1, Qt 6.10.2. [High] [S30][S31][S33]
- **New CMake target:** `find_package(ament_cmake_ros REQUIRED)` + `target_link_libraries(tgt PUBLIC ament_cmake_ros_core::ament_ros_defaults)` sets C/C++ standard via `target_compile_features`. Prefer it over per-package `CMAKE_CXX_STANDARD`. [High] [S29]
- Other Lyrical items that touch C++ build/perf: `EventsCBGExecutor` (10–15% less CPU than single/multi-threaded executors), `rosidl::Buffer<uint8_t>` replacing `std::vector<uint8_t>` for `uint8[]` fields (zero-copy GPU publish/subscribe, Fast DDS only for now), runtime tracing opt-out and LTTng snapshot mode, `class_loader` plugin constructor args, `ament_python_install_package` multiple calls. [High] [S29]
- **colcon:** `colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` produces per-package `compile_commands.json` plus a **workspace-level aggregate** in `build/`. Mixins (`colcon-mixin`) are the sanctioned way to inject `ccache`, `mold`/`lld`, sanitizer and `compile-commands` flags; **mixin composition** (a mixin referencing other mixins) is a GSoC 2026 project with PR `colcon/colcon-mixin#70` in review (Aug 2026), not yet released. [High/Med] [S34][S35]
- **ament_lint 0.20.6** (2026-05-15) for Lyrical: `ament_clang_tidy` fixed `WarningsAsErrors` reporting; `ament_uncrustify` now accepts uncrustify ≥0.78.1 (Ubuntu 26.04 ships 0.78.1, RHEL 10 ships 0.80.1). [High] [S36]
- **CI:** `ros-tooling/action-ros-ci` added Lyrical on 2026-05-07 (`target-ros2-distro: lyrical`, `ros-tooling/setup-ros`); `industrial_ci` lists Lyrical. [High] [S58]
- **Windows friction:** Lyrical Tier 1 is VS 2022 (MSVC 14.44, v143), not VS 2026 — pin the v143 toolset in ROS Windows builds; use 14.5x only for non-ROS tools. [High] [S28][S15]

### 2.4 Bazel / Meson / xmake — community signal check

- **Bazel 9.0 LTS (2026-01-20):** `WORKSPACE` removed entirely (Bzlmod only), C++ rules moved out to `rules_cc`, `--incompatible_autoload_externally` default empty. Bazel 6 deprecated. ROS 2 on Bazel exists via `mvukov/rules_ros2` (~146 stars, Bzlmod-based, patches ROS core repos). **Signal: niche**; only relevant if you already run Bazel monorepos. [High for Bazel; Med for ROS signal] [S37]
- **Meson 1.12.0 (2026-08-10):** active, but C++ modules still experimental; no meaningful ROS 2 presence. [Med] [S38]
- **xmake:** claims C++ module scanner rework in 3.x; no ROS 2 signal. [Low]
- **FASTBuild** got a CMake generator in 4.2 — of interest only for very large Windows builds. [High] [S22]

---

## 3. Package managers

### 3.1 Conan 2

- **2.32.0 (2026-08-31)**, strictly monthly minors through 2026 (2.25 Jan → 2.32 Aug). Recent items: `CMakeConfigDeps` moved incubating → **experimental** (2.25.0, 2026-01-28) with full **CPS round-trip**; **Workspaces graduated out of incubating** (2.31.0, 2026-07-23) with `conan workspace open/add/complete/super-install`; `conan audit` CVE scanning (build/host context filter 2.21, CVE version info 2.27); **CycloneDX SBOM deployers** (2.26.0) and SPDX expressions (2.30.0); compiler support for Clang 22 (2.27), GCC 16 (2.29), GCC 16.2 (2.32); accepts CMake 4.4 `--presets-file` presets (2.32). [High] [S39]
- Friction for ROS-adjacent C++: Conan wants to own the toolchain/`CMAKE_TOOLCHAIN_FILE`, while `ament_cmake` wants to own `find_package` and install layout; mixing both means two dependency graphs (rosdep/apt vs. Conan) and potential duplicate libstdc++/OpenCV/Boost symbols. Works best when Conan produces an **isolated prefix** consumed via `CMAKE_PREFIX_PATH` for non-ROS third-party code (camera SDK wrappers, math/optimization libs). [Med — our synthesis]
- Tooling upside: SonarQube 2026.1 LTA does SCA (vulnerability/license) for Conan and vcpkg dependency graphs. [High] [S48]

### 3.2 vcpkg

- Registry release **2026.07.29**: 2,858 ports (2,807 in April; ~+50/quarter), 302 ports updated in July, 93 contributors/month, 27.3k stars; vcpkg-tool July releases focus on **SBOM** improvements; April tool releases added locking for parallel builds and cross-platform PE dependency analysis. Monthly registry cadence. [High] [S40]
- Friction: manifest mode + triplets is clean for standalone tools; inside colcon workspaces you must inject `CMAKE_TOOLCHAIN_FILE` per package and keep system-package overlap (Boost, OpenCV, Eigen from apt) out of the manifest to avoid ODR issues. `x64-linux` has 2,800 ports, `arm64-linux` 2,301 — check ARM coverage before committing on Jetson-class targets. [High for numbers; Med for guidance] [S40]

### 3.3 CPM.cmake

- **0.42.3** (2026-05): tests updated for CMake 4, README gained **supply-chain security notes**; 0.42.2 (2026-05-05) added `.tar.xz`/`.tar.zst` tarball URLs; 0.42.0 (2025-05-18) shortened `CPM_SOURCE_CACHE` hashes. [High] [S41]
- Fits ROS-adjacent libs when the dependency is header-only or small and not in rosdep; pin `GIT_TAG` to commits and set `CPM_SOURCE_CACHE` in CI. Avoid for anything also provided by apt/rosdep (double definitions in the same process). [Med — our synthesis]

### 3.4 ROS 2 ecosystem signal: rosdep + pixi/RoboStack

- On 2026-01-12 Open Robotics discourse thread "Pixi as a co-official way of installing ROS on Linux" (Esteve Fernandez, with core maintainers responding) proposes pixi/RoboStack alongside apt; consensus: rosdep stays for apt/rpm builds, `pixi-build-ros` is a "preview feature" and not a colcon replacement yet; pixi does **not** support rosdep inside its environments. Pixi gives a lockfile (`pixi.lock`) and cross-platform envs; RoboStack publishes conda packages for Humble/Jazzy/Kilted (Lyrical channel status: check before relying on it). [High for thread content; Med for channel status] [S42]
- Net: for a ROS 2 shop the pragmatic 2026 stack is **rosdep/apt for ROS + system libs, pixi for reproducible dev/CI environments (optional), vcpkg or Conan only for isolated vendor SDK wrappers**.

---

## 4. Static analysis and CI patterns

### 4.1 clang-tidy / clangd (LLVM 23.1, 2026-08-25)

- **Removed `hicpp` module** — every `hicpp-*` check now aliases into `bugprone-*`, `cppcoreguidelines-*`, `modernize-*`, `performance-*`, `readability-*`, `misc-*`, `portability-*`. `.clang-tidy` files listing `hicpp-*` will error/ignore in 23. `performance-faster-string-find` deprecated (→ `performance-prefer-single-char-overloads`, removal in LLVM 25). [High] [S43]
- New checks worth enabling: `bugprone-assignment-in-selection-statement`, `bugprone-unsafe-to-allow-exceptions`, `modernize-use-std-bit`, `modernize-use-string-view`, `performance-string-view-conversions`, `performance-use-std-move`, `readability-redundant-parameter-list`. [High] [S43]
- clang-tidy now (a) can run with only `clang-diagnostic-*` enabled (use it purely as a Clang-warnings frontend on a GCC-built tree), (b) matches the compiler's system-header suppression logic (expect some new diagnostics), (c) produces valid JSON profiles for odd paths. [High] [S43]
- **SARIF:** no native output as of 23.1; PR `llvm/llvm-project#219182` (`-export-sarif=`) opened 2026-08-27. Use `clang-tidy-sarif` 0.8.0 (sarif-rs) to convert for GitHub code scanning. `clang-tidy-diff.py` limits *reports* to changed lines but still analyzes whole files (no speedup). [High] [S44][S45]
- **clangd 23:** completion style default → `detailed` (per-overload items), better resource-dir discovery when clang/clangd are in different prefixes, module-build caching, new `clangd-remap` for background-index path remapping. [High] [S43]

### 4.2 Clang Static Analyzer / GCC analyzer

- CSA: SARIF and `sarif-html` outputs fixed (no more triplicated issues; `IssueHash` emitted) in 22. [High] [S7]
- GCC 16 `-fanalyzer`: C++ still not production-ready (see 1.4). [High] [S1]

### 4.3 Cppcheck

- **2.21.0 (2026-06-04):** repository moved to `github.com/cppcheck-opensource/cppcheck`; `compile_commands.json` include paths handled correctly; `--exitcode-suppress=<id>`; new checks (`uninitMemberVarNoCtor`, `fcloseInLoopCondition`, MISRA C 2012 10.3 tweak); Windows binary built with VS 2026. 2.20 (2026-03-02) bumped min CMake to 3.22, defaulted `win*/unix*` platforms to signed `char`. 2.19 (2025-12-21) fixed C++23 lambda parsing. SARIF via `--output-format=sarif` exists since 2.16 [older context]; note results go to **stderr** (`2> report.sarif`). [High] [S46]
- ROS: `ament_cmake_cppcheck` is still in `ament_lint_common`; Ubuntu 26.04 froze before 2.21 shipped, so its cppcheck package very likely lags — run upstream 2.21 in CI containers if you want the new checks. [High for ament_lint; Med for Ubuntu version] [S36]

### 4.4 Commercial: PVS-Studio, Coverity, SonarQube

- **PVS-Studio 8.00 (2026-08-19):** new JS/TS/Go analyzers (not relevant), continued **MISRA C++:2023** rollout (22 rules in 7.42, 12 in 7.43, 16 in 8.00), `x86_64-pc-linux-gnu-c++` compiler support, Qt Creator 20 plugin. 7.42 (2026-04-08) announced "official CMake integration" — this is CMake 4.3's `<LANG>_PVS_STUDIO` property. [High] [S47][S23]
- **Coverity 2026.6.0:** incremental C++26 support begins, Clang 21/22 and VS 2026 supported, Rust beta, TÜV functional-safety certification completed, CLI auto-configures **sccache** as a prefix compiler. Hyundai C/C++ 4.0 standards removed in 2026.9. [High] [S49]
- **SonarQube Server:** 2026.1 LTA — **SCA for C/C++ (Conan, vcpkg) GA**, MISRA C++:2023 compliance; 2026.2 — AI CodeFix for C++; 2026.4 — **Cross-Translation-Unit analysis beta** for C/C++ (100+ path-sensitive rules; run on a dedicated branch; ~30 MB disk/source file, 4 GB RAM/thread for C++, 1.1–2.2x runtime; incompatible with C++20 modules and PCH-optimized parsing). [High] [S48]
- **CodeQL (GitHub):** C23/C++23 in beta; compilers up to Clang 21, GCC 15, VS 2022 (i.e., **not** GCC 16 / Clang 22–23 / VS 2026 yet); `build-mode: none` GA for C/C++. [High] [S50]

### 4.5 CI patterns that work in 2026

1. `colcon build --mixin compile-commands` (or `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`) → one aggregated `build/compile_commands.json`. [High] [S34]
2. Run clang-tidy from LLVM 21 (system) or 23 (container) against that database with `-p build`, `--warnings-as-errors=*` for a curated allowlist; convert with `clang-tidy-sarif` and upload via `github/codeql-action/upload-sarif`. [High] [S44]
3. Emit native SARIF from GCC (`-fdiagnostics-add-output=sarif`, respects dump dir in 16) and Cppcheck (`--output-format=sarif 2>`) in the same job. [High] [S1][S46]
4. Nightly-only heavy passes: SonarQube CTU, Coverity, PVS-Studio (via CMake 4.3 property or `compile_commands.json`). [High] [S48][S49][S47]
5. Keep `ament_lint_auto` + `ament_lint_common` in `colcon test` for style gates; the `WarningsAsErrors` fix in `ament_clang_tidy` (2026) makes it usable as a hard gate. [High] [S36]

---

## 5. Related tooling

### 5.1 Sanitizers

- **RealtimeSanitizer (RTSan):** in LLVM since 20.0 [older context: Mar 2025], documented for Clang 23. `-fsanitize=realtime` + `[[clang::nonblocking]]` on real-time entry points; flags `malloc`, `free`, `pthread_mutex_lock`, syscalls, etc. at runtime; `[[clang::blocking]]` marks your own unsafe functions; `__rtsan::ScopedDisabler` for known-safe regions. Pairs with compile-time **Function Effect Analysis** (`-Wfunction-effects`, `nonblocking`/`nonallocating`), which warns when a `nonblocking` function lacks `noexcept`. **GCC has neither**; a standalone-header hack exists for GCC/AppleClang. [High] [S51]
- UBSan: Clang 22 trap-reason strings in debug info (`-fsanitize-debug-trap-reasons=`), `-fsanitize=alloc-token` (allocation-token instrumentation), `__builtin_allow_sanitize_check("address")`. [High] [S7]
- MSVC: AddressSanitizer for ARM64 targets (preview) in VS 2026 18.0. [High] [S13]
- Baseline advice unchanged: ASan+UBSan on GCC or Clang in a dedicated colcon mixin (`asan-gcc`, `ubsan`), TSan separately; RTSan requires Clang.

### 5.2 Linkers: mold / lld / wild

- **mold 2.42.0 (2026-08-12):** "numerous optimizations" this cycle; `--pack-dyn-relocs=android[+relr]`; `--compress-debug-sections=zstd:N`; README (Aug 2026 self-benchmark) claims 4.9x faster than lld and 1.9x faster than wild at the median. [High for release; Low for vendor benchmark] [S52]
- **wild 0.10 (2026-08-04)**, 0.9.0 (2026-05-24) added basic linker-plugin LTO and AArch64 range-extension thunks; 0.8.0 (2026-01-16). Rust, Linux ELF only, incremental linking still unimplemented; **CMake 4.4 recognizes `CMAKE_<LANG>_COMPILER_LINKER_ID = WILD`**. [High] [S53][S24]
- **lld:** MaskRay's 2026-04-12 measurements (clang-23 Release `--gc-sections`): lld HEAD 941 ms vs mold 599 ms vs wild 376 ms; excluding `--gdb-index`, mold is 1.47–1.97x and wild 2.50–2.78x as fast as lld; lld itself sped up 1.34x in 15 weeks (parallel `--gc-sections`, input loading). [High] [S54]
- Usage: `-fuse-ld=mold` (GCC ≥12/Clang) or CMake `CMAKE_LINKER_TYPE=MOLD|LLD` (CMake ≥3.29 [older context]); colcon `mold`/`lld` mixins exist in the default mixin repository. [Med] [S35]

### 5.3 Compiler caches: ccache / sccache

- **ccache 4.13 (2026-03-05)**, latest 4.13.6 (2026-05-04): **remote storage helpers** (out-of-process helpers; built-in HTTP/Redis "likely removed in a future release"), **directory-specific `ccache.conf`**, official MSVC support, distributed ThinLTO caching for Clang, musl static Linux binaries, `-fcoverage-prefix-map` rewriting. 4.12 (2025-09-14). Requires a C++20 compiler to build. [High] [S56]
- **sccache 0.17.0 (2026-07-29):** opt-in **client-side mode** (`SCCACHE_CLIENT_SIDE=1`) removes the server round-trip; response-file handling for gcc/clang; distributed-compile abort on client disconnect; S3 SSE-KMS. 0.15.0 (2026-04-30), 0.14.0 (2026-02-09), 0.12.0 (2025-10-20). Coverity 2026.6 auto-detects sccache. [High] [S55][S49]
- Hook-up: `-DCMAKE_CXX_COMPILER_LAUNCHER=ccache` via the colcon `ccache` mixin; with mold/ccache both enabled, expect colcon incremental rebuild wins mostly from ccache on generated `rosidl` code. [Med]

### 5.4 `compile_commands.json`

- Produced by `CMAKE_EXPORT_COMPILE_COMMANDS` (Makefile/Ninja only); colcon aggregates workspace-wide. Consumers verified in this window: clangd, clang-tidy, Cppcheck 2.21 (include-path fix), PVS-Studio (`compile_commands.json` / trace), SonarQube (build-wrapper or compile_commands), CodeQL `build-mode: none` (no DB needed). [High] [S34][S46][S47][S50]
- Caveat: C++20 modules break the "one TU = one command" assumption (clangd/tidy need module maps or CMake's scanning outputs) — one more reason to postpone modules.

### 5.5 Real-time-ish Linux

- **Ubuntu 26.04 LTS:** kernel 7.0; the **PREEMPT_RT kernel is free in the main archive** (`sudo apt install ubuntu-realtime`), variants `generic` and `raspi`; 24.04 still needs Ubuntu Pro (6.8 / HWE 6.17). PREEMPT_RT was fully upstreamed in Linux 6.12 [older context: Nov 2024], which is why Canonical dropped the Pro gate. [High] [S57]
- Toolchain implications: build RT paths with Clang for RTSan/Function-Effect checks even if GCC is the release compiler; use `_GLIBCXX_ASSERTIONS`/libc++ hardening in RT code only after measuring latency; prefer `EventsCBGExecutor` + thread naming utilities (`rcpputils`) for tracing under LTTng snapshot mode. [High for facts; Med for guidance] [S29][S51]

---

## 6. Watch next 6 months (Sep 2026 → Mar 2027)

| When | What | Why it matters |
|---|---|---|
| Sep–Dec 2026 | LLVM 23.1.x point releases biweekly (23.1.1 2026-09-08 … 23.1.8 2026-12-15) | Pick 23.1.3+ for CI containers. [High] [S8] |
| Nov 2026 | **MSVC 14.52** (VS 2026 Nov feature update): C++23 completion → `/std:c++23`, `c++23preview` deprecated | Windows-side C++23 baseline. [High] [S14][S15] |
| Nov 2026 | ROS 2 **Kilted Kaiju EOL**; Ubuntu 26.10 (gcc-16 16.2.0 already in the devel archive; expected to become the default) | Migrate Kilted users to Lyrical; test GCC 16 gnu++20 default before it hits your fleet. [High for EOL; Med for 26.10 default] [S32][S4] |
| ~Nov 2026 | **CMake 4.5** (expect: further CPS work, diagnostics categories, maybe another `import std` gate attempt) | Track `CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` history thread. [Med] [S25] |
| Nov 2026 | WG21 Búzios meeting (C++29 work); **C++26 ISO publication** likely between late 2026 and early 2027 | Contracts/profiles debates continue; `-fcontracts` semantics may shift slightly. [High/Med] [S17][S18] |
| Q4 2026–Q1 2027 | clang-tidy native SARIF (`-export-sarif`) if PR #219182 lands → LLVM 24 (branch ~Jan 2027, release ~Mar 2027) | Drop the converter step. [Med] [S44] |
| Q4 2026 | Conan `CMakeConfigDeps` experimental → stable? Conan 2.33–2.36; vcpkg monthly registries (SBOM tooling) | Only if you adopt Conan for vendor SDKs. [Med] [S39][S40] |
| Q4 2026–Q1 2027 | SonarQube CTU beta → GA; Coverity 2026.9/2026.12 (more C++26); PVS-Studio 8.0x MISRA C++:2023 completion | Nightly analysis budget. [Med] [S48][S49][S47] |
| 2027 | wild incremental linking (still "planned"); lld parallelization continues | Re-benchmark linkers yearly; mold remains the safe default. [Med] [S53][S54] |
| Ongoing | pixi/RoboStack "co-official" ROS install path; Lyrical RoboStack channel; `pixi-build-ros` preview | Reproducible dev envs; not a colcon replacement yet. [Med] [S42] |
| ~Apr–May 2027 | GCC 17.1, ROS 2 "M" release (non-LTS), Humble EOL (May 2027) | Out of window but drives 2027 planning. [Med] |

---

## 7. Actionable for a ROS 2 / C++ robotics shop (PLAIF-like)

Assumptions: fleet moving to **ROS 2 Lyrical on Ubuntu 26.04**, C++ nodes for polishing pipelines and camera drivers, some Windows tooling, CMake/ament packages, real-time-ish control on Linux.

### 7.1 Toolchain baseline (do now)

- **Release compiler:** GCC 15.2 (system) with `-std=` supplied by `ament_cmake_ros_core::ament_ros_defaults` (C++20). Add `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` only for third-party deps that still declare `< 3.5`; fix your own packages to `cmake_minimum_required(VERSION 3.22)` or higher. [S26][S29]
- **Analysis compiler:** Clang 21 (system `clang-21`, `clangd-21`, `clang-tidy-21`) for clangd/clang-tidy/RTSan; run LLVM 23 in a CI container for the newest checks. [S33][S43]
- **CMake:** 4.2.3 system minimum; use presets **schema 10** in `CMakePresets.json` (works on 4.2–4.4), upgrade to schema 12 / `--presets-file` once CI images carry 4.4. [S23][S24][S30]
- **Windows (if any ROS builds):** stay on VS 2022 / v143 for ROS packages; VS 2026 + 14.51 only for standalone tools. [S28][S15]
- **GCC 16.2** in an experimental container to (a) preview the gnu++20 default and new diagnostics before Ubuntu 26.10, (b) try `-freflection` for message/serialization codegen — do **not** ship it. [S1][S4]

### 7.2 Flags

```cmake
# Dev/CI configuration (GCC)
add_compile_options(-O2 -g -fno-omit-frame-pointer -Wall -Wextra -Wpedantic -Werror=return-type)
add_compile_definitions($<$<CONFIG:Debug,RelWithDebInfo>:_GLIBCXX_ASSERTIONS>)
# Release candidates for non-hot-path nodes: evaluate -fhardened (GCC 14+); measure image-pipeline nodes first.
# Reproducible ISA for x86 controllers:
add_compile_options(-march=x86-64-v3)
```

- Machine-readable diagnostics: GCC `-fdiagnostics-add-output=sarif`, Clang `-fdiagnostics-format=sarif`; never rely on GCC's removed JSON format. [S1][S7]

### 7.3 Real-time paths (control loops, camera callbacks)

- Annotate RT entry points with `[[clang::nonblocking]]`, compile the RT packages with Clang `-fsanitize=realtime -Wfunction-effects` in a nightly `colcon build --mixin rtsan` job (custom mixin), run the bring-up on the free Ubuntu 26.04 `ubuntu-realtime` kernel. [S51][S57]
- Use `rosidl::Buffer<uint8_t>` for image `uint8[]` payloads to avoid copies with GPU pre-processing (Fast DDS only for now) and `EventsCBGExecutor` for lower CPU; keep the vendor camera SDK behind a thin `*_vendor` package. [S29]

### 7.4 Static analysis pipeline

- Before moving CI to LLVM 23: `grep -r "hicpp-" .clang-tidy` → replace with the mapped checks; add `modernize-use-std-bit`, `performance-use-std-move`, `bugprone-assignment-in-selection-statement`. [S43]
- Per-PR: clang-tidy (changed files via `clang-tidy-diff.py`, converted with `clang-tidy-sarif`) + Cppcheck 2.21 SARIF + GCC SARIF → GitHub code scanning. Nightly: SonarQube CTU (dedicated branch, sized per Sonar's 4 GB/thread guidance) or Coverity 2026.6 if functional-safety evidence (TÜV-certified) is needed for polishing cells. [S44][S46][S48][S49]
- Keep `ament_lint_auto` in `colcon test`; set `WarningsAsErrors` in `.clang-tidy` now that `ament_clang_tidy` reports it correctly. [S36]

### 7.5 Build speed

- `colcon build --mixin ninja ccache mold compile-commands` (default mixin repo names may differ — verify with `colcon mixin show`); ccache 4.13's per-directory `ccache.conf` lets each workspace pin `base_dir`/`sloppiness`. If you already run S3/Redis caches, evaluate sccache 0.17 client-side mode. [S34][S35][S52][S55][S56]
- Turn on CMake 4.3+ `cmake_instrumentation()` with `compileTrace` (4.4) and Clang `-ftime-trace` for the slowest TUs (typically `rclcpp` generic-publisher templates and Eigen-heavy pipeline code). [S23][S24]

### 7.6 Dependencies

- Keep `rosdep`/apt for everything ROS and for OpenCV/PCL/Eigen/Boost (versions pinned by Ubuntu 26.04: OpenCV 4.10.0, PCL 1.15.1). [S30]
- Vendor camera/motion SDKs: wrap in `*_vendor` packages (ExternalProject/FetchContent) or a **vcpkg manifest / Conan 2 profile producing an isolated prefix**; never let both apt and vcpkg/Conan provide the same library into one process. If you go Conan, target `CMakeConfigDeps` (CPS-capable) rather than legacy `CMakeDeps`. [S39][S40]
- Pilot **pixi** for reproducible developer environments/CI (lockfile), while keeping colcon as the build driver. [S42]

### 7.7 Explicitly defer

- C++20 modules / `import std` in ROS packages (CMake gate, no distro std modules, clangd/tidy gaps). [S1][S25]
- Bazel migration (WORKSPACE removal makes any half-done migration painful; ROS 2 rules are community-maintained). [S37]
- GCC `-fanalyzer` for C++. [S1]

---

## Sources (accessed 2026-09-09 unless noted)

Compilers / standard
- [S1] GCC 16 Release Series — Changes: https://gcc.gnu.org/gcc-16/changes.html
- [S2] LWN, "GCC 16.1 released" (2026-04-30): https://lwn.net/Articles/1070649/
- [S3] isocpp.org, "GCC 16.1 released…" (2026-04-30): https://isocpp.org/blog/2026/04/gcc-16.1
- [S4] GCC 16.2 release (2026-08-07): https://sourceware.org/ftp/gcc/releases/gcc-16.2.0/ ; Phoronix: https://www.phoronix.com/news/GCC-16.2-Released
- [S5] GCC 15.1 released (2025-04-25), LWN: https://lwn.net/Articles/1018920/ ; Red Hat, "New C++ features in GCC 15": https://developers.redhat.com/articles/2025/04/24/new-c-features-gcc-15
- [S6] GCC C++ Standards Support: https://gcc.gnu.org/projects/cxx-status.html
- [S7] LLVM 22.1.0 released (2026-02-24): https://discourse.llvm.org/t/llvm-22-1-0-released/89950 ; Clang 22.1.0 Release Notes: https://releases.llvm.org/22.1.0/tools/clang/docs/ReleaseNotes.html
- [S8] LLVM 23.1.0 released (2026-08-25): https://discourse.llvm.org/t/llvm-23-1-0-released/91654 ; schedule: https://llvm.org/ ; Phoronix: https://www.phoronix.com/news/LLVM-23.1-Released
- [S9] LLVM 21.1.0 released (2025-08-26): https://discourse.llvm.org/t/llvm-21-1-0-released/88066
- [S10] Clang C++ Status: https://clang.llvm.org/cxx_status.html
- [S11] libc++ C++2c Status (22.1.0): https://releases.llvm.org/22.1.0/projects/libcxx/docs/Status/Cxx2c.html
- [S12] C++ Language Updates in MSVC Build Tools v14.50: https://devblogs.microsoft.com/cppblog/c-language-updates-in-msvc-build-tools-v14-50/
- [S13] What's New for C++ Developers in Visual Studio 2026 18.0: https://devblogs.microsoft.com/cppblog/whats-new-for-cpp-developers-in-visual-studio-2026-version-18-0/
- [S14] C++23 Support in MSVC Build Tools 14.51: https://devblogs.microsoft.com/cppblog/c23-support-in-msvc-build-tools-14-51/
- [S15] New release cadence and support lifecycle for MSVC Build Tools: https://devblogs.microsoft.com/cppblog/new-release-cadence-and-support-lifecycle-for-msvc-build-tools/ ; Lifecycle FAQ: https://learn.microsoft.com/en-us/lifecycle/faq/visual-c-faq
- [S16] Microsoft C/C++ language conformance: https://learn.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance?view=msvc-170 ; What's new for MSVC: https://learn.microsoft.com/en-us/cpp/overview/what-s-new-for-msvc?view=msvc-170
- [S17] Herb Sutter, "C++26 is done!" trip report (2026-03-29): https://herbsutter.com/2026/03/29/c26-is-done-trip-report-march-2026-iso-c-standards-meeting-london-croydon-uk/
- [S18] WG21 N5051 Editors' Report (DIS preparation): https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2026/n5051.html
- [S19] wro.cpp, "C++26 is done — five weeks since Croydon" (secondary): https://wrocpp.github.io/posts/cpp26-five-weeks/
- [S20] moderncpp.dev, "GCC 16.1 and C++20 Modules" (opinion): https://moderncpp.dev/articles/gcc16-cpp20-modules-adoption-practical/
- [S21] Hardening: C++ Stories, "Standard Library Hardening Experiments" (2026): https://www.cppstories.com/2026/hardening-experiments/ ; libstdc++ hardened feature-test macros commit: https://github.com/gcc-mirror/gcc/commit/b7e4c5254212aceedf69725f8816ef3efce39178 ; wro.cpp toolset (overhead table, secondary): https://wrocpp.github.io/toolset/hardened-stdlib/ ; Šimon Tóth, "Hardened mode of standard library implementations": https://simontoth.substack.com/p/daily-bite-of-c-hardened-mode-of

Build
- [S22] CMake 4.2.0 (2025-11-20): https://www.kitware.com/cmake-4-2-0-available-for-download/ ; notes: https://cmake.org/cmake/help/v4.2/release/4.2.html
- [S23] CMake 4.3.0 (2026-03-17): https://www.kitware.com/cmake-4-3-0-available-for-download/ ; notes: https://cmake.org/cmake/help/v4.3/release/4.3.html ; "Common Package Specification is Out the Gate": https://www.kitware.com/common-package-specification-is-out-the-gate/
- [S24] CMake 4.4.0 (2026-07-14): https://www.kitware.com/cmake-4-4-0-available-for-download/ ; notes: https://cmake.org/cmake/help/latest/release/4.4.html ; Kitware release list (4.4.3, 2026-09-02): https://www.kitware.com/software-releases/
- [S25] CMake `import std` gate history (Discourse): https://discourse.cmake.org/t/cmake-experimental-cxx-import-std-value-history-and-state/15712 ; commit "Restore `import std` gate": https://github.com/Kitware/CMake/commit/c1d58d3f3d14213b1d8336255a731fe1234dfd1a ; `CXX_MODULE_STD` docs: https://cmake.org/cmake/help/latest/prop_tgt/CXX_MODULE_STD.html
- [S26] CMake 4.0 Release Notes [older context, Mar 2025]: https://cmake.org/cmake/help/v4.0/release/4.0.html
- [S27] Ninja releases (v1.13.2, 2025-11-20): https://github.com/ninja-build/ninja/releases
- [S28] "ROS 2 Lyrical Luth Released!" (2026-05-22): https://discourse.openrobotics.org/t/ros-2-lyrical-luth-released/55021
- [S29] Lyrical Luth release notes: https://docs.ros.org/en/lyrical/Releases/Release-Lyrical-Luth.html (source: https://github.com/ros2/ros2_documentation/blob/lyrical/source/Releases/Release-Lyrical-Luth.rst)
- [S30] Lyrical Luth Supported Platforms: https://docs.ros.org/en/lyrical/Releases/lyrical/supported-platforms.html
- [S31] "ROS 2 Lyrical C++ Version" (2026-02-17): https://discourse.openrobotics.org/t/ros-2-lyrical-c-version/52551 ; rclcpp C++20 switch: https://github.com/ros2/rclcpp/issues/3124
- [S32] "ROS 2 Kilted Kaiju Release!" (2025-05-23, EOL Nov 2026): https://discourse.openrobotics.org/t/ros-2-kilted-kaiju-release/43902
- [S33] Ubuntu 26.04 LTS: Canonical announcement: https://canonical.com/blog/canonical-releases-ubuntu-26-04-lts-resolute-raccoon ; gcc package (15.2.0): https://packages.ubuntu.com/en/resolute/gcc ; toolchain summary (secondary): https://linuxiac.com/ubuntu-26-04-lts-resolute-raccoon-released/
- [S34] colcon How-to (compile_commands.json): https://colcon.readthedocs.io/en/released/user/how-to.html
- [S35] colcon-mixin composition, GSoC 2026 update (Aug 2026): https://discourse.openrobotics.org/t/gsoc-2026-add-support-for-mixin-composition-in-colcon-mixin-progress-update/57408 ; PR: https://github.com/colcon/colcon-mixin/pull/70 ; default mixins: https://github.com/colcon/colcon-mixin-repository
- [S36] ament_lint (lyrical) changelog: https://github.com/ament/ament_lint/blob/lyrical/ament_clang_tidy/CHANGELOG.rst ; uncrustify ≥0.78.1: https://github.com/ament/ament_lint/issues/581
- [S37] Bazel 9 LTS (2026-01-20): https://blog.bazel.build/2026/01/20/bazel-9.html ; release notes: https://github.com/bazelbuild/bazel/releases/tag/9.0.0 ; rules_ros2: https://github.com/mvukov/rules_ros2
- [S38] Meson 1.12.0 (2026-08-10): https://github.com/mesonbuild/meson/releases/tag/1.12.0

Package managers
- [S39] Conan 2 changelog (2.32.0, 2026-08-31): https://docs.conan.io/2/changelog.html
- [S40] "What's New in vcpkg (Jul 2026)": https://devblogs.microsoft.com/cppblog/whats-new-in-vcpkg-jul-2026/ ; releases: https://github.com/microsoft/vcpkg/releases
- [S41] CPM.cmake releases: https://github.com/cpm-cmake/CPM.cmake/releases
- [S42] "Pixi as a co-official way of installing ROS on Linux" (2026-01-12): https://discourse.openrobotics.org/t/pixi-as-a-co-official-way-of-installing-ros-on-linux/51764 ; Pixi for Robotics: https://pixi.prefix.dev/latest/robotics/ ; pixi-build-ros: https://prefix-dev.github.io/pixi-build-backends/backends/pixi-build-ros/

Static analysis
- [S43] Extra Clang Tools 23.1.0 Release Notes: https://releases.llvm.org/23.1.0/tools/clang/tools/extra/docs/ReleaseNotes.html
- [S44] "[clang-tidy] Add SARIF output to clang-tidy" PR (2026-08-27): https://github.com/llvm/llvm-project/pull/219182 ; clang-tidy-sarif: https://crates.io/crates/clang-tidy-sarif
- [S45] clang-tidy documentation: https://clang.llvm.org/extra/clang-tidy/
- [S46] Cppcheck releases (2.21.0 2026-06-04, 2.20.0 2026-03-02, 2.19.0 2025-12-21): https://github.com/cppcheck-opensource/cppcheck/releases
- [S47] PVS-Studio release history: https://pvs-studio.com/en/docs/manual/0010/ ; 7.42: https://pvs-studio.com/en/blog/posts/1365/ ; 7.43: https://pvs-studio.com/en/blog/posts/1386/ ; 8.00: https://pvs-studio.com/en/blog/posts/1406/
- [S48] SonarQube Server 2026.1 LTA: https://www.sonarsource.com/products/sonarqube/whats-new/2026-1/ ; 2026.2: https://www.sonarsource.com/products/sonarqube/whats-new/2026-2/ ; CTU beta (2026-07-17): https://community.sonarsource.com/t/catch-the-c-and-c-bugs-that-hide-across-your-files-ctu-analysis-enters-beta/186105
- [S49] Coverity 2026.6.0 Release Notes: https://docs.blackduck.com/r/coverity/latest/coverity-documentation/coverity-2026.6.0-release-notes.html ; C++26 rollout KB (2026-05-15): https://community.blackduck.com/s/article/Coverity-C-26-support-is-being-incrementally-rolled-out-from-Coverity-Analysis-2026-6-onwards
- [S50] CodeQL supported languages and frameworks: https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/

Related
- [S51] RealtimeSanitizer (Clang 23.1 docs): https://releases.llvm.org/23.1.0/tools/clang/docs/RealtimeSanitizer.html ; Function Effect Analysis: https://clang.llvm.org/docs/FunctionEffectAnalysis.html ; RTSan project: https://github.com/realtime-sanitizer/rtsan/
- [S52] mold 2.42.0 (2026-08-12): https://github.com/rui314/mold/releases/tag/v2.42.0 ; README benchmarks: https://github.com/rui314/mold
- [S53] wild linker: https://github.com/wild-linker/wild/ ; "Wild Linker Update - 0.9.0" (2026-05-24): https://davidlattimore.github.io/posts/2026/05/24/wild-update-0.9.0.html
- [S54] MaskRay, "Recent lld/ELF performance improvements" (2026-04-12): https://maskray.me/blog/2026-04-12-recent-lld-elf-performance-improvements
- [S55] sccache v0.17.0 (2026-07-29): https://github.com/mozilla/sccache/releases/tag/v0.17.0
- [S56] Ccache release notes: https://ccache.dev/releasenotes.html ; news: https://ccache.dev/news.html
- [S57] Real-time Ubuntu: https://ubuntu.com/real-time ; releases: https://ubuntu.com/real-time/docs/reference/releases/ ; enable guide: https://documentation.ubuntu.com/real-time/latest/how-to/enable-real-time-ubuntu/
- [S58] action-ros-ci "Add support for Lyrical" (merged 2026-05-07): https://github.com/ros-tooling/action-ros-ci/pull/1029 ; industrial_ci: https://github.com/ros-industrial/industrial_ci/
