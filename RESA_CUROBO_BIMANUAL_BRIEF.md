# RESA 브리프 — NVIDIA cuRobo × PLAIF Hyundai wrinkle (`pj_hyundai_wrinkle`) 적용성

작성일: 2026-09-09 · 대상: Resa / Orche · 상태: research brief (코드 변경 없음)

## 0. 결론 (한 줄)

**Conditional.** cuRobo(V2, Apache-2.0)는 *수동으로 티칭하던 안전/전이 자세(home / ready / drain, `home_left`류 named pose)와 그 사이의 free-space 전이*를 seat·fence·tool·반대팔 장애물 기준으로 **자동 생성·재계획하는 PoC 가치가 있다.** 반면 **force polishing, Z 보정, seat_plan 시맨틱, `core_manipulation` 오케스트레이션, 동시 양팔 공유물체(closed-chain) 협조 교체는 No-Go** — cuRobo 범위 밖이다.

## 1. 질문 재정의 (re-lens)

- 원 질문: "cuRobo가 dual-arm 협조에 좋은가?" → **이 셀에서는 잘못된 질문.** 이 셀의 본체는 seat 위 steam/polish 경로(taught route + force/Z 보정)이며, 현재 스택에는 motion planner가 없어 **안전/전이 자세를 사람이 손으로 티칭**해 왔다(TeachingPendant 경로는 제거, 시퀀스는 core GUI Sequence + `seat_plans` YAML).
- 재정의: **"장애물(seat, fixture, fence, tool, 반대팔)이 있는 상태에서 home/ready/drain ↔ route 시작·종료점 사이의 collision-free 전이를 cuRobo가 생성/재계획하여 티칭 부담을 줄일 수 있는가?"**
- 명시적으로 범위 밖(그대로 유지): polishing route, force/Z 보정 루프, `seat_plans` 시맨틱, `core_manipulation` 오케스트레이션, `controller-manager`(ros2_control) 실행 계층, 동시 양팔 공유물체 협조.

## 2. cuRobo 현황과 이 셀에 관련된 capability / limit (2026-09 기준)

### 2.1 무엇인가

- GPU(CUDA/PyTorch/Warp) 병렬 로봇 모션 라이브러리: FK/IK(배치, collision-free), 충돌 검사(cuboid/mesh/depth→ESDF), trajectory optimization, graph planner, MotionGen(IK+graph+trajopt), MPC(MPPI 기반). 레거시 문서: <https://curobo.org/>
- **cuRoboV2 = v0.8.0 (2026-04-18), Apache-2.0 로 공개.** "Major refactor, breaks most existing API"; v1 API가 필요하면 `v0.7.8` 태그 고정. 레거시 문서는 "business/commercial use 는 cuRoboV2 사용" 명시. 릴리스: <https://github.com/NVlabs/curobo/releases/tag/v0.8.0> · LICENSE: <https://github.com/NVlabs/curobo/blob/main/LICENSE> · v1 고정: <https://github.com/NVlabs/curobo/tree/v0.7.8>
- V2 기술 보고서(arXiv 2603.05493): B-spline trajopt + torque limit(RNEA 역동역학), nvblox 의존 제거한 GPU-native TSDF/ESDF, 고DoF(bimanual/humanoid) 스케일링. <https://arxiv.org/abs/2603.05493> · v1 보고서: <https://arxiv.org/abs/2310.17274>
- 설치 요건(V2): Ubuntu ≥ 20.04, **NVIDIA GPU > Turing(즉 Ampere 이상), VRAM ≥ 4 GB, driver ≥ 580.65.06**, Python ≥ 3.10, `pip install .[cu12|cu13(-torch)]`. <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/installation.rst>
- 2026-06-15 업데이트: **live RealSense RGB-D mapping + MPC** 예제, LiDAR TSDF. <https://github.com/NVlabs/curobo/blob/main/docs/news.rst> · 예제: <https://github.com/NVlabs/curobo/blob/main/curobo/examples/reference/live_volumetric_mapping_mpc.py>

### 2.2 이 셀 관점 capability 표

