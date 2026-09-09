# RESA 브리프 — NVIDIA cuRobo × PLAIF (Hyundai wrinkle 셀 · dual-arm 제품화 · ROS 2)

작성일: 2026-09-09 · 대상: Resa / Orche · 상태: research brief (코드 변경 없음)

> 후속: `RESA_CUROBO_DEPLOYED_CASES.md` — 실제 배치·운용 사례(cuMotion 제품 4건, 실명 현장 2건, peer Realtime Robotics, 양팔 실기 연구)와 현장 실패·라이선스 검증. 결론: Conditional 유지(소폭 강화). 정정 1건: Isaac ROS 4.4(2026-04-30)부터 cuMotion 은 cuRobo v0.7.x 소스가 아닌 closed C++ `cumotion` 1.x 바이너리(NVIDIA Isaac ROS Software License)다.

## 0. 한 줄 판정

**Conditional — "안전 자세·free-space 전이 자동화 PoC 는 Go, force polishing / 티칭 시퀀스 / `core_manipulation` 오케스트레이터 / 양팔 공유물체 협조 대체는 No-Go."**
근거: 이 셀에서 planner 부재로 발생한 실제 비용은 *전이 자세(home/ready/drain, `home_left`류) 수동 티칭과 양팔 간섭 확인*이며, cuRoboV2 의 `plan_cspace`·단일 tree dual-arm·ESDF 가 정확히 그 범위를 겨냥한다. 반면 셀의 본체(force polishing, route 시맨틱, 오케스트레이션)와 동시 양팔 공유물체 협조는 cuRobo 가 다루지 않는다.

## 1. 질문 프레임

- 원 질문 "cuRobo 가 dual-arm 협조에 좋은가?" 는 이 셀에서는 부차적이다. 셀 본체는 seat 위 steam/polish route(taught route + force/Z 보정)이고, 현재 스택에 motion planner 가 없어 **안전/전이 자세를 사람이 손으로 티칭**해 왔다(TeachingPendant 경로는 제거, 시퀀스는 core GUI Sequence + `seat_plans` YAML).
- 재정의: (a) wrinkle 셀 — *장애물(seat, fixture, fence, tool, 반대팔) 속 named pose 사이 collision-free 전이를 cuRobo 가 생성/재계획해 티칭 부담을 줄일 수 있는가*; (b) PLAIF dual-arm 제품화 — *cuRobo 를 재사용 가능한 dual-arm 모션 컴포넌트로 삼을 수 있는가, 어디까지인가*; (c) ROS 2 — *현 스택(`core_manipulation` → `controller-manager`, FastDDS/SHM)에 어떻게 꽂히는가*.
- 범위 밖(그대로 유지): polishing route, force/Z 보정 루프, `seat_plans` 시맨틱, `core_manipulation` 오케스트레이션, `controller-manager`(ros2_control) 실행 계층.

## 2. cuRobo 현황 (2026-09)

- GPU(CUDA/PyTorch/Warp) 병렬 모션 라이브러리: FK/IK(배치, collision-free), 충돌 검사(cuboid/mesh/depth→ESDF), trajectory optimization, graph planner, MotionGen, MPC(MPPI). 레거시 문서(v0.7.6): <https://curobo.org/>
- **cuRoboV2 = v0.8.0 (2026-04-18), Apache-2.0.** "Major refactor, breaks most existing API"; v1 API 필요 시 `v0.7.8` 고정. 레거시 문서는 "business/commercial use 는 cuRoboV2" 명시(v0.7.x 자산 헤더는 NVIDIA 독점 고지). 릴리스 <https://github.com/NVlabs/curobo/releases/tag/v0.8.0> · LICENSE <https://github.com/NVlabs/curobo/blob/main/LICENSE> · v0.7.8 <https://github.com/NVlabs/curobo/tree/v0.7.8>
- V2 기술 보고서(arXiv 2603.05493): B-spline trajopt + torque limit(RNEA), nvblox 의존 제거한 GPU-native TSDF/ESDF, 고DoF(bimanual/humanoid) 스케일링. <https://arxiv.org/abs/2603.05493> · v1 보고서 <https://arxiv.org/abs/2310.17274>
- 설치 요건(V2): Ubuntu ≥ 20.04, **GPU > Turing(Ampere 이상), VRAM ≥ 4 GB, driver ≥ 580.65.06**, Python ≥ 3.10, `pip install .[cu12|cu13(-torch)]`. <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/installation.rst>
- 최근 변화 속도: 2026-04 TSDF feature channel, 2026-06 LiDAR TSDF + **live RealSense RGB-D mapping + MPC**, 2026-07 textured mapper. API 가 아직 월 단위로 움직인다(제품화 리스크, §5.2). <https://github.com/NVlabs/curobo/blob/main/docs/news.rst>
- ROS 2 제품 경로 = Isaac ROS cuMotion(MoveIt 2 plugin + action server). 4.6.0(2026-08-18), cuMotion 1.1.0. **ROS 2 Jazzy / Ubuntu 24.04 / CUDA 13.2+ / driver 595+**, Jetson Thor·Orin(JetPack 7.2), DGX Spark. <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/index.html>

