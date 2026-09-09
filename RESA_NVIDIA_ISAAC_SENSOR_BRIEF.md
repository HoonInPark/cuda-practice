# NVIDIA Isaac / MCAP 브리프 — 창준 설계에 꽂기

조사일: 2026-09-09  
범위: 창준 작성 Notion 5페이지만을 설계 베이스로 함. 그 외 PLAIF 문서는 사용하지 않음.

설계 베이스:
- 수집기 설계 — https://app.notion.com/p/3d5ba69e7a8780189027e109454dc9ac
- 파이프라인 조사 — https://app.notion.com/p/3b1ba69e7a8780a3b19cd821ef4c7796
- 파이프라인 설계 — https://app.notion.com/p/3c0ba69e7a878024858acf96ebb7496b
- Bronze 디렉터리 — https://app.notion.com/p/3c1ba69e7a87800089f2e5a4248563ae
- 주름 이미지 수집 인수인계 — https://app.notion.com/p/387ba69e7a87801aa637ee5686cc7ce0

---

## A. 추천 레포/문서 (6)

1. **Isaac ROS GR00T Reference Workflow**  
   파이프라인 설계가 명시한 NVIDIA 경로(MCAP rosbag → LeRobot → GR00T)와, 조사 문서의 closed loop(수집 → 관리/정제 → 학습/재현 → 재배포)가 한 장에 붙어 있는 공식 E2E.  
   **출처:** https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/tutorials/tutorials.html

2. **ros2/rosbag2 + ros-tooling/rosbag2_storage_mcap**  
   수집기 코어가 몰라야 하는 “저장 형식/경로”의 ROS2 어댑터. 로봇 계층의 CT=세션 동안 MCAP append(RAM/SSD→HDD)와 Bronze의 `.mcap` + `metadata.yaml`이 이 두 레포의 산출물이다.  
   **출처:** https://github.com/ros2/rosbag2  
   **출처:** https://github.com/ros-tooling/rosbag2_storage_mcap

3. **`isaac_ros_unitree_g1_recorder` (Isaac ROS Physical AI)**  
   추상 수집기가 아님. ROS2 어댑터 레퍼런스: 세션 디렉터리에 MCAP를 이어 쓰고, `camera_info`(intrinsics)를 bag에 넣으며, start/stop/cancel로 제어 루프와 녹화 루프를 분리한다.  
   **출처:** https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_physical_ai/isaac_ros_unitree_g1_recorder/index.html  
   **레포:** https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_physical_ai

4. **`isaac_ros_mcap_lerobot_converter`**  
   처리 계층의 공식 훅: Bronze 세션(`metadata.yaml` + bag)을 읽어 시간 정렬된 LeRobot(`meta/`·`data/`·`videos/`)으로 보낸다. Gold = LeRobot이라는 Bronze 문서 정의와 맞는다. 변환은 수집 루프 밖(호스트 Python, ROS 불필요).  
   **출처:** https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_data_tools/isaac_ros_mcap_lerobot_converter/index.html  
   **튜토리얼:** https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/tutorials/tutorial_convert.html  
   **레포:** https://github.com/NVIDIA-ISAAC-ROS/isaac_ros_data_tools

5. **NVIDIA/Isaac-GR00T (N1.7)**  
   학습/재현/재배포 계층: LeRobot(+ `modality.json`)을 받아 fine-tune하고 replay/deploy한다. 파이프라인 설계의 “LeRobot → 가중치 → 현장 재배포”에 대응.  
   **출처:** https://github.com/NVIDIA/Isaac-GR00T  
   **Isaac ROS fine-tune:** https://nvidia-isaac-ros.github.io/reference_workflows/isaac_for_physical_ai/tutorials/tutorial_finetune.html

6. **Isaac ROS RealSense Setup**  
   주름 인수인계의 RealSense(IR/컬러, exposure)와 Bronze `config/camera.yaml`(intrinsics·센서 config)을 맞출 공식 핀. bag의 `camera_info`와 `versions/firmware.yaml`에 그대로 적는다.  
   **출처:** https://nvidia-isaac-ros.github.io/getting_started/sensors/realsense_setup.html

---

## B. 주름/수집기 설계 액션

1. **수집기 코어는 Isaac 패키지를 품지 말 것.** 도메인 규칙만: raw 불변, timestamp 필수, 제어 주기와 별도 루프, back-pressure 없음. ros2 vs march, dump vs DDS, `.mcap` vs `.h5`, 로컬 vs HTTPS는 어댑터. 주름은 ROS2 어댑터, 양산은 다른 어댑터.
2. **ROS2 어댑터 = rosbag2 MCAP append.** CT=세션 동안 RAM/SSD에 이어 쓰고 종료 후 HDD → USB/HTTP NAS. 산출은 Bronze 계약: `{session_id}_0.mcap` + rosbag2 `metadata.yaml` + `session_manifest.yaml`.
3. **Bronze는 절대 삭제/덮어쓰기·압축/변환 금지.** Isaac recorder의 H.264-in-bag은 Bronze “변환 없이 저장”과 충돌한다. Bronze에는 raw(+ `camera_info`)를 두고, H.264는 Silver/전송 쪽으로만.
4. **NAS 경로는 Hive `Key=value`.** `/plaif_data/bronze/domain=wrinkle/site=.../session_id=.../` 아래에 `config/camera.yaml`(intrinsics)과 `versions/firmware.yaml`을 같이 둔다. converter가 기대하는 `metadata.yaml` 레이아웃과 맞출 것.
5. **처리 계층만 `mcap-to-lerobot`.** 시간축 정렬, 이상치(시트 이미지 작업자 손), 세션 성공/실패 라벨은 Silver. 통과분만이 LeRobot Gold. 변환 실패가 Bronze를 덮어쓰지 않게 `--output-dir`을 세션/태스크별로 분리.
6. **주름 이미지 프로그램은 같은 Bronze 규칙으로 합류.** RealSense IR/컬러·ROI exposure·`.capture.json`은 raw+timestamp로 남기고, 주름 polyline 라벨은 Silver. 자동 캡처(optical flow)는 제어/검사 주기와 분리하고 조명 끊김이 캡처를 막지 말 것(인수인계).

---

## C. 한 줄 요약 (Resa)

창준 설계의 NVIDIA 훅은 **rosbag2 MCAP Bronze(세션 append, raw+`metadata.yaml`) → `mcap-to-lerobot` Silver/Gold → GR00T 학습/재배포**이고, Isaac recorder는 ROS2 어댑터 레퍼런스일 뿐 추상 수집기 자체가 아니다.