| 항목 | cuRobo 제공 (근거) | wrinkle 셀 의미 |
|---|---|---|
| 충돌 월드 | cuboid / mesh / depth→ESDF(V2 내장 TSDF/ESDF; v1은 nvblox). <https://curobo.org/get_started/2c_world_collision.html>, V2 paper §5 | seat(mesh: CAD 또는 RealSense 스캔) + fixture/fence(cuboid) + tool(collision sphere) 모델링 가능. **월드 정확도가 성패를 결정** |
| Free-space 전이 계획 | `MotionPlanner.plan_cspace(goal_joint, current)` — joint-space 목표로 collision-free 궤적; `plan_pose(GoalToolPose, current)` — pose 목표; 결과는 `interpolation_dt` 로 보간된 joint trajectory. <https://github.com/NVlabs/curobo/blob/main/curobo/_src/motion/motion_planner.py>, <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/motion_planning.py> | **named pose(home/ready/drain) 사이 전이를 티칭 대신 생성**하는 데 정확히 맞는 API. joint-space 목표라 기존 named pose 정의(joint 값)를 그대로 목표로 쓸 수 있음 |
| 계획 시간·품질 | V2 벤치(RTX 6000 Ada, Franka 2,600문제): 성공 99.73 %, plan time 평균 38 ms(3 kg torque limit 포함 52 ms). <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst>; 레거시: UR10 on Jetson Orin 100 ms 이내 <https://curobo.org/> | 오프라인 생성이면 시간은 무의미; **온라인 재계획(seat 변형/장애물 변화)도 수십~수백 ms 로 가능** |
| Dual-arm | 양팔을 **하나의 kinematic tree(단일 URDF)** 로 모델링, `tool_frames: ["tool1","tool0"]` 각 팔 목표 동시 지정(`dual_ur10e.yml`). V2 IK 벤치: dual_ur10e IK 6.1 ms / collision-free IK 15.6 ms, 성공 99.2 %. <https://github.com/NVlabs/curobo/blob/main/curobo/content/configs/robot/dual_ur10e.yml>, <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst> | 전이 중 **양팔 상호 충돌 회피는 자연스럽게 포함**(같은 최적화 문제). 한 팔만 움직일 때는 아래 limit 참조 |
| 제약 계획 | v1 `PoseCostMetric`(축 고정·접근벡터), V2 `update_tool_pose_criteria`. <https://curobo.org/advanced_examples/3_constrained_planning.html> | 노즐 방향 유지 등 전이 구간 제약에 유용. **표면 추종(polishing path)용은 아님** |
| Reactive/MPC | v1 MPPI 500 Hz(RTX 4090) "experimental, no safety guarantees"; V2 `ModelPredictiveControl.update_goal_tool_poses`, whole-body. <https://curobo.org/get_started/2b_isaacsim_examples.html>, <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/reactive_control.py> | 셀 PoC 범위 밖(안전 보증 없음). 전이 자동화에는 오프라인/온디맨드 `plan_*` 로 충분 |
| 부착물 | V2 `AttachmentManager` — 임의 링크에 물체 sphere 부착(v1 은 기본 EE 만 지원하던 버그 #553). <https://github.com/NVlabs/curobo/blob/main/curobo/_src/collision/attachment_manager.py>, <https://github.com/NVlabs/curobo/issues/553> | steam 노즐 / polishing head 를 각 팔 tool 로 부착해 충돌 검사 |

### 2.3 이 셀에 걸리는 limit (정직하게)

1. **힘 제어 없음.** cuRobo 는 운동학적 궤적 생성기다. impedance/admittance, 접촉력, Z 보정은 어떤 버전에도 없다(V2 RNEA 는 torque *limit* 검사용). → polishing 루프는 그대로 CM/벤더 force control.
2. **표면 경로 추종 없음.** MoveIt Pilz `LIN/CIRC`+blending, Descartes/noether 류 toolpath 추종 primitive 가 없다. 점→점 최적화(+goalset, grasp 3단계)만 있다. → seat 위 route 생성/추종 도구가 아니다.
3. **Dual-arm 은 "양팔 동시 목표" 모델.** NVIDIA 답변: "dual arm motion planning where **both arms need to have a target**. We don't directly support having one arm static while the other arm is moving as an API. You can achieve this by using two separate instances… **not integrated with MoveIt**." <https://github.com/NVlabs/curobo/issues/349> · 레거시 문서: "Multi-Arm motion planning is **experimental** and does not work as well as single arm planning." <https://curobo.org/get_started/2b_isaacsim_examples.html> · 공유 torso 양팔에서 수렴 실패 보고와 IK iteration 상향 권고: <https://github.com/NVlabs/curobo/discussions/337>
4. **Closed-chain / 상대자세 제약 없음.** 두 tool 사이 상대 transform 을 궤적 전체에서 강제하는 API 없음(목표 시점 pose 만). → 공유물체 동시 협조는 No-Go.
5. **반대팔을 동적 장애물로 넣는 표준 경로 없음**(discussion #345 미답변). 실무 해법은 (a) 단일 tree 로 양팔 동시 계획, 또는 (b) 팔별 planner 인스턴스 + 반대팔 현재 자세를 월드에 반영. <https://github.com/NVlabs/curobo/discussions/345>
6. **ROS 2 제품 경로(Isaac ROS cuMotion)는 단일 매니퓰레이터.** MoveIt planning group 이 2개면 "'JointX' is not in list" 실패, NVIDIA: "We currently don't support two manipulators"; XRDF `tool_frames` 첫 항목만 사용. <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion/issues/10>, <https://forums.developer.nvidia.com/t/dual-arm-robot-use-isaac-ros-cumotion-with-erroe/336266>
7. **GPU 의존 + 플랫폼 조건.** cuRoboV2 단독: Ampere+ GPU, driver ≥ 580. Isaac ROS 4.6.0(2026-08-18): **ROS 2 Jazzy / Ubuntu 24.04 / CUDA 13.2+ / driver 595+**, Jetson Thor·Orin(JetPack 7.2), DGX Spark. <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/index.html> → 스택이 Humble/22.04 면 cuMotion 경로는 OS/distro 불일치.
8. **문헌상 dual-arm 신뢰성.** ICRA 2026 SDAR: "cuRobo can compute nice motions for dual-arm systems for **certain pre-specified start/goal configurations**… doing so reliably for **random start/goal** remains difficult"; fallback 없이 쓰면 성공률 49 % / 11 %, 저자들은 cuRobo IK+MotionGen 위에 rule-based untangling fallback 을 얹어 100 % 달성. <https://arxiv.org/abs/2512.08206>, <https://github.com/arc-l/dual-arm> → **PoC 에서도 fallback(재시도·seed 변경·via-pose)과 검증 게이트가 필수.**
9. **깊이 기반 장애물의 ghost voxel** 위험은 NVIDIA 문서도 인정(nvblox 비활성 + MoveIt scene file 기반 정적 planning scene 을 대안으로 제시). <https://nvidia-isaac-ros.github.io/v/release-4.0/reference_workflows/isaac_for_manipulation/tutorials/pick_and_place/tutorial_pick_and_place.html>

## 3. 대안 비교 (ROS 2 산업 셀 맥락)

| 후보 | 장점 | 단점 / 이 셀 판단 |
|---|---|---|
| **cuRoboV2 Python 직접 통합**(rclpy 노드 또는 오프라인 스크립트) | Apache-2.0; `plan_cspace` 로 named pose 전이 생성; 양팔 단일 tree; ESDF(RealSense) 가능; 부드러운 time-optimal 궤적; 배치 IK 로 reachability 검토 | GPU 필요; ROS 인터페이스 자작; dual-arm "experimental"; fallback 자작 |
| **Isaac ROS cuMotion**(MoveIt 2 plugin, action `cumotion/move_group`) | 제품화·문서·UR 예제; nvblox 연동; `time_dilation_factor`, `interpolation_dt` 파라미터 | **MoveIt 2 필수**(현 스택 미사용), **단일 매니퓰레이터만**, Jazzy/24.04 + Isaac ROS 환경 종속. UR 예제는 `scaled_joint_trajectory_controller` 의 `allow_nonzero_velocity_at_trajectory_end=true` 요구. <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion_moveit/index.html>, <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion/index.html> |
| **MoveIt 2 (OMPL/CHOMP) + Pilz Industrial Motion Planner** | CPU 만으로 동작; PTP/LIN/CIRC + blending 은 산업 전이에 익숙; planning group 별 팔 분리 자연스러움 | 스택에 MoveIt 도입 비용; 양팔 동시 최적화 약함; 궤적 품질은 후처리 의존. <https://moveit.picknik.ai/main/doc/how_to_guides/pilz_industrial_motion_planner/pilz_industrial_motion_planner.html> |
| **VAMP / pRRTC**(SIMD-CPU / GPU sampling planner) | 단일 팔 계획 시간은 cuRobo v1 보다 훨씬 빠름(pRRTC 논문: Panda 에서 pRRTC 가 cuRobo 대비 128×, VAMP-RRTC 는 그보다 3× 더 빠름). VAMP 는 GPU 불필요 | 연구 코드, ROS 통합·산업 지원 없음; 궤적 후처리 필요. <https://arxiv.org/abs/2503.06757>, <https://arxiv.org/abs/2309.14545> |
| **Tesseract/TrajOpt + noether/Descartes**(ROS-Industrial) | 표면 가공(Scan-N-Plan) 계보 — mesh 위 raster toolpath 생성·추종에 맞음 | 이 셀의 route 는 이미 티칭+force 로 해결; 전이 자동화 목적엔 과함. <https://github.com/tesseract-robotics/tesseract>, <https://github.com/ros-industrial/noether>, <https://github.com/swri-robotics/descartes_light> |
| **현행 유지(수동 티칭)** | 검증된 방식, 추가 HW 없음 | seat 타입/셀 레이아웃 변경마다 재티칭; 양팔 간섭은 사람이 눈으로 확인 |
| force/접촉(참고) | ros2_control `admittance_controller`, FZI `cartesian_controllers`, 벤더 force mode | cuRobo 와 무관하게 유지. <https://control.ros.org/master/doc/ros2_controllers/admittance_controller/doc/userdoc.html>, <https://github.com/fzi-forschungszentrum-informatik/cartesian_controllers> |

요약: **전이 자동화 한 가지 목적**에 대해 진짜 경쟁자는 "MoveIt 2 + Pilz/OMPL(CPU)" 이다. cuRobo 의 차별점은 (i) 양팔을 하나의 최적화로 다뤄 상호 간섭을 함께 해소, (ii) time-optimal·jerk 최소 궤적, (iii) RealSense→ESDF 로 seat 형상 변화 반영. 그 대가는 GPU 와 자작 통합이다.

## 4. Changjun/PLAIF wrinkle 스택과의 접점

### 4.1 꽂히는 곳 (plug-in)

```
core_manipulation (orchestrator, route as string, seat_plans YAML)
   │  named pose / route 시작·종료 joint state + 현재 joint state + 월드(seat/fixture/fence/tool/반대팔)
   ▼
[신규] Transition Planner (cuRoboV2)  ── plan_cspace / plan_pose ──► JointTrajectory
   │  (A) 오프라인: 생성 → 검증 → seat_plans 에 via-pose/trajectory 로 저장
   │  (B) 온라인: 서비스 호출 → 검증 게이트 → FollowJointTrajectory
   ▼
controller-manager (ros2_control JTC)  ── 기존과 동일하게 실행 (안전 계층 변경 없음)
```

- **(A) 오프라인 생성 모드(1차 권장):** 개발 워크스테이션(GPU)에서 seat 타입별 named pose 전이(home_left ↔ ready ↔ route_start/end ↔ drain)를 일괄 생성하고, 독립 충돌 검사(예: MoveIt/FCL 또는 Isaac Sim)로 재검증한 뒤 `seat_plans` 에 via-pose 또는 궤적으로 넣는다. **셀 PC 에 GPU 가 없어도 되고(Hongjin testbed / plant demo 제약 회피), 런타임 안전성 논리는 "티칭된 pose" 와 동일하게 유지**된다. 이것이 티칭 부담을 가장 직접적으로 줄인다.
- **(B) 온라인 재계획 모드(2차, 조건부):** seat pose/변형이 카메라(RealSense)로 갱신될 때 `core_manipulation` 이 전이 계획 서비스를 호출. 셀에 Ampere+ GPU(RTX PC 또는 Jetson Orin/Thor) 필요. 궤적은 CM 의 JTC 로 실행되므로 로봇측 안전 기능(속도 스케일링, 보호정지)은 그대로. 계획 실패 시 fallback(재시도 → 사전 검증된 via-pose 경로 → 정지)이 반드시 있어야 함(§2.3-8).
- **Dual-arm 전이:** 양팔 동시 이동 구간은 단일 tree(`tool_frames` 2개, 또는 `plan_cspace` 로 12-joint 목표)로 한 번에 계획 → 상호 충돌 자동 회피. 한 팔만 이동 구간은 팔별 planner 인스턴스 + 반대팔 현재 자세를 월드 장애물로 반영(§2.3-3,5).
- **부수 효과:** 배치 collision-free IK 로 새 seat 타입에 대한 reachability/충돌 사전 점검, 기존 티칭 pose 의 충돌 마진 일괄 검사.

### 4.2 꽂히지 않는 곳 (변경 없음)

- polishing/steam route 자체(taught + force/Z 보정) — cuRobo 에 힘 제어·표면 추종 없음.
- `seat_plans` 시맨틱, core GUI Sequence, `core_manipulation` 상태기계/오케스트레이션 — cuRobo 는 planner 이며 task planner 가 아님.
- `controller-manager`/ros2_control, FastDDS/SHM 계층 — 무관.
- 동시 양팔 공유물체(closed-chain) 협조 — 상대자세 제약 API 부재.
- MPC 기반 실시간 반응 제어 — "no safety guarantees", 이 셀에 불필요.

### 4.3 전제·리스크 체크리스트

- 정확한 셀 모델: 양팔+fixture 단일 URDF, tool collision sphere, seat mesh(CAD/스캔)와 캘리브레이션. 월드가 틀리면 "collision-free" 는 무의미.
- 로봇 벤더 드라이버가 JTC 로 외부 궤적을 받는지(UR e-Series 는 cuMotion 예제로 검증됨; 타 벤더는 확인 필요).
- ROS distro: cuRoboV2 단독은 Python ≥ 3.10 이면 Humble(22.04)에서도 별도 venv 로 가능; Isaac ROS 경로는 Jazzy/24.04 전제.
- 라이선스: V2 Apache-2.0 으로 상용 문제 해소(v0.7.x 자산은 NVIDIA 독점 고지 — v1 코드/자산 혼용 금지).

## 5. 판정

**Conditional — "안전 자세·free-space 전이 자동화 PoC 는 Go, polishing/티칭 시퀀스/오케스트레이터 대체는 No-Go."**
근거: 이 셀에서 planner 부재로 발생한 실제 비용은 *전이 자세 수동 티칭과 양팔 간섭 확인* 이며, 그 문제는 cuRoboV2 의 `plan_cspace`/단일 tree dual-arm/ESDF 가 정확히 겨냥하는 범위다. 반면 셀의 본체(force polishing, route 시맨틱, 오케스트레이션)는 cuRobo 가 다루지 않는다.

실행 항목:

1. **PoC 범위 고정:** seat 타입 1종, 전이 3~4개(home_left→ready, ready→route_start, route_end→drain, 양팔 동시 home 복귀). 오프라인 모드(A)만. 성공 기준: 독립 충돌 검사 100 % 통과, 최소 clearance ≥ 정해진 마진(예: 30 mm), 이동 시간 ≤ 현 티칭 경로, 동일 입력에 대해 결정적 재생.
2. **비교 기준선 병행:** 같은 전이를 MoveIt 2(OMPL 또는 Pilz PTP)로도 생성해 품질·공정 비교. GPU 없이 충분하면 cuRobo 채택 근거가 약해진다 — 그 판단을 PoC 산출물로 남긴다.
3. **월드 모델 우선 투자:** 양팔+fixture URDF, tool sphere, seat mesh 파이프라인(CAD → 필요 시 RealSense 스캔 보정). 이 자산은 어느 planner 를 택해도 재사용된다.
4. **통합 방식:** cuRoboV2 Python 직접 사용(Isaac ROS cuMotion 은 단일 팔·MoveIt·Jazzy 종속으로 제외). 출력은 `seat_plans` 호환 via-pose 또는 JointTrajectory 로 표준화.
5. **온라인 모드(B)는 PoC 결과 후 결정:** 셀 GPU(Jetson Orin/Thor 또는 RTX) 확보와 fallback·검증 게이트 설계가 선행 조건.
6. **명시적 비목표 공유:** force/Z, route 시맨틱, 오케스트레이션, 공유물체 협조는 이번 라운드에서 cuRobo 로 건드리지 않는다고 팀에 고지.

## 6. 출처

- cuRobo 레거시 문서(v0.7.6) <https://curobo.org/> · Isaac Sim/MPC/Multi-Arm 예제 <https://curobo.org/get_started/2b_isaacsim_examples.html> · Constrained planning <https://curobo.org/advanced_examples/3_constrained_planning.html> · World collision <https://curobo.org/get_started/2c_world_collision.html> · Python 예제 <https://curobo.org/get_started/2a_python_examples.html>
- cuRobo 저장소 <https://github.com/NVlabs/curobo> · v0.8.0 릴리스 <https://github.com/NVlabs/curobo/releases/tag/v0.8.0> · LICENSE <https://github.com/NVlabs/curobo/blob/main/LICENSE> · v0.7.8 <https://github.com/NVlabs/curobo/tree/v0.7.8> · 레거시 dual_ur10e.yml <https://raw.githubusercontent.com/NVlabs/curobo/v0.7.8/src/curobo/content/configs/robot/dual_ur10e.yml>
- cuRoboV2 소스/문서: MotionPlanner <https://github.com/NVlabs/curobo/blob/main/curobo/_src/motion/motion_planner.py> · motion_planning 예제 <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/motion_planning.py> · reactive_control 예제 <https://github.com/NVlabs/curobo/blob/main/curobo/examples/getting_started/reactive_control.py> · live RealSense mapping+MPC <https://github.com/NVlabs/curobo/blob/main/curobo/examples/reference/live_volumetric_mapping_mpc.py> · dual_ur10e.yml(V2) <https://github.com/NVlabs/curobo/blob/main/curobo/content/configs/robot/dual_ur10e.yml> · AttachmentManager <https://github.com/NVlabs/curobo/blob/main/curobo/_src/collision/attachment_manager.py> · 벤치마크 <https://github.com/NVlabs/curobo/blob/main/docs/reference/benchmarks.rst> · 설치 <https://github.com/NVlabs/curobo/blob/main/docs/getting-started/installation.rst> · 뉴스 <https://github.com/NVlabs/curobo/blob/main/docs/news.rst>
- 논문: cuRoboV2 <https://arxiv.org/abs/2603.05493> · cuRobo(2023) <https://arxiv.org/abs/2310.17274> · SDAR dual-arm TAMP(ICRA 2026) <https://arxiv.org/abs/2512.08206>, <https://github.com/arc-l/dual-arm> · pRRTC <https://arxiv.org/abs/2503.06757> · VAMP <https://arxiv.org/abs/2309.14545> · cuTAMP <https://arxiv.org/abs/2411.11833>
- 이슈/토론: dual-arm API 답변 <https://github.com/NVlabs/curobo/issues/349> · 공유 torso 수렴 실패 <https://github.com/NVlabs/curobo/discussions/337> · 제2 로봇 장애물 <https://github.com/NVlabs/curobo/discussions/345> · multi-arm attach 버그 <https://github.com/NVlabs/curobo/issues/553> · cuMotion 다중 planning group <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion/issues/10> · NVIDIA 포럼 "two manipulators 미지원" <https://forums.developer.nvidia.com/t/dual-arm-robot-use-isaac-ros-cumotion-with-erroe/336266>
- Isaac ROS: cuMotion 개요 <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/index.html> · planner node API <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion/index.html> · MoveIt plugin quickstart <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_cumotion/isaac_ros_cumotion_moveit/index.html> · Isaac for Manipulation <https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_manipulation/index.html> · Bring Your Own Robot(XRDF) <https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_manipulation/tutorials/tutorial_bring_your_own_robot.html> · Manipulation 개념 <https://nvidia-isaac-ros.github.io/concepts/manipulation/index.html> · nvblox <https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_nvblox/index.html> · 저장소 <https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_cumotion>
- 대안: MoveIt Pilz <https://moveit.picknik.ai/main/doc/how_to_guides/pilz_industrial_motion_planner/pilz_industrial_motion_planner.html> · MoveIt Servo <https://moveit.picknik.ai/main/doc/examples/realtime_servo/realtime_servo_tutorial.html> · ros2_control admittance <https://control.ros.org/master/doc/ros2_controllers/admittance_controller/doc/userdoc.html> · FZI cartesian_controllers <https://github.com/fzi-forschungszentrum-informatik/cartesian_controllers> · Tesseract <https://github.com/tesseract-robotics/tesseract> · noether <https://github.com/ros-industrial/noether> · descartes_light <https://github.com/swri-robotics/descartes_light> · Scan-N-Plan <https://github.com/ros-industrial-consortium/scan_n_plan_workshop>