## 3. Deliverable 1 — capability & limit: dual-arm / collision / synchronization / MPC·planning

### 3.1 Dual-arm

가능한 것
- 양팔을 **하나의 kinematic tree(단일 URDF, 공통 base)** 로 모델링하고 `tool_frames: ["tool1","tool0"]` 로 두 팔 목표를 한 최적화 문제에서 동시 해결(`dual_ur10e.yml`, 12-joint cspace). V2 <https://github.com/NVlabs/curobo/blob/main/curobo/content/configs/robot/dual_ur10e.yml> · v1 <https://raw.githubusercontent.com/NVlabs/curobo/v0.7.8/src/curobo/content/configs/robot/dual_ur10e.yml>
- V2 IK 벤치(dual_ur10e, batch 100): IK 6.06 ms / 성공 100 %, collision-free IK 15.6 ms / 성공 99.2 %. <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst>
- V2 논문은 12-DoF dual-UR10e 를 kinematics·dynamics 벤치 대상으로 포함하고, 분기 kinematic tree(다중 EE) 의 sparse Jacobian·map-reduce self-collision 을 V2 의 핵심 기여로 제시. <https://arxiv.org/abs/2603.05493>
- 임의 링크에 tool/물체 sphere 부착(V2 `AttachmentManager`; v1 은 기본 EE 만 되는 버그 #553). <https://github.com/NVlabs/curobo/blob/main/curobo/_src/collision/attachment_manager.py> · <https://github.com/NVlabs/curobo/issues/553>

한계
- NVIDIA 공식 답변: "dual arm motion planning where **both arms need to have a target**. We don't directly support having **one arm static while the other arm is moving** as an API. You can achieve this by using two separate instances of motion planner. These features are **not integrated with MoveIt**." <https://github.com/NVlabs/curobo/issues/349>
- 레거시 문서: "Multi-Arm motion planning is **experimental** and does not work as well as single arm planning… only meant to be a starting point for research." <https://curobo.org/get_started/2b_isaacsim_examples.html> · 공유 torso 양팔에서 "Plan did not converge" 보고, 유지자 권고는 IK iteration 상향 <https://github.com/NVlabs/curobo/discussions/337>
- **closed-chain / 상대자세 제약 없음**: 두 tool 간 상대 transform 을 궤적 전 구간에서 강제하는 API 가 없다(목표 시점 pose 만). 공유물체 동시 운반·양손 조립은 범위 밖.
- 반대팔을 *움직이는* 장애물로 넣는 표준 경로 없음(discussion #345 미답변). <https://github.com/NVlabs/curobo/discussions/345>
- 문헌: ICRA 2026 SDAR — "cuRobo can compute nice motions for dual-arm systems for **certain pre-specified start/goal configurations**… doing so reliably for **random start/goal configurations remains difficult**"; fallback 없이 cuRobo 만 쓰면 성공률 49 %(SDAR-T+cuRobo) / 11 %(baseline TP+cuRobo), 저자들은 cuRobo IK+MotionGen 위에 rule-based untangling fallback 을 얹어 100 %. <https://arxiv.org/abs/2512.08206> · <https://github.com/arc-l/dual-arm>
- Isaac ROS cuMotion 은 **단일 매니퓰레이터만**: planning group 2개면 "'JointX' is not in list" 실패, NVIDIA "We currently don't support two manipulators", XRDF `tool_frames` 첫 항목만 사용. <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion/issues/10> · <https://forums.developer.nvidia.com/t/dual-arm-robot-use-isaac-ros-cumotion-with-erroe/336266>

### 3.2 Collision

가능한 것
- 월드 표현: cuboid / mesh / voxel-ESDF. v1 은 nvblox 연동, **V2 는 GPU-native TSDF/ESDF 내장**(depth 이미지 → dense ESDF, nvblox 대비 2–10× 빠르고 2–8× 적은 메모리, collision recall 92–99 % @10–20 mm voxel). <https://curobo.org/get_started/2c_world_collision.html> · <https://arxiv.org/abs/2603.05493>
- 로봇 = collision sphere 집합 + self-collision 행렬(XRDF/yml); trajopt 안에서 swept-sphere 충돌 비용; V2 는 sphere fitting 도구(`sphere_fit`)와 self-collision map-reduce 제공. <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/build_robot_model.rst>
- 배치 collision-free IK 로 reachability/충돌 사전 점검(레거시 `ik_reachability.py`). <https://curobo.org/get_started/2b_isaacsim_examples.html>
- 실측: RealSense/ZED depth → TSDF → ESDF → planner/MPC 를 한 제어 루프에서 구동(V2 논문 §7.7, 2026-06 live RealSense 예제). <https://github.com/NVlabs/curobo/blob/main/curobo/examples/reference/live_volumetric_mapping_mpc.py>

한계
- 충돌 회피는 **비용항(cost) 기반**이지 hard constraint 가 아니다. 문서: 제약은 "cost… the trajectory will not reach the exact offset". <https://curobo.org/advanced_examples/3_constrained_planning.html> → 여유(`collision_sphere_buffer`, self-collision buffer)와 **독립 검증기**가 필요.
- 계획 호출 시점의 **정적 월드 스냅샷**(`update_world(SceneCfg)` 로 갱신). 움직이는 장애물의 swept volume 은 모델링하지 않는다. <https://github.com/NVlabs/curobo/blob/main/curobo/_src/motion/motion_planner.py>
- depth 기반 장애물의 ghost voxel 위험은 NVIDIA 문서도 인정(nvblox 비활성 + MoveIt scene file 정적 장면을 대안으로 제시). <https://nvidia-isaac-ros.github.io/v/release-4.0/reference_workflows/isaac_for_manipulation/tutorials/pick_and_place/tutorial_pick_and_place.html>
- sphere 근사 정밀도 = 사용자 책임(steam 노즐·polishing head 는 직접 sphere 정의/부착).

### 3.3 Synchronization

가능한 것
- 단일 tree 계획은 **한 개의 시간축 위 12-joint 궤적**을 낸다 → 두 팔이 같은 시각에 출발·정지하고, 궤적 전 구간에서 상호 충돌이 같은 최적화에 반영된다(구조적 동기화). `dual_ur10e.yml` cspace 12 joints, `MotionPlanner.plan_cspace/plan_pose` 결과 `get_interpolated_plan()`(고정 `interpolation_dt`). <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/motion_planning.py>
- 전체 속도 스케일링: v0.7.2 re-timing(계획 간 궤적 속도 변경) <https://curobo.org/>, cuMotion `time_dilation_factor`(기본 0.5)·`interpolation_dt`(0.025 s). <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion/index.html>

한계
- **팔별 독립 타이밍 없음**: 한 팔만 움직이려면 planner 인스턴스 분리(#349) → 두 인스턴스 사이에 공통 시간축이 없고, 반대팔은 계획 시점의 정적 자세로만 반영된다(3.2).
- **동기화된 "협조 좌표계" 개념 없음**: ABB MultiMove 의 coordinated work object + `SyncMoveOn` 같은 "물체를 든 팔에 다른 팔이 상대위치를 유지" 기능은 cuRobo 에 없다. <https://search.abb.com/library/Download.aspx?DocumentID=3HAC050961-001>
- **실행 동기화는 ros2_control 책임**: 12-joint 단일 `joint_trajectory_controller` 면 한 클록으로 실행되지만, 팔별 JTC 2개면 `FollowJointTrajectory` 의 `trajectory.header.stamp` 로 시작 시각을 맞춰야 한다. <https://control.ros.org/master/doc/ros2_controllers/joint_trajectory_controller/doc/userdoc.html>

### 3.4 MPC / Planning

가능한 것
- 계획 파이프라인: 배치 IK seed → graph planner → 다중 seed trajopt(v1 MotionGen, V2 `MotionPlanner`). V2 벤치(RTX 6000 Ada, 2,600문제): 성공 99.73 %, plan time 평균 38 ms(3 kg torque limit 포함 52 ms); 논문 end-to-end 35/42 ms(RTX 4090). 레거시: UR10 on Jetson Orin 100 ms 이내. <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst> · <https://curobo.org/>
- V2 만의 것: B-spline 궤적 + **torque limit 강제**(3 kg payload 에서 v1 77 % → V2 99.7 %), goal set(`num_goalset`), grasp 3단계(`plan_grasp`: approach/grasp/lift), joint-space 목표(`plan_cspace`), tool pose 제약(`update_tool_pose_criteria`). <https://github.com/NVlabs/curobo/blob/main/curobo/_src/motion/motion_planner.py>
- MPC: v1 MPPI 500 Hz(RTX 4090) — 단일 팔; V2 `ModelPredictiveControl.update_goal_tool_poses`, whole-body, 예제 `optimization_dt` 0.025–0.03 s. V2 논문 표 1: MPC 지원 범위 v1 "Single-Arm" → V2 "Whole-Body". <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/reactive_control.py>

한계
- MPC 는 "**experimental and does not provide safety guarantees**… constraints as cost terms with large weights" (레거시 문서), V2 논문도 MPC 추종 정확도가 IK 보다 낮다고 기술. <https://curobo.org/get_started/2b_isaacsim_examples.html>
- **힘/임피던스 제어 없음**: 어떤 버전에도 접촉력 제어·Z 보정 기능이 없다(V2 RNEA 는 torque *limit* 검사용).
- **표면 경로 추종 없음**: 점→점(+goalset, grasp 3단계)만 있고 MoveIt Pilz `LIN/CIRC`+blending 이나 Descartes/noether 류 toolpath 추종 primitive 가 없다.
- 단일 팔 계획 시간은 최신 SIMD/GPU sampling planner 보다 느리다(pRRTC 논문: Panda 에서 pRRTC 가 cuRobo v1 대비 128× 빠름, VAMP-RRTC 는 그보다 3× 더 빠름 — 단, cuRobo 는 시간-최적·jerk 최소 궤적을 직접 출력). <https://arxiv.org/abs/2503.06757>

### 3.5 요약 매트릭스

| 축 | 가능 | 조건부 | 불가 |
|---|---|---|---|
| Dual-arm | 단일 tree 동시 목표, 상호 충돌 회피, 다중 tool 부착 | 한 팔 정지(인스턴스 분리), 임의 start/goal 신뢰성(fallback 필요) | closed-chain/상대자세 제약, cuMotion 경로 |
| Collision | cuboid/mesh/ESDF, RealSense→ESDF, 배치 C-free IK | depth 노이즈(ghost voxel), sphere 정밀도 | hard-constraint 보증, 동적 장애물 swept volume |
| Sync | 단일 시간축 12-joint 궤적, 전체 속도 스케일링 | 팔별 JTC 시작 시각 정렬 | 팔별 독립 타이밍, 협조 좌표계(MultiMove류) |
| MPC/Planning | 수십 ms 계획, torque limit, goal set, grasp 3단계, joint 목표 | MPC(안전 보증 없음), 제약=cost | force/impedance, 표면 경로 추종 |

## 4. Deliverable 2 — dual-arm coordination 대안과 pros/cons

| 스택 (1차 문서) | 장점 | 단점 / PLAIF 판단 |
|---|---|---|
| **cuRoboV2 Python 직접 통합** <https://github.com/NVlabs/curobo> | Apache-2.0; 양팔 단일 tree 동시 최적화; `plan_cspace` 로 named pose 전이; RealSense→ESDF 내장; time-optimal·jerk 최소 궤적; 배치 IK | GPU 필수; ROS 인터페이스·fallback 자작; dual-arm "experimental"; closed-chain 없음; API 변동성 |
| **Isaac ROS cuMotion** (MoveIt 2 plugin, action `cumotion/move_group`) <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion_moveit/index.html> | NVIDIA 제품 경로·문서·UR 예제; nvblox; `time_dilation_factor` | **단일 매니퓰레이터**, MoveIt 2 필수(현 스택 미사용), Jazzy/24.04 + Isaac ROS 환경 종속. UR 예제는 `scaled_joint_trajectory_controller` 에 `allow_nonzero_velocity_at_trajectory_end=true` 요구 |
| **MoveIt 2**: 양팔 합친 planning group + OMPL, OMPL constrained planning, MoveIt Task Constructor(MTC), Hybrid Planning <https://moveit.picknik.ai/main/doc/examples/move_group_interface/move_group_interface_tutorial.html> · <https://moveit.picknik.ai/main/doc/how_to_guides/using_ompl_constrained_planning/ompl_constrained_planning.html> · <https://github.com/moveit/moveit_task_constructor> · <https://moveit.picknik.ai/main/doc/concepts/hybrid_planning/hybrid_planning.html> | CPU 만으로 동작; 팔별/합친 group 전환이 자연스러움; MTC 로 stage 단위 양팔 순서·조건 표현; Pilz `PTP/LIN/CIRC`+blending 은 산업 전이에 익숙 <https://moveit.picknik.ai/main/doc/how_to_guides/pilz_industrial_motion_planner/pilz_industrial_motion_planner.html> | 스택에 MoveIt 도입 비용; sampling planner 는 궤적 품질·시간-최적성이 후처리 의존; 양팔 동시 최적화·ESDF 는 약함 |
| **Tesseract / TrajOpt** (ROS-Industrial) <https://tesseract-docs.readthedocs.io/en/latest/> · <https://github.com/tesseract-robotics/tesseract> | 다중 kinematic group, TrajOpt 최적화, 표면 가공(Scan-N-Plan: noether/Descartes) 계보 <https://github.com/ros-industrial/noether> · <https://github.com/swri-robotics/descartes_light> | 학습 곡선; GPU 가속 없음; 이 셀 route 는 이미 티칭+force 로 해결되어 toolpath 도구는 과함 |
| **Drake** (TRI) <https://drake.mit.edu/> · IK <https://drake.mit.edu/doxygen_cxx/classdrake_1_1multibody_1_1_inverse_kinematics.html> · KinematicTrajectoryOptimization <https://drake.mit.edu/doxygen_cxx/classdrake_1_1planning_1_1trajectory__optimization_1_1_kinematic_trajectory_optimization.html> · 교재 <https://manipulation.mit.edu/> | **임의 두 frame 사이 position/orientation 제약**을 IK·trajopt 에 직접 추가 → closed-chain/상대자세(공유물체) 협조를 수학적으로 표현 가능; 검증된 최적화 툴체인 | CPU, 실시간성·ROS 2 통합은 자작; 학습 곡선 높음; 산업 지원 없음 |
| **VAMP / pRRTC** (SIMD-CPU / GPU RRT-Connect) <https://github.com/KavrakiLab/vamp> · <https://arxiv.org/abs/2309.14545> · <https://arxiv.org/abs/2503.06757> | 초고속 계획(µs~ms); VAMP 는 GPU 불필요; **Baxter 14-DoF 양팔 벤치**(`bookshelf_tall_both_arms_*`) 지원 | 연구 코드; 궤적 시간 파라미터화·후처리 별도; ROS/산업 통합 없음 |
| **Crocoddyl (OCP/MPC, contact 모델)** <https://github.com/loco-3d/crocoddyl> | 접촉·힘을 포함한 whole-body OCP — force 작업까지 수식화 가능 | 연구용; 산업 안전 보증 없음; 이 셀 규모엔 과함 |
| **벤더 컨트롤러 협조 기능** — 예: ABB MultiMove(coordinated work object, `SyncMoveOn`, ISO 10218-1 에서 하나의 로봇으로 취급) <https://search.abb.com/library/Download.aspx?DocumentID=3HAC050961-001> | 인증·안전 체계 안에서 양팔 동기·협조 좌표계 제공; 공유물체 운반의 산업 표준 해법 | 벤더 종속; 충돌 회피 계획은 없음(경로는 사람이 티칭); PLAIF 스택(ROS 2) 과 이중 구조 |
| **학습 기반 양팔 정책** — ALOHA/ACT, Isaac Lab RL <https://tonyzhaozh.github.io/aloha/> · <https://isaac-sim.github.io/IsaacLab/> | 시연 데이터로 협조 동작 학습 | 정밀·반복·안전 보증 부재 → 산업 wrinkle 셀 부적합(제품화 R&D 트랙에서만 고려) |
| **반응형 per-arm 제어** — Isaac Sim RMPflow <https://docs.isaacsim.omniverse.nvidia.com/latest/manipulators/manipulators_rmpflow.html> | 실시간 회피·추종 | 전역 계획 아님, 팔별 독립; 양팔 협조는 별도 상위 로직 필요 |
| **현행 유지(수동 티칭)** | 검증됨, 추가 HW 없음 | seat 타입/레이아웃 변경마다 재티칭; 양팔 간섭은 사람이 눈으로 확인 |
| force/접촉(참고, cuRobo 와 독립) — ros2_control `admittance_controller`, FZI `cartesian_controllers`, 벤더 force mode <https://control.ros.org/master/doc/ros2_controllers/admittance_controller/doc/userdoc.html> · <https://github.com/fzi-forschungszentrum-informatik/cartesian_controllers> | 표준 ROS 2 컨트롤러 | polishing 루프는 이 층에서 유지 |

정리: **양팔 "동시 전이 + 상호 충돌 회피 + 부드러운 time-optimal 궤적"** 한정으로 cuRoboV2 가 가장 완성도 높은 OSS 선택지다. **공유물체 협조(closed-chain)** 는 Drake(수식화) 또는 벤더 MultiMove류(인증)가 맞고, **CPU-only 전이 자동화**라면 MoveIt 2(OMPL/Pilz)가 충분할 수 있다 — 이 비교를 PoC 산출물에 포함한다(§6).

## 5. Deliverable 3 — PLAIF fit

### 5.1 Hyundai wrinkle 셀 (safety-pose transition lens)

```
core_manipulation (orchestrator, route as string, seat_plans YAML)
   │  named pose / route 시작·종료 joint state + 현재 joint state + 월드(seat/fixture/fence/tool/반대팔)
   ▼
[신규] Transition Planner (cuRoboV2)  ── plan_cspace / plan_pose ──► JointTrajectory
   │  (A) 오프라인: 생성 → 독립 검증 → seat_plans 에 via-pose/trajectory 로 저장
   │  (B) 온라인: 서비스 호출 → 검증 게이트 → FollowJointTrajectory
   ▼
controller-manager (ros2_control JTC)  ── 기존과 동일하게 실행 (안전 계층 변경 없음)
```

꽂히는 곳
- **(A) 오프라인 생성(1차 권장):** 개발 워크스테이션(GPU)에서 seat 타입별 named pose 전이(home_left ↔ ready ↔ route_start/end ↔ drain)를 일괄 생성 → 독립 충돌 검사(MoveIt/FCL 또는 Isaac Sim) → `seat_plans` via-pose/궤적으로 저장. **셀 PC 에 GPU 불필요(Hongjin testbed / plant demo 제약 회피), 런타임 안전 논리는 "티칭된 pose" 와 동일.** 티칭 부담을 가장 직접적으로 줄인다.
- **(B) 온라인 재계획(2차, 조건부):** RealSense 로 seat pose/변형이 갱신될 때 `core_manipulation` 이 전이 계획 서비스를 호출. 셀 GPU(RTX PC 또는 Jetson Orin/Thor) 필요. 궤적은 CM 의 JTC 로 실행되어 로봇측 안전 기능은 그대로. 실패 시 fallback(재시도 → 사전 검증 via-pose 경로 → 정지) 필수(§3.1 SDAR).
- **양팔 전이:** 동시 이동 구간은 단일 tree 로 한 번에 계획(상호 충돌 자동 회피); 한 팔만 이동 구간은 팔별 인스턴스 + 반대팔 현재 자세를 월드에 반영.
- **부수 효과:** 배치 C-free IK 로 새 seat 타입 reachability 사전 점검, 기존 티칭 pose 의 충돌 마진 일괄 검사.

꽂히지 않는 곳
- polishing/steam route(taught + force/Z 보정) — 힘 제어·표면 추종 없음.
- `seat_plans` 시맨틱, core GUI Sequence, `core_manipulation` 상태기계 — cuRobo 는 planner 이며 task planner 가 아님.
- `controller-manager`/ros2_control, FastDDS/SHM — 무관.
- 동시 양팔 공유물체(closed-chain) 협조, MPC 실시간 반응 제어 — 각각 API 부재 / 안전 보증 없음.

전제·리스크
- 정확한 셀 모델: 양팔+fixture 단일 URDF, tool collision sphere, seat mesh(CAD/스캔)+캘리브레이션. 월드가 틀리면 "collision-free" 는 무의미.
- 로봇 드라이버가 외부 JointTrajectory 를 받는지(UR e-Series 는 cuMotion 예제로 검증; 타 벤더 확인 필요).
- 라이선스: V2 Apache-2.0 으로 상용 문제 해소; v0.7.x 코드/자산 혼용 금지.

### 5.2 Dual-arm 제품화 관점

- **역할 정의:** cuRoboV2 는 셀-공통 "collision-aware 모션 컴포넌트"(IK/reachability, 전이 계획, 양팔 동시 계획)로 재사용 가능하다. 셀마다 필요한 입력은 단일 tree URDF + sphere 정의(XRDF/yml) + scene 모델. **협조 로직(순서, 조건, 상태)은 PLAIF 오케스트레이터에 남는다** — cuRobo 는 coordination layer 가 아니다.
- **제품화에 가능한 것:** 양팔 동시 전이·회피, seat/작업물 변형에 대한 재계획, depth 기반 장애물 반영, 티칭 자동화 도구(오프라인 생성기).
- **제품화에 빠진 것(다른 스택 필요):** closed-chain/공유물체 협조(Drake 수식화 또는 벤더 MultiMove류), 팔별 비동기 계획(인스턴스 2개 + 자체 조율), force/접촉 작업(ros2_control/벤더), 형식적 안전 보증(cuRobo 는 cost 기반 — 셀 단위 ISO 10218-2 위험평가와 독립 검증기가 대체).
- **지원 경로 리스크:** NVIDIA 의 지원 제품은 Isaac ROS cuMotion 인데 단일 팔·MoveIt·Jazzy 종속 → dual-arm 은 OSS 직접 통합만 가능. V2 는 출시 5개월, API 월 단위 변동 → **버전 고정 + 내부 인터페이스 뒤에 격리**가 조건.
- **HW 리스크:** 셀당 Ampere+ GPU(Orin/Thor/RTX) 또는 오프라인 모드. 오프라인 모드는 제품 초기 단계에서 GPU BOM 을 회피하는 현실적 경로.

### 5.3 ROS 2 통합 구체안

- **노드:** rclpy 노드가 cuRoboV2 를 호스팅(별도 venv: torch + CUDA 12/13). 서비스/액션 예: `PlanTransition{goal: named_pose|joint_goal|tool_pose, arms: L|R|both, scene_rev}` → `trajectory_msgs/JointTrajectory`(12 joint 또는 팔별 6 joint). 오프라인 모드에서는 같은 코드가 CLI 로 `seat_plans` 를 생성.
- **실행:** 단일 12-joint JTC 면 동기 실행이 보장되고, 팔별 JTC 2개면 `FollowJointTrajectory` 시작 시각을 공통 stamp 로 맞춘다. UR scaled JTC 는 cuMotion 예제대로 `allow_nonzero_velocity_at_trajectory_end` 설정 확인. <https://control.ros.org/master/doc/ros2_controllers/joint_trajectory_controller/doc/userdoc.html>
- **검증 게이트:** cuRobo 결과를 독립 충돌 검사기(MoveIt planning scene/FCL, 또는 Isaac Sim)로 재검사 후 CM 에 전달. 실패 시 fallback 경로.
- **월드 입력:** 정적(CAD mesh/cuboid) 우선; 온라인은 RealSense depth → V2 TSDF/ESDF(live 예제) 또는 static scene 으로 대체.
- **distro:** cuRoboV2 단독은 Python ≥ 3.10 이면 Humble(22.04) 에서도 venv 로 가능; Isaac ROS 4.6 경로는 Jazzy/24.04 전제. FastDDS/SHM 은 영향 없음.

## 6. 판정과 실행 항목

**Conditional — 안전 자세·free-space 전이 자동화 PoC 는 Go; force polishing / 티칭 시퀀스 / 오케스트레이터 / 양팔 공유물체 협조 대체는 No-Go.**

1. **PoC 범위 고정:** seat 타입 1종, 전이 3~4개(home_left→ready, ready→route_start, route_end→drain, 양팔 동시 home 복귀). 오프라인 모드(A)만. 성공 기준: 독립 충돌 검사 100 % 통과, 최소 clearance ≥ 정한 마진(예 30 mm), 이동 시간 ≤ 현 티칭 경로, 동일 입력에 결정적 재생.
2. **비교 기준선 병행:** 같은 전이를 MoveIt 2(OMPL 또는 Pilz PTP)로도 생성해 품질·공정 비교. GPU 없이 충분하면 cuRobo 채택 근거가 약해진다 — 그 판단을 산출물로 남긴다.
3. **월드 모델 우선 투자:** 양팔+fixture URDF, tool sphere, seat mesh 파이프라인(CAD → 필요 시 RealSense 스캔 보정). 어느 planner 를 택해도 재사용된다.
4. **통합 방식:** cuRoboV2 Python 직접 사용(Isaac ROS cuMotion 은 단일 팔·MoveIt·Jazzy 종속으로 제외). 버전 고정, 내부 인터페이스 뒤에 격리. 출력은 `seat_plans` 호환 via-pose 또는 JointTrajectory 로 표준화.
5. **온라인 모드(B)와 제품화 확장은 PoC 결과 후 결정:** 셀 GPU 확보, fallback·검증 게이트, API 변동 대응 비용을 함께 평가.
6. **비목표 명시:** force/Z, route 시맨틱, 오케스트레이션, 공유물체 협조는 이번 라운드에서 cuRobo 로 건드리지 않는다고 팀에 고지. 공유물체 협조가 제품 요구로 올라오면 Drake/벤더 협조 기능을 별도 평가.

## 7. 출처

- cuRobo 레거시 문서(v0.7.6) <https://curobo.org/> · Isaac Sim/MPC/Multi-Arm 예제 <https://curobo.org/get_started/2b_isaacsim_examples.html> · Constrained planning <https://curobo.org/advanced_examples/3_constrained_planning.html> · World collision <https://curobo.org/get_started/2c_world_collision.html> · Python 예제 <https://curobo.org/get_started/2a_python_examples.html>
- cuRobo 저장소 <https://github.com/NVlabs/curobo> · v0.8.0 릴리스 <https://github.com/NVlabs/curobo/releases/tag/v0.8.0> · LICENSE <https://github.com/NVlabs/curobo/blob/main/LICENSE> · v0.7.8 <https://github.com/NVlabs/curobo/tree/v0.7.8> · 레거시 dual_ur10e.yml <https://raw.githubusercontent.com/NVlabs/curobo/v0.7.8/src/curobo/content/configs/robot/dual_ur10e.yml>
- cuRoboV2 소스/문서: MotionPlanner <https://github.com/NVlabs/curobo/blob/main/curobo/_src/motion/motion_planner.py> · motion_planning 예제 <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/motion_planning.py> · reactive_control 예제 <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/reactive_control.py> · live RealSense mapping+MPC <https://github.com/NVlabs/curobo/blob/main/curobo/examples/reference/live_volumetric_mapping_mpc.py> · dual_ur10e.yml(V2) <https://github.com/NVlabs/curobo/blob/main/curobo/content/configs/robot/dual_ur10e.yml> · AttachmentManager <https://github.com/NVlabs/curobo/blob/main/curobo/_src/collision/attachment_manager.py> · Build robot model <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/build_robot_model.rst> · 벤치마크 <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst> · 설치 <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/installation.rst> · 뉴스 <https://github.com/NVlabs/curobo/blob/main/docs/news.rst>
- 논문: cuRoboV2 <https://arxiv.org/abs/2603.05493> · cuRobo(2023) <https://arxiv.org/abs/2310.17274> · SDAR dual-arm TAMP(ICRA 2026) <https://arxiv.org/abs/2512.08206>, <https://github.com/arc-l/dual-arm> · pRRTC <https://arxiv.org/abs/2503.06757> · VAMP <https://arxiv.org/abs/2309.14545>, <https://github.com/KavrakiLab/vamp> · cuTAMP <https://arxiv.org/abs/2411.11833>
- 이슈/토론: dual-arm API 답변 <https://github.com/NVlabs/curobo/issues/349> · 공유 torso 수렴 실패 <https://github.com/NVlabs/curobo/discussions/337> · 제2 로봇 장애물 <https://github.com/NVlabs/curobo/discussions/345> · multi-arm attach 버그 <https://github.com/NVlabs/curobo/issues/553> · cuMotion 다중 planning group <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion/issues/10> · NVIDIA 포럼 "two manipulators 미지원" <https://forums.developer.nvidia.com/t/dual-arm-robot-use-isaac-ros-cumotion-with-erroe/336266>
- Isaac ROS: cuMotion 개요 <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/index.html> · planner node API <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion/index.html> · MoveIt plugin quickstart <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion_moveit/index.html> · Isaac for Manipulation <https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_manipulation/index.html> · Pick-and-place 튜토리얼(ghost voxel) <https://nvidia-isaac-ros.github.io/v/release-4.0/reference_workflows/isaac_for_manipulation/tutorials/pick_and_place/tutorial_pick_and_place.html> · Bring Your Own Robot(XRDF) <https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_manipulation/tutorials/tutorial_bring_your_own_robot.html> · Manipulation 개념 <https://nvidia-isaac-ros.github.io/concepts/manipulation/index.html> · nvblox <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_nvblox/index.html> · 저장소 <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion>
- 대안: MoveIt move_group(합친 group) <https://moveit.picknik.ai/main/doc/examples/move_group_interface/move_group_interface_tutorial.html> · OMPL constrained planning <https://moveit.picknik.ai/main/doc/how_to_guides/using_ompl_constrained_planning/ompl_constrained_planning.html> · MoveIt Task Constructor <https://github.com/moveit/moveit_task_constructor>, <https://moveit.picknik.ai/main/doc/tutorials/pick_and_place_with_moveit_task_constructor/pick_and_place_with_moveit_task_constructor.html> · Hybrid Planning <https://moveit.picknik.ai/main/doc/concepts/hybrid_planning/hybrid_planning.html> · Pilz <https://moveit.picknik.ai/main/doc/how_to_guides/pilz_industrial_motion_planner/pilz_industrial_motion_planner.html> · MoveIt Servo <https://moveit.picknik.ai/main/doc/examples/realtime_servo/realtime_servo_tutorial.html> · Tesseract <https://tesseract-docs.readthedocs.io/en/latest/>, <https://github.com/tesseract-robotics/tesseract> · noether <https://github.com/ros-industrial/noether> · descartes_light <https://github.com/swri-robotics/descartes_light> · Scan-N-Plan <https://github.com/ros-industrial-consortium/scan_n_plan_workshop> · Drake <https://drake.mit.edu/>, IK <https://drake.mit.edu/doxygen_cxx/classdrake_1_1multibody_1_1_inverse_kinematics.html>, KinematicTrajectoryOptimization <https://drake.mit.edu/doxygen_cxx/classdrake_1_1planning_1_1trajectory__optimization_1_1_kinematic_trajectory_optimization.html>, 교재 <https://manipulation.mit.edu/> · Crocoddyl <https://github.com/loco-3d/crocoddyl> · ABB MultiMove 매뉴얼 <https://search.abb.com/library/Download.aspx?DocumentID=3HAC050961-001> · ALOHA <https://tonyzhaozh.github.io/aloha/> · Isaac Lab <https://isaac-sim.github.io/IsaacLab/> · Isaac Sim RMPflow <https://docs.isaacsim.omniverse.nvidia.com/latest/manipulators/manipulators_rmpflow.html> · ros2_control JTC <https://control.ros.org/master/doc/ros2_controllers/joint_trajectory_controller/doc/userdoc.html>, admittance <https://control.ros.org/master/doc/ros2_controllers/admittance_controller/doc/userdoc.html> · FZI cartesian_controllers <https://github.com/fzi-forschungszentrum-informatik/cartesian_controllers>
